//
//  BatchAndFocusTests.swift
//  Borno Pulse Tests
//

import AppKit
import Foundation
import PDFKit
import SwiftUI

@MainActor
public enum BatchAndFocusTests {
    public static func runTests(_ assert: (Bool, String) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        
        // ==========================================
        // MARK: - Batch File Converter Tests
        // ==========================================
        
        // 1. Empty queue invariant
        let batch = BatchConverterService.shared
        batch.clearAll()
        assert(batch.queue.isEmpty, "Batch converter: Queue is empty after clearAll")
        assert(batch.totalSourceBytes == 0, "Batch converter: Empty queue has 0 totalSourceBytes")
        assert(batch.completedCount == 0, "Batch converter: Empty queue has 0 completedCount")
        assert(batch.overallProgress == 0.0, "Batch converter: Empty queue has 0.0 progress")
        
        // 2. Importing multiple supported files
        let testImagePNG = tempDir.appendingPathComponent("batch_test_sample.png")
        let testImageJPG = tempDir.appendingPathComponent("batch_test_sample.jpg")
        let testPDF = tempDir.appendingPathComponent("batch_test_doc.pdf")
        
        // Create 100x100 dummy bitmap image
        let dummyImg = NSImage(size: NSSize(width: 100, height: 100))
        dummyImg.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        dummyImg.unlockFocus()
        if let tiff = dummyImg.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            let pngData = rep.representation(using: .png, properties: [:])
            try? pngData?.write(to: testImagePNG)
            let jpgData = rep.representation(using: .jpeg, properties: [:])
            try? jpgData?.write(to: testImageJPG)
        }
        
        // Create 1-page dummy PDF
        let dummyPDFDoc = PDFDocument()
        let pdfPage = PDFPage(image: dummyImg)!
        dummyPDFDoc.insert(pdfPage, at: 0)
        dummyPDFDoc.write(to: testPDF)
        
        let importResult = batch.addFiles([testImagePNG, testImageJPG, testPDF])
        assert(importResult.added == 3, "Batch converter: Successfully imported 3 supported files (PNG, JPG, PDF)")
        assert(batch.queue.count == 3, "Batch converter: Queue contains 3 items")
        assert(batch.queue.allSatisfy { $0.status == .queued }, "Batch converter: All imported items start in .queued status")
        
        // 3. Unsupported files rejection
        let testTxtFile = tempDir.appendingPathComponent("batch_unsupported.txt")
        let testZipFile = tempDir.appendingPathComponent("batch_archive.zip")
        try? "plain text".write(to: testTxtFile, atomically: true, encoding: .utf8)
        try? "dummy zip".write(to: testZipFile, atomically: true, encoding: .utf8)
        
        let rejectResult = batch.addFiles([testTxtFile, testZipFile])
        assert(rejectResult.added == 0, "Batch converter: Unsupported files (.txt, .zip) are rejected")
        assert(rejectResult.skipped == 2, "Batch converter: Exactly 2 unsupported files were skipped")
        assert(batch.rejectedFilesNotice != nil, "Batch converter: User notice displayed when files are skipped")
        
        // 4. Queue item reordering and removal
        let firstItemId = batch.queue[0].id
        let secondItemId = batch.queue[1].id
        batch.moveItemDown(id: firstItemId)
        assert(batch.queue[1].id == firstItemId, "Batch converter: moveItemDown successfully swapped item position")
        batch.moveItemUp(id: firstItemId)
        assert(batch.queue[0].id == firstItemId, "Batch converter: moveItemUp restored item position")
        
        batch.removeItem(id: secondItemId)
        assert(batch.queue.count == 2, "Batch converter: removeItem reduced queue count to 2")
        assert(!batch.queue.contains(where: { $0.id == secondItemId }), "Batch converter: Removed item is absent from queue")
        
        // 5. Collision safe URL naming
        let collisionTestURL = tempDir.appendingPathComponent("collision_test_target.png")
        try? "dummy".write(to: collisionTestURL, atomically: true, encoding: .utf8)
        let resolvedCollision = BatchConverterService.collisionSafeURL(desiredURL: collisionTestURL)
        assert(resolvedCollision.lastPathComponent == "collision_test_target (1).png", "Batch converter: Collision safe URL generates incremented name")
        try? FileManager.default.removeItem(at: collisionTestURL)
        
