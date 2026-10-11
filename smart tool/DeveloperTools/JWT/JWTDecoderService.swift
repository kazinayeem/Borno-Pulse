//
//  JWTDecoderService.swift
//  Borno Pulse
//

import Foundation

public final class JWTDecoderService: Sendable {
    public static let shared = JWTDecoderService()
    
    private init() {}
    
    public func decode(jwtToken: String) throws -> JWTTokenDetails {
        let trimmed = jwtToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: ".")
        
        guard parts.count >= 2 else {
            throw NSError(
                domain: "JWTError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid JWT format. A valid token contains at least a header and payload separated by periods."]
            )
        }
        
        let headerData = try base64URLDecode(parts[0])
        let payloadData = try base64URLDecode(parts[1])
        let signature = parts.count > 2 ? parts[2] : "(None)"
        
        // Pretty JSON
        let headerObj = try JSONSerialization.jsonObject(with: headerData, options: [])
        let payloadObj = try JSONSerialization.jsonObject(with: payloadData, options: [])
        
        let prettyHeader = try String(data: JSONSerialization.data(withJSONObject: headerObj, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8) ?? ""
        let prettyPayload = try String(data: JSONSerialization.data(withJSONObject: payloadObj, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8) ?? ""
        
        // Extract Header Fields
        var alg: String? = nil
        var typ: String? = nil
        if let hDict = headerObj as? [String: Any] {
            alg = hDict["alg"] as? String
            typ = hDict["typ"] as? String
        }
        
        // Extract Payload Claims
        var issuer: String? = nil
        var subject: String? = nil
        var audience: String? = nil
        var expDate: Date? = nil
        var nbfDate: Date? = nil
        var iatDate: Date? = nil
        var jti: String? = nil
        var claims: [JWTClaimItem] = []
        
        let now = Date()
        var isExpired = false
        var remaining: TimeInterval? = nil
        
        if let pDict = payloadObj as? [String: Any] {
            issuer = pDict["iss"] as? String
            subject = pDict["sub"] as? String
            audience = pDict["aud"] as? String
            jti = pDict["jti"] as? String
            
            if let expTimestamp = pDict["exp"] as? TimeInterval {
                let d = Date(timeIntervalSince1970: expTimestamp)
                expDate = d
                isExpired = d < now
                remaining = d.timeIntervalSince(now)
            } else if let expInt = pDict["exp"] as? Int64 {
                let d = Date(timeIntervalSince1970: TimeInterval(expInt))
                expDate = d
                isExpired = d < now
                remaining = d.timeIntervalSince(now)
            }
            
            if let nbfTimestamp = pDict["nbf"] as? TimeInterval {
                nbfDate = Date(timeIntervalSince1970: nbfTimestamp)
            }
            if let iatTimestamp = pDict["iat"] as? TimeInterval {
                iatDate = Date(timeIntervalSince1970: iatTimestamp)
            }
            
            // Build Claims list
            for (k, v) in pDict.sorted(by: { $0.key < $1.key }) {
                let desc: String? = {
                    switch k {
                    case "iss": return "Issuer: Entity that issued the JWT"
                    case "sub": return "Subject: Principal subject of the JWT"
                    case "aud": return "Audience: Intended recipients"
                    case "exp": return "Expiration Time: UTC timestamp"
                    case "nbf": return "Not Before: Valid time start"
                    case "iat": return "Issued At: Creation timestamp"
                    case "jti": return "JWT ID: Unique token identifier"
                    default: return nil
                    }
                }()
                claims.append(JWTClaimItem(key: k, value: "\(v)", standardDescription: desc))
            }
        }
        
        return JWTTokenDetails(
            algorithm: alg,
            tokenType: typ,
            headerJSON: prettyHeader,
            payloadJSON: prettyPayload,
            signature: signature,
            issuer: issuer,
            subject: subject,
            audience: audience,
            expirationDate: expDate,
            notBeforeDate: nbfDate,
            issuedAtDate: iatDate,
            jwtId: jti,
            isExpired: isExpired,
            remainingSeconds: remaining,
            claims: claims
        )
    }
    
    private func base64URLDecode(_ string: String) throws -> Data {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        
        guard let data = Data(base64Encoded: base64) else {
            throw NSError(
                domain: "JWTError",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to Base64URL decode segment"]
            )
        }
        return data
    }
}
