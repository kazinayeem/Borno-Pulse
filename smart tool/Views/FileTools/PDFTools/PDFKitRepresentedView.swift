//
//  PDFKitRepresentedView.swift
//  Borno Pulse
//
//  Native AppKit PDFView bridge for SwiftUI.
//

import AppKit
import PDFKit
import SwiftUI

public struct PDFKitRepresentedView: NSViewRepresentable {
    public let document: PDFDocument?
    @Binding public var currentPageIndex: Int
    public var autoScales: Bool
    public var displayMode: PDFDisplayMode

    public init(
        document: PDFDocument?,
        currentPageIndex: Binding<Int>,
        autoScales: Bool = true,
        displayMode: PDFDisplayMode = .singlePageContinuous
    ) {
        self.document = document
        self._currentPageIndex = currentPageIndex
        self.autoScales = autoScales
        self.displayMode = displayMode
    }

    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = autoScales
        pdfView.displayMode = displayMode
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    public func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
        pdfView.autoScales = autoScales
        pdfView.displayMode = displayMode

        if let doc = document, currentPageIndex < doc.pageCount, let page = doc.page(at: currentPageIndex) {
            if pdfView.currentPage !== page {
                pdfView.go(to: page)
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    public final class Coordinator: NSObject {
        var parent: PDFKitRepresentedView

        init(_ parent: PDFKitRepresentedView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let doc = pdfView.document else { return }
            let index = doc.index(for: currentPage)
            if index != NSNotFound && index != parent.currentPageIndex {
                self.parent.currentPageIndex = index
            }
        }
    }
}
