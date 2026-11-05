import UIKit

/// The word explanation sheet (Meaning / Words / Confusable). iOS 12 has no system bottom sheet,
/// so this is a custom panel sliding over a dimmed background.
final class DetailViewController: UIViewController {
    private var word: Word
    private var vs: Word?
    private var tab = 0
    private let store = Store.shared
    private let speaker = Speaker.shared
    private let lex = AppContext.lex
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private lazy var singles: [Character: Word] = {
        var m = [Character: Word]()
        for w in lex.words where w.hanzi.count == 1 { m[w.hanzi.first!] = w }
        return m
    }()

    init(word: Word, vs: Word?) {
        self.word = word; self.vs = vs
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .coverVertical
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let dim = UIView()
        dim.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dim)
        dim.pin(view)
        dim.onTap { [weak self] in self?.dismiss(animated: true, completion: nil) }

        let panel = UIView()
        panel.backgroundColor = .white
        panel.layer.cornerRadius = 24
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        let lead = panel.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        lead.priority = UILayoutPriority(750)
        let trail = panel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        trail.priority = UILayoutPriority(750)
        NSLayoutConstraint.activate([
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.widthAnchor.constraint(lessThanOrEqualToConstant: 640),
            lead, trail,
            panel.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.88),
        ])

        let handle = UIView()
        handle.backgroundColor = UIColor(hex: 0xD9CFC6)
        handle.layer.cornerRadius = 2.5
        handle.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(handle)
        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            handle.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 36),
            handle.heightAnchor.constraint(equalToConstant: 5),
        ])

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        panel.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: panel.topAnchor, constant: 24),
            scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
        ])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Store.didChange, object: nil)
        render()
    }

    @objc private func refresh() { render() }

    private func section(_ t: String) -> UIView {
        return padded(lbl(t, 13, .bold, C.muted), UIEdgeInsets(top: 14, left: 0, bottom: 8, right: 0))
    }

    private func show(_ w: Word) {
        word = w; vs = nil; tab = 0
        render()
        scroll.setContentOffset(.zero, animated: false)
    }

    private func render() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        let w = word
        let related = relatedWords(w, lex.words)
        let confusables = confusablesOf(w, lex.all)

        // header
        let hz = lbl(w.hanzi, w.hanzi.count <= 2 ? 44 : 30, .heavy, C.ink, lines: 1)
        hz.adjustsFontSizeToFitWidth = true
        hz.minimumScaleFactor = 0.5
        hz.setContentHuggingPriority(.required, for: .horizontal)
        let sp = speakButton(40) { [weak self] in self?.speaker.speak(w.hanzi) }
        let bm = UIButton(type: .system)
        bm.setTitle("🔖", for: .normal)
        bm.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        bm.alpha = store.isBookmarked(w.id) ? 1 : 0.35
        bm.translatesAutoresizingMaskIntoConstraints = false
        bm.widthAnchor.constraint(equalToConstant: 40).isActive = true
        bm.heightAnchor.constraint(equalToConstant: 40).isActive = true
        bm.onTouch { [weak self] in self?.store.toggleBookmark(w.id) }
        var pills = [UIView]()
        if let lp = levelPill(w) { pills.append(lp) }
        if !w.pos.trimmingCharacters(in: .whitespaces).isEmpty { pills.append(pill(posLong(w.pos), UIColor(hex: 0xFFF0D6), UIColor(hex: 0x8A5A00))) }
        pills.append(flexSpacer())
        let info = vstack([pinyinLabel(w.pinyin, 20), spacer(4), hstack(pills, spacing: 6)])
        info.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        stack.addArrangedSubview(hstack([hz, sp, bm, info], spacing: 8))
        if speaker.missing {
            stack.addArrangedSubview(padded(lbl("No Chinese voice installed on this iPad.", 12, .regular, C.red),
                                            UIEdgeInsets(top: 6, left: 0, bottom: 0, right: 0)))
        }

        if let v = vs {
            let msg = v.id == w.id ? "This is the correct answer." : "Why it is confusable with \(v.hanzi): \(confusionNote(v, w))"
            let c = Card(bg: UIColor(hex: 0xFFF3E0), radius: 14, padding: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
            c.add(lbl(msg, 14))
            stack.addArrangedSubview(padded(c, UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)))
        }

        // tabs
        let tabBar = UIView()
        tabBar.backgroundColor = UIColor(hex: 0xF1EEE8)
        tabBar.layer.cornerRadius = 12
        var tabViews = [UIView]()
        for (i, name) in ["Meaning", "Words", "Confusable"].enumerated() {
            let l = PillLabel()
            l.text = name
            l.textAlignment = .center
            l.insets = UIEdgeInsets(top: 9, left: 4, bottom: 9, right: 4)
            l.font = UIFont.systemFont(ofSize: 14, weight: tab == i ? .bold : .medium)
            l.textColor = C.ink
            l.backgroundColor = tab == i ? .white : .clear
            l.onTap { [weak self] in self?.tab = i; self?.render() }
            tabViews.append(l)
        }
        let tabs = hstack(tabViews, spacing: 0, align: .fill, dist: .fillEqually)
        tabBar.addSubview(tabs)
        tabs.pin(tabBar, UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        stack.addArrangedSubview(padded(tabBar, UIEdgeInsets(top: 14, left: 0, bottom: 0, right: 0)))

        switch tab {
        case 0: renderMeaning(w, related)
        case 1: renderWords(w, related)
        default: renderConfusable(w, confusables)
        }
    }

    private func renderMeaning(_ w: Word, _ related: [Word]) {
        stack.addArrangedSubview(section("Meaning"))
        stack.addArrangedSubview(lbl(w.meaningLine(), 20))
        stack.addArrangedSubview(spacer(14))
        stack.addArrangedSubview(hstack([flexSpacer(), hanziBox(w.hanzi, box: 120, font: 72), flexSpacer()]))

        if let lens = lensTagsView(w.hanzi) {
            stack.addArrangedSubview(section("Four lenses"))
            stack.addArrangedSubview(lens)
        }

        var seen = Set<Character>()
        let parts = w.hanzi.filter { c in
            if singles[c] != nil && !seen.contains(c) { seen.insert(c); return true }
            return false
        }
        if w.hanzi.count > 1 && !parts.isEmpty {
            stack.addArrangedSubview(section("Character by character"))
            for (i, c) in parts.enumerated() {
                guard let s = singles[c] else { continue }
                let n = lbl("\(i + 1).", 13, .bold, C.muted); n.translatesAutoresizingMaskIntoConstraints = false
                n.widthAnchor.constraint(equalToConstant: 28).isActive = true
                let h = lbl(String(c), 24, .bold); h.translatesAutoresizingMaskIntoConstraints = false
                h.widthAnchor.constraint(equalToConstant: 40).isActive = true
                let en = lbl("  \(s.english)", 13, .regular, C.muted)
                en.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
                let row = hstack([n, h, pinyinLabel(s.pinyin, 15), en], spacing: 0)
                row.onTap { [weak self] in self?.show(s) }
                stack.addArrangedSubview(padded(row, UIEdgeInsets(top: 0, left: 0, bottom: 6, right: 0)))
            }
        }

        stack.addArrangedSubview(section("Words"))
        for (i, r) in ([w] + related).enumerated() {
            let card = Card(radius: 14, border: C.line, padding: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
            let n = lbl("\(i + 1).", 13, .bold, C.muted); n.translatesAutoresizingMaskIntoConstraints = false
            n.widthAnchor.constraint(equalToConstant: 32).isActive = true
            var items: [UIView] = [n]
            if let lp = levelPill(r) { items.append(lp); items.append(spacer10()) }
            items.append(lbl(r.hanzi, 18, .bold))
            items.append(spacer10())
            let en = lbl(r.english, 13, .regular, C.muted)
            en.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
            items.append(en)
            items.append(lbl("›", 20, .regular, C.muted))
            card.add(hstack(items, spacing: 0))
            card.onTap { [weak self] in
                guard let self = self else { return }
                if r.id == w.id { self.tab = 1; self.render() } else { self.show(r) }
            }
            stack.addArrangedSubview(padded(card, UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)))
        }
    }

    private func spacer10() -> UIView {
        let v = UIView(); v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 10).isActive = true
        return v
    }

    private func wordCard(_ w: Word, tap: (() -> Void)?) -> UIView {
        let card = Card(radius: 14, border: C.line, padding: UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        var head = [UIView]()
        if let lp = levelPill(w) { head.append(lp) }
        head.append(lbl(w.hanzi, 20, .bold))
        head.append(pinyinLabel(w.pinyin, 14))
        head.append(flexSpacer())
        card.add(hstack(head, spacing: 8))
        card.add(spacer(6))
        card.add(lbl(w.meaningLine(), 14))
        if !w.example.trimmingCharacters(in: .whitespaces).isEmpty {
            card.add(spacer(8))
            let ex = Card(bg: C.soft, radius: 10, padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12), spacing: 2)
            ex.add(lbl("🔊  \(w.example)", 16))
            ex.add(lbl(w.exampleEn, 13, .regular, C.muted))
            ex.onTap { [weak self] in self?.speaker.speak(w.example) }
            card.add(ex)
        }
        if let t = tap { card.onTap(t) }
        return card
    }

    private func renderWords(_ w: Word, _ related: [Word]) {
        stack.addArrangedSubview(section("Words"))
        let all = [w] + related
        for (i, r) in all.enumerated() {
            let n = lbl("\(i + 1).", 14, .bold, C.muted)
            n.translatesAutoresizingMaskIntoConstraints = false
            n.widthAnchor.constraint(equalToConstant: 28).isActive = true
            let tapAction: (() -> Void)? = i == 0 ? nil : { [weak self] in self?.show(r) }
            let card = wordCard(r, tap: tapAction)
            let row = hstack([n, card], spacing: 4, align: .top)
            stack.addArrangedSubview(padded(row, UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)))
        }
    }

    private func renderConfusable(_ w: Word, _ confusables: [Word]) {
        stack.addArrangedSubview(section("Confusable"))
        let base = Card(radius: 14, border: C.line, padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        base.stack.alignment = .center
        var tags: [UIView] = [pill("Recognize", C.teal)]
        if let lp = levelPill(w) { tags.append(lp) }
        tags.append(flexSpacer())
        let tagRow = hstack(tags, spacing: 6)
        base.add(tagRow)
        tagRow.widthAnchor.constraint(equalTo: base.stack.widthAnchor).isActive = true
        base.add(spacer(8))
        base.add(hanziBox(w.hanzi, box: 96, font: 60))
        base.add(spacer(6))
        base.add(pinyinLabel(w.pinyin, 16, .semibold, align: .center))
        base.add(lbl(w.meaningLine(), 14, .regular, C.ink, align: .center))
        stack.addArrangedSubview(base)
        stack.addArrangedSubview(spacer(10))
        if confusables.isEmpty {
            stack.addArrangedSubview(lbl("No close look-alikes found for this word.", 13, .regular, C.muted))
        }
        var i = 0
        while i < confusables.count {
            var cells = [UIView]()
            for c in confusables[i..<min(i + 2, confusables.count)] { cells.append(confusableCard(w, c)) }
            if cells.count == 1 { cells.append(UIView()) }
            let row = hstack(cells, spacing: 10, align: .fill, dist: .fillEqually)
            stack.addArrangedSubview(padded(row, UIEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)))
            i += 2
        }
    }

    private func confusableCard(_ base: Word, _ c: Word) -> UIView {
        let card = Card(radius: 14, border: C.line, padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        card.stack.alignment = .center
        var tags: [UIView] = [pill(confusionTag(base, c), C.teal)]
        if let lp = levelPill(c) { tags.append(lp) }
        tags.append(flexSpacer())
        let tagRow = hstack(tags, spacing: 6)
        card.add(tagRow)
        tagRow.widthAnchor.constraint(equalTo: card.stack.widthAnchor).isActive = true
        card.add(spacer(8))
        card.add(hanziBox(c.hanzi, box: 72, font: 44))
        card.add(spacer(6))
        card.add(pinyinLabel(c.pinyin, 15, .semibold, align: .center))
        card.add(lbl(c.meaningLine(), 12, .regular, C.muted, align: .center))
        card.onTap { [weak self] in self?.show(c) }
        return card
    }
}
