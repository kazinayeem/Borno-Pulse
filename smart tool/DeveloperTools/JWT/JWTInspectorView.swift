//
//  JWTInspectorView.swift
//  Borno Pulse
//

import AppKit
import SwiftUI

public struct JWTInspectorView: View {
    @State private var inputToken: String = ""
    @State private var tokenDetails: JWTTokenDetails? = nil
    @State private var errorMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Security Warning & Disclaimer Card
                securityWarningBanner
                
                // Input Header with Controls
                HStack {
                    Text("Paste Encoded JWT Token")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    Button {
                        loadSampleToken()
                    } label: {
                        Label("Sample JWT", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear") {
                        inputToken = ""
                        tokenDetails = nil
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)
                }
                
                // Token Editor
                TextEditor(text: $inputToken)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 100)
                    .themedInputField()
                    .onChange(of: inputToken) { _, newVal in
                        parseToken(newVal)
                    }
                
                if let err = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.dangerRed)
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.dangerRed)
                    }
                    .padding(10)
                    .background(AppTheme.dangerRed.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                if let jwt = tokenDetails {
                    // Summary Ribbon
                    tokenSummaryRibbon(jwt)
                    
                    // Decoded Components: Header, Payload & Signature
                    HStack(alignment: .top, spacing: 14) {
                        // Header Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("HEADER (Algorithm & Type)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.electricCyan)
                                Spacer()
                                copyButton(jwt.headerJSON)
                            }
                            
                            TextEditor(text: .constant(jwt.headerJSON))
                                .font(.system(size: 11, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(height: 140)
                                .background(AppTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.electricCyan.opacity(0.3), lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Payload Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("PAYLOAD (Data & Claims)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.purpleAccent)
                                Spacer()
                                copyButton(jwt.payloadJSON)
                            }
                            
                            TextEditor(text: .constant(jwt.payloadJSON))
                                .font(.system(size: 11, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(height: 140)
                                .background(AppTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.purpleAccent.opacity(0.3), lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Signature Box
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("SIGNATURE (Base64URL Digest)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.matrixGreen)
                            Spacer()
                            copyButton(jwt.signature)
                        }
                        
                        Text(jwt.signature)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.matrixGreen.opacity(0.3), lineWidth: 1))
                    }
                    
                    // Claims Table
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Decoded Claims Table")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        VStack(spacing: 4) {
                            ForEach(jwt.claims) { claim in
                                HStack {
                                    Text(claim.key)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.electricCyan)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    if let desc = claim.standardDescription {
                                        Text(desc)
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppTheme.textTertiary)
                                            .frame(width: 220, alignment: .leading)
                                    } else {
                                        Spacer().frame(width: 220)
                                    }
                                    
                                    Text(claim.value)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(claim.value, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 9))
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(AppTheme.subtleFill)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .padding(14)
                    .smartCard()
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Security Warning Banner
    private var securityWarningBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.warningAmber)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Local-Only Inspection • Signature Verification Notice")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("This tool decodes token payloads locally on your Mac. Decoding is NOT cryptographic signature verification; an expired or tampered token can still be decoded. Never paste production API secret keys unnecessarily.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(12)
        .background(AppTheme.warningAmber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.warningAmber.opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - Summary Ribbon
    private func tokenSummaryRibbon(_ jwt: JWTTokenDetails) -> some View {
        HStack(spacing: 12) {
            // Algorithm
            HStack(spacing: 5) {
                Text("Algorithm:")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(jwt.algorithm ?? "None")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.electricCyan)
            }
            
            // Expiration State
            if let expDate = jwt.expirationDate {
                HStack(spacing: 5) {
                    Circle()
                        .fill(jwt.isExpired ? AppTheme.dangerRed : AppTheme.successGreen)
                        .frame(width: 7, height: 7)
                    
                    Text(jwt.isExpired ? "Expired" : "Active (Valid)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(jwt.isExpired ? AppTheme.dangerRed : AppTheme.successGreen)
                    
                    Text("(\(expDate.formatted(date: .abbreviated, time: .shortened)))")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            } else {
                Text("No 'exp' claim (Never expires)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.warningAmber)
            }
            
            Spacer()
            
            if let sub = jwt.subject {
                Text("Subject: \(sub)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(10)
        .background(AppTheme.cardBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.cardBorder, lineWidth: 0.5))
    }
    
    private func copyButton(_ text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                Text("Copy")
            }
            .font(.system(size: 10))
            .foregroundStyle(AppTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
    
    private func parseToken(_ token: String) {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            tokenDetails = nil
            errorMessage = nil
            return
        }
        
        do {
            tokenDetails = try JWTDecoderService.shared.decode(jwtToken: token)
            errorMessage = nil
        } catch {
            tokenDetails = nil
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadSampleToken() {
        // Standard sample JWT: HS256 with user details
        inputToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6Ik5hZW0gU21hcnQgVXNlciIsImFkbWluIjp0cnVlLCJpc3MiOiJuYWVtLXNtYXJ0LXRvb2wiLCJpYXQiOjE3Mzg4NTc2MDAsImV4cCI6MjA1NDQ3MzYwMH0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        parseToken(inputToken)
    }
}