        // 6. Conversion engine: Image format conversion to JPG
        let convertDir = tempDir.appendingPathComponent("batch_output_test", isDirectory: true)
        try? FileManager.default.createDirectory(at: convertDir, withIntermediateDirectories: true)
        let convertResult = ImageFormatConverterService.convertSingleImage(
            inputURL: testImagePNG,
            outputDir: convertDir,
            targetFormat: .jpeg,
            backgroundColor: .white
        )
        switch convertResult {
        case .success(let bytes):
            assert(bytes > 0, "Batch converter engine: Image format conversion produced valid non-empty JPEG bytes")
        case .failure(let err):
            assert(false, "Batch converter engine: Image conversion failed with error: \(err)")
        }
        
        // 7. Conversion engine: PDF compression
        let pdfCompressResult = PDFCompressorService.compress(inputURL: testPDF, outputDir: convertDir, preset: .balanced)
        switch pdfCompressResult {
        case .success(let output):
            assert(output.bytes > 0, "Batch converter engine: PDF compression produced valid output PDF")
            assert(FileManager.default.fileExists(atPath: output.url.path), "Batch converter engine: Compressed PDF file exists on disk")
        case .failure(let err):
            assert(false, "Batch converter engine: PDF compression failed with error: \(err)")
        }
        
        // Clean up temp files
        try? FileManager.default.removeItem(at: testImagePNG)
        try? FileManager.default.removeItem(at: testImageJPG)
        try? FileManager.default.removeItem(at: testPDF)
        try? FileManager.default.removeItem(at: testTxtFile)
        try? FileManager.default.removeItem(at: testZipFile)
        try? FileManager.default.removeItem(at: convertDir)
        batch.clearAll()
        
        // ==========================================
        // MARK: - Focus & Pomodoro Tests
        // ==========================================
        
        let focus = FocusTimerService.shared
        focus.reset()
        
        // 8. Preset durations
        focus.setFocusDuration(minutes: 25)
        assert(focus.focusDurationSeconds == 1500, "Pomodoro: 25m preset sets focus duration to exactly 1500 seconds")
        assert(focus.remainingSeconds == 1500, "Pomodoro: 25m preset sets remaining seconds to 1500")
        assert(focus.totalSessionSeconds == 1500, "Pomodoro: 25m preset sets total session seconds to 1500")
        
        focus.setFocusDuration(minutes: 45)
        assert(focus.focusDurationSeconds == 2700, "Pomodoro: 45m preset sets focus duration to exactly 2700 seconds")
        assert(focus.remainingSeconds == 2700, "Pomodoro: 45m preset sets remaining seconds to 2700")
        
        focus.setFocusDuration(minutes: 50)
        assert(focus.focusDurationSeconds == 3000, "Pomodoro: 50m preset sets focus duration to exactly 3000 seconds")
        assert(focus.remainingSeconds == 3000, "Pomodoro: 50m preset sets remaining seconds to 3000")
        
        // 9. Quick short session presets (1m and 2m)
        focus.setFocusDuration(seconds: 60)
        assert(focus.focusDurationSeconds == 60, "Pomodoro: 1-minute quick preset sets duration to exactly 60 seconds")
        assert(focus.remainingSeconds == 60, "Pomodoro: 1-minute quick preset sets remaining seconds to 60")
        assert(focus.totalSessionSeconds == 60, "Pomodoro: 1-minute quick preset sets totalSessionSeconds to 60")
        
        focus.setFocusDuration(seconds: 120)
        assert(focus.focusDurationSeconds == 120, "Pomodoro: 2-minute quick preset sets duration to exactly 120 seconds")
        assert(focus.remainingSeconds == 120, "Pomodoro: 2-minute quick preset sets remaining seconds to 120")
        
        // 10. Custom duration validation
        let zeroResult = FocusTimerService.validateDuration(hours: 0, minutes: 0, seconds: 0)
        assert(zeroResult == .failure(.zeroOrNegative), "Pomodoro validation: Zero duration is rejected")
        
