//
//  PdfViewController.swift
//
//  Created by Oleksandr Harmash
//  Copyright © Oleksandr Harmash. All rights reserved.
//

import Cocoa
import Quartz

class PdfViewController: NSViewController {

    @IBOutlet weak var pdfView: PDFView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadPDF()
    }

    private func loadPDF() {
        guard let pdfUrl = Bundle.main.url(forResource: "instruction_pdf", withExtension: "pdf"),
            let pdfDocument = PDFDocument(url: pdfUrl)
        else { return }
        
        pdfView.document = pdfDocument
    }
}
