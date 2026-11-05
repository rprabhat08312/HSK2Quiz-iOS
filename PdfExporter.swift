import UIKit

enum PdfExporter {
    /// Builds an A4 word-list PDF and opens the iOS share sheet (Save to Files, AirDrop, Print...).
    static func export(words: [Word], title: String, from vc: UIViewController, source: UIView?) {
        if words.isEmpty { Router.alert("Export PDF", "No words to export."); return }

        let pageW: CGFloat = 595, pageH: CGFloat = 842, margin: CGFloat = 36
        let titleAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.black]
        let subAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor(white: 0.4, alpha: 1)]
        let headAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor(red: 40/255, green: 50/255, blue: 70/255, alpha: 1)]
        let hanziAttr: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 15), .foregroundColor: UIColor.black]
        let pyAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor(red: 30/255, green: 90/255, blue: 160/255, alpha: 1)]
        let textAttr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor(white: 0.12, alpha: 1)]
        let lineColor = UIColor(red: 225/255, green: 230/255, blue: 235/255, alpha: 1)
        let headBg = UIColor(red: 240/255, green: 243/255, blue: 246/255, alpha: 1)

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"
        let stamp = df.string(from: Date())

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let data = renderer.pdfData { ctx in
            var page = 0
            var y: CGFloat = 0

            func line(_ y: CGFloat) {
                lineColor.setStroke()
                let p = UIBezierPath(); p.lineWidth = 0.8
                p.move(to: CGPoint(x: margin, y: y)); p.addLine(to: CGPoint(x: pageW - margin, y: y)); p.stroke()
            }
            func header() {
                ctx.beginPage(); page += 1
                (title as NSString).draw(at: CGPoint(x: margin, y: 24), withAttributes: titleAttr)
                ("Total words: \(words.count)   |   Exported: \(stamp)" as NSString)
                    .draw(at: CGPoint(x: margin, y: 50), withAttributes: subAttr)
                line(66)
                headBg.setFill()
                UIBezierPath(rect: CGRect(x: margin, y: 74, width: pageW - 2 * margin, height: 22)).fill()
                ("#" as NSString).draw(at: CGPoint(x: margin + 8, y: 79), withAttributes: headAttr)
                ("Hanzi" as NSString).draw(at: CGPoint(x: margin + 36, y: 79), withAttributes: headAttr)
                ("Pinyin" as NSString).draw(at: CGPoint(x: margin + 115, y: 79), withAttributes: headAttr)
                ("Meaning & Example" as NSString).draw(at: CGPoint(x: margin + 215, y: 79), withAttributes: headAttr)
                y = 104
            }
            func footer() {
                ("Page \(page)" as NSString).draw(at: CGPoint(x: pageW - margin - 40, y: pageH - 26), withAttributes: subAttr)
            }

            header()
            for (i, w) in words.enumerated() {
                let hasEx = !w.example.trimmingCharacters(in: .whitespaces).isEmpty
                let rowH: CGFloat = hasEx ? 40 : 26
                if y + rowH > pageH - margin - 20 { footer(); header() }
                ("\(i + 1)" as NSString).draw(at: CGPoint(x: margin + 8, y: y + 4), withAttributes: subAttr)
                (w.hanzi as NSString).draw(at: CGPoint(x: margin + 36, y: y + 2), withAttributes: hanziAttr)
                (w.pinyin as NSString).draw(at: CGPoint(x: margin + 115, y: y + 4), withAttributes: pyAttr)
                let meaning = w.english.count > 55 ? String(w.english.prefix(52)) + "..." : w.english
                (meaning as NSString).draw(at: CGPoint(x: margin + 215, y: y + 4), withAttributes: textAttr)
                if hasEx {
                    let ex = w.example.count > 30 ? String(w.example.prefix(28)) + "..." : w.example
                    let en = w.exampleEn.count > 35 ? String(w.exampleEn.prefix(32)) + "..." : w.exampleEn
                    ("e.g. \(ex)  (\(en))" as NSString).draw(at: CGPoint(x: margin + 215, y: y + 20), withAttributes: subAttr)
                }
                y += rowH
                line(y)
                y += 4
            }
            footer()
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("HSK2_Words.pdf")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            Router.alert("Export PDF", "Failed to export PDF: \(error.localizedDescription)")
            return
        }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = sheet.popoverPresentationController {
            let v = source ?? vc.view!
            pop.sourceView = v
            pop.sourceRect = v.bounds
        }
        vc.present(sheet, animated: true, completion: nil)
    }
}