        let negativeResult = FocusTimerService.validateDuration(hours: -1, minutes: 20, seconds: 0)
        assert(negativeResult == .failure(.zeroOrNegative), "Pomodoro validation: Negative duration is rejected")
        
        let tooShortResult = FocusTimerService.validateDuration(hours: 0, minutes: 0, seconds: 5)
        assert(tooShortResult == .failure(.belowMinimum(FocusTimerService.minDurationSeconds)), "Pomodoro validation: Durations under 10 seconds are rejected")
        
        let tooLongResult = FocusTimerService.validateDuration(hours: 13, minutes: 0, seconds: 0)
        assert(tooLongResult == .failure(.exceedsMaximum(FocusTimerService.maxDurationSeconds)), "Pomodoro validation: Durations exceeding 12 hours are rejected")
        
        let validCustom = FocusTimerService.validateDuration(hours: 1, minutes: 30, seconds: 15)
        switch validCustom {
        case .success(let secs):
            assert(secs == 5415, "Pomodoro validation: 1h 30m 15s correctly computed as 5415 seconds")
        case .failure:
            assert(false, "Pomodoro validation: Valid custom duration was incorrectly rejected")
        }
        
        // 11. Apply custom duration
        let applyResult = focus.applyCustomDuration(hours: 0, minutes: 35, seconds: 0)
        switch applyResult {
        case .success(let secs):
            assert(secs == 2100, "Pomodoro: applyCustomDuration(35m) sets duration to 2100 seconds")
            assert(focus.focusDurationSeconds == 2100, "Pomodoro: focusDurationSeconds updated to 2100")
            assert(focus.remainingSeconds == 2100, "Pomodoro: remainingSeconds reset to 2100")
        case .failure(let err):
            assert(false, "Pomodoro: applyCustomDuration failed: \(err)")
        }
        
        // 12. Reset restores the selected custom duration (never hardcoded 25m)
        focus.setFocusDuration(seconds: 120) // 2 minutes
        focus.remainingSeconds = 45 // simulate active ticking
        focus.reset()
        assert(focus.remainingSeconds == 120, "Pomodoro: reset() restores selected 2-minute duration (120s), not hardcoded 25m")
        
        focus.setFocusDuration(seconds: 60) // 1 minute
        focus.remainingSeconds = 15 // simulate active ticking
        focus.reset()
        assert(focus.remainingSeconds == 60, "Pomodoro: reset() restores selected 1-minute duration (60s), not hardcoded 25m")
        
        // 13. Skip does not record completed focus session
        let initialHistoryCount = focus.sessionHistory.count
        focus.skipToNextMode()
        assert(focus.sessionHistory.count == initialHistoryCount, "Pomodoro: Skipping does NOT record completed session in history")
        assert(focus.currentMode == .shortBreak, "Pomodoro: Skip from focus successfully advanced mode to .shortBreak")
        
        focus.skipToNextMode()
        assert(focus.currentMode == .focus, "Pomodoro: Skip from shortBreak returned mode to .focus")
        
        // 14. Pause and Resume invariant
        focus.setFocusDuration(minutes: 25)
        focus.reset()
        focus.start()
        assert(focus.isRunning == true, "Pomodoro: start() sets isRunning to true")
        focus.pause()
        assert(focus.isRunning == false, "Pomodoro: pause() sets isRunning to false")
        
        // 15. Formatted duration helper
        assert(FocusTimerService.formatDuration(seconds: 60) == "1m", "Pomodoro format: 60s formats as 1m")
        assert(FocusTimerService.formatDuration(seconds: 120) == "2m", "Pomodoro format: 120s formats as 2m")
        assert(FocusTimerService.formatDuration(seconds: 3600) == "1h", "Pomodoro format: 3600s formats as 1h")
        assert(FocusTimerService.formatDuration(seconds: 5400) == "1h 30m", "Pomodoro format: 5400s formats as 1h 30m")
        
        // Restore default 25m
        focus.setFocusDuration(minutes: 25)
        focus.reset()
    }
}
