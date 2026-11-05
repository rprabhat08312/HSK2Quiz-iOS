import UIKit

final class WordsViewController: WordListBase {
    private var onlyBookmarked = false
    private var exportButton: UIButton?

    override var baseList: [Word] { return onlyBookmarked ? store.bookmarkedWords(words) : words }

    override func makeHeader() -> UIView {
        let btn = filledButton("📄 Export PDF", C.olive, size: 13, height: 34, radius: 12) { [weak self] in self?.export() }
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        btn.setContentHuggingPriority(.required, for: .horizontal)
        exportButton = btn
        return screenHeader(title: onlyBookmarked ? "Bookmarked (\(shown.count))" : "All words (\(shown.count))",
                            trailing: btn) { Router.home() }
    }

    override func makeExtras() -> [UIView] {
        let chips = hstack([
            ChipButton("All (\(words.count))", on: !onlyBookmarked) { [weak self] in self?.onlyBookmarked = false; self?.reload() },
            ChipButton("🔖 Bookmarked (\(store.bookmarkedCount))", on: onlyBookmarked) { [weak self] in self?.onlyBookmarked = true; self?.reload() },
            flexSpacer(),
        ], spacing: 8)
        return [padded(chips, UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16))]
    }

    override func rowView(for w: Word, index: Int) -> UIView {
        return makeWordRow(w, index: index + 1, mastered: store.mastered(w.id),
                           bookmark: (isOn: store.isBookmarked(w.id), toggle: { [weak self] in self?.store.toggleBookmark(w.id) }))
    }

    override func didSelect(_ w: Word, index: Int) { Router.openWord(w) }

    override func emptyState() -> UIView? {
        guard onlyBookmarked else { return nil }
        let v = vstack([lbl("🔖", 40, .regular, C.ink, align: .center),
                        lbl("No bookmarked words yet", 16, .medium, C.ink, align: .center),
                        lbl("Tap 🔖 on any word row to bookmark it", 13, .regular, C.muted, align: .center)], spacing: 8)
        let c = UIView()
        c.addSubview(v)
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.centerXAnchor.constraint(equalTo: c.centerXAnchor),
            v.centerYAnchor.constraint(equalTo: c.centerYAnchor, constant: -40),
            v.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 24),
            v.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -24),
        ])
        return c
    }

    private func export() {
        let list: [Word] = onlyBookmarked ? shown : (store.bookmarkedCount > 0 ? store.bookmarkedWords(words) : shown)
        let title = (onlyBookmarked || store.bookmarkedCount > 0) ? "HSK 2 Quiz - Bookmarked Words" : "HSK 2 Quiz - Word List"
        PdfExporter.export(words: list, title: title, from: self, source: exportButton)
    }
}

// MARK: - Pick words for the quiz

final class PickViewController: WordListBase {
    private var rangeMode = false
    private var rangeStart: Word?

    override func makeHeader() -> UIView {
        let done = textButton("Done", C.red, size: 16) { Router.home() }
        done.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        return screenHeader(title: "Pick words for quiz", subtitle: "\(store.pickedCount) of \(words.count) selected",
                            trailing: done) { Router.home() }
    }

    override func makeExtras() -> [UIView] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let chips: [UIView] = [
            ChipButton(q.isEmpty ? "Select all" : "Select shown (\(shown.count))") { [weak self] in
                guard let self = self else { return }
                self.store.addPicked(self.shown.map { $0.id })
            },
            ChipButton("🔢 Range / Serial #") { [weak self] in self?.showRange() },
            ChipButton(rangeMode ? "❌ Cancel Tap Range" : "👉 Tap Range (A➔B)", on: rangeMode) { [weak self] in
                guard let self = self else { return }
                self.rangeMode.toggle(); self.rangeStart = nil; self.reload()
            },
            ChipButton("Add my learned") { [weak self] in
                guard let self = self else { return }
                self.store.addPicked(self.store.learnedWords(self.words).map { $0.id })
            },
            ChipButton("Clear") { [weak self] in self?.store.clearPicked() },
        ]
        var out: [UIView] = [hscroll(chips, spacing: 8, height: 38, sidePad: 16)]
        if rangeMode {
            let text: String
            if let s = rangeStart { text = "🎯 Range start: #\(s.id) \(s.hanzi). Now tap RANGE END!" }
            else { text = "👉 Tap a word to set RANGE START" }
            let l = lbl(text, 13, .bold)
            var items: [UIView] = [l]
            if rangeStart != nil {
                items.append(textButton("Reset", C.red, size: 12) { [weak self] in self?.rangeStart = nil; self?.reload() })
            }
            let card = Card(bg: UIColor(hex: 0xFFF3E0), radius: 12, border: C.gold,
                            padding: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
            card.add(hstack(items, spacing: 8))
            out.append(padded(card, UIEdgeInsets(top: 0, left: 16, bottom: 4, right: 16)))
        }
        return out
    }

    override func rowView(for w: Word, index: Int) -> UIView {
        let on = store.isPicked(w.id)
        let isStart = w.id == rangeStart?.id
        var style = RowStyle()
        if isStart { style = RowStyle(bg: UIColor(hex: 0xFFF8E1), border: C.gold, borderWidth: 2) }
        else if on { style = RowStyle(bg: UIColor(hex: 0xE8F5E9), border: C.good, borderWidth: 1.5) }
        let trailing: UIView = isStart ? pill("START", C.gold) : lbl(on ? "☑" : "☐", 24, .regular, on ? C.good : C.muted)
        return makeWordRow(w, index: w.id, mastered: false, trailing: trailing, style: style)
    }

    override func didSelect(_ w: Word, index: Int) {
        if rangeMode {
            if let s = rangeStart {
                if let si = shown.firstIndex(where: { $0.id == s.id }) {
                    let lo = min(si, index), hi = max(si, index)
                    store.addPicked(shown[lo...hi].map { $0.id })
                }
                rangeStart = nil
                rangeMode = false
                reload()
            } else {
                rangeStart = w
                reload()
            }
        } else {
            store.setPicked(w.id, !store.isPicked(w.id))
        }
    }

    private func showRange() {
        let d = RangeDialog(words: words) { [weak self] ids, mode in
            guard let self = self else { return }
            switch mode {
            case .add: self.store.addPicked(ids)
            case .replace: self.store.replacePicked(ids)
            case .remove: self.store.removePicked(ids)
            }
        }
        present(d, animated: true, completion: nil)
    }
}
