import CoreNFC
import Foundation

enum NFCScanError: LocalizedError {
    case unavailable
    case cancelled
    case timedOut
    case readFailed
    case unsupportedCard
    case wrongCard
    case sessionFailed(String)

    /// True when the user dismissed the NFC sheet or it already showed the
    /// reason, so the app should not show a second message.
    var isAlreadyExplained: Bool {
        switch self {
        case .cancelled, .timedOut, .readFailed, .unsupportedCard, .wrongCard: true
        case .unavailable, .sessionFailed: false
        }
    }

    var errorDescription: String? {
        switch self {
        case .unavailable: "This iPhone can't read NFC cards right now."
        case .cancelled: "The scan was cancelled."
        case .timedOut: "No card was found in time."
        case .readFailed: "The card couldn't be read."
        case .unsupportedCard: "Unsupported card"
        case .wrongCard: "That's not your Brick"
        case .sessionFailed(let reason): reason
        }
    }
}

/// Reads the UID of an NTAG / MIFARE Ultralight card.
@MainActor
struct NFCService {
    /// Shows the system NFC sheet and returns the card's UID as uppercase hex.
    ///
    /// When `expectedUID` is given, any other card fails with `.wrongCard`
    /// and the sheet tells the user so before it closes.
    func scan(expecting expectedUID: String? = nil, successMessage: String) async throws -> String {
        guard NFCTagReaderSession.readingAvailable else { throw NFCScanError.unavailable }
        return try await TagScan(expectedUID: expectedUID, successMessage: successMessage).run()
    }
}

/// One NFC session. Every callback arrives on the main queue.
private final class TagScan: NSObject, NFCTagReaderSessionDelegate {
    private let expectedUID: String?
    private let successMessage: String
    private var continuation: CheckedContinuation<String, Error>?
    /// Held so the session stays alive until it delivers a result.
    private var session: NFCTagReaderSession?

    init(expectedUID: String?, successMessage: String) {
        self.expectedUID = expectedUID
        self.successMessage = successMessage
    }

    func run() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            guard let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: .main) else {
                continuation.resume(throwing: NFCScanError.unavailable)
                return
            }
            self.continuation = continuation
            self.session = session
            session.alertMessage = "Hold the top of your iPhone against your card"
            session.begin()
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        session.connect(to: tag) { [self] error in
            if error != nil {
                session.invalidate(errorMessage: "Couldn't read the card. Try again.")
                finish(.failure(NFCScanError.readFailed))
                return
            }
            guard case .miFare(let card) = tag, card.mifareFamily == .ultralight else {
                session.invalidate(errorMessage: "Unsupported card")
                finish(.failure(NFCScanError.unsupportedCard))
                return
            }
            let uid = card.identifier.map { String(format: "%02X", $0) }.joined()
            if let expectedUID, uid != expectedUID {
                session.invalidate(errorMessage: "That's not your Brick")
                finish(.failure(NFCScanError.wrongCard))
                return
            }
            session.alertMessage = successMessage
            session.invalidate()
            finish(.success(uid))
        }
    }

    /// Also called after this class invalidates the session itself, by which
    /// time the result has been delivered and this is ignored.
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        switch (error as? NFCReaderError)?.code {
        case .readerSessionInvalidationErrorUserCanceled:
            finish(.failure(NFCScanError.cancelled))
        case .readerSessionInvalidationErrorSessionTimeout:
            finish(.failure(NFCScanError.timedOut))
        default:
            finish(.failure(NFCScanError.sessionFailed(error.localizedDescription)))
        }
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        session = nil
    }
}
