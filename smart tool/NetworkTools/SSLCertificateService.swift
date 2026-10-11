//
//  SSLCertificateService.swift
//  Borno Pulse
//

import Foundation
import Security

public final class SSLCertificateService: NSObject, URLSessionDelegate, @unchecked Sendable {
    public static let shared = SSLCertificateService()
    
    private override init() {
        super.init()
    }
    
    public func inspect(host: String, port: Int = 443) async throws -> SSLCertificateDetails {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .components(separatedBy: "/").first ?? host
        
        guard let url = URL(string: "https://\(cleanHost):\(port)") else {
            throw NSError(domain: "SSLError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid host URL"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = SingleRequestCertDelegate(expectedHost: cleanHost) { result in
                continuation.resume(with: result)
            }
            
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 10.0
            config.timeoutIntervalForResource = 10.0
            
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            
            let task = session.dataTask(with: request)
            task.resume()
        }
    }
}

// MARK: - Dedicated Challenge Delegate
private final class SingleRequestCertDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let expectedHost: String
    private let completion: @Sendable (Result<SSLCertificateDetails, Error>) -> Void
    private var didComplete = false
    
    init(expectedHost: String, completion: @escaping @Sendable (Result<SSLCertificateDetails, Error>) -> Void) {
        self.expectedHost = expectedHost
        self.completion = completion
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        var trustError: CFError?
        let isTrusted = SecTrustEvaluateWithError(serverTrust, &trustError)
        
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leafCert = chain.first else {
            finishOnce(.failure(NSError(domain: "SSLError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not retrieve certificate chain"])))
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let commonName = (SecCertificateCopySubjectSummary(leafCert) as String?) ?? expectedHost
        
        // Extract Validity Dates
        var validFromDate: Date? = nil
        var validUntilDate: Date? = nil
        var issuerName: String = "Unknown CA"
        var sans: [String] = []
        
        // Extract Issuer from chain if present
        if chain.count > 1, let issuerSummary = SecCertificateCopySubjectSummary(chain[1]) as String? {
            issuerName = issuerSummary
        } else {
            issuerName = commonName
        }
        
        let keyProp = kSecPropertyKeyValue as String
        if let values = SecCertificateCopyValues(leafCert, [
            kSecOIDX509V1ValidityNotBefore,
            kSecOIDX509V1ValidityNotAfter,
            kSecOIDSubjectAltName
        ] as CFArray, nil) as? [CFString: [String: Any]] {
            if let notBeforeDict = values[kSecOIDX509V1ValidityNotBefore],
               let val = notBeforeDict[keyProp] as? TimeInterval {
                validFromDate = Date(timeIntervalSinceReferenceDate: val)
            }
            if let notAfterDict = values[kSecOIDX509V1ValidityNotAfter],
               let val = notAfterDict[keyProp] as? TimeInterval {
                validUntilDate = Date(timeIntervalSinceReferenceDate: val)
            }
            if let sanDict = values[kSecOIDSubjectAltName],
               let items = sanDict[keyProp] as? [[String: Any]] {
                sans = items.compactMap { $0[keyProp] as? String }
            }
        }


        
        let now = Date()
        let isExpired = (validUntilDate != nil) ? validUntilDate! < now : false
        let remainingDays = (validUntilDate != nil) ? Calendar.current.dateComponents([.day], from: now, to: validUntilDate!).day : nil
        
        let details = SSLCertificateDetails(
            host: expectedHost,
            port: challenge.protectionSpace.port,
            commonName: commonName,
            issuer: issuerName,
            validFrom: validFromDate,
            validUntil: validUntilDate,
            remainingDays: remainingDays,
            isTrusted: isTrusted,
            isExpired: isExpired,
            sanDNSNames: sans
        )
        
        finishOnce(.success(details))
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error {
            finishOnce(.failure(err))
        }
    }
    
    private func finishOnce(_ result: Result<SSLCertificateDetails, Error>) {
        if !didComplete {
            didComplete = true
            completion(result)
        }
    }
}
