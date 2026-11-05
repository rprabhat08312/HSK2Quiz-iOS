import UIKit

private var changeKey: UInt8 = 0

extension UITextField {
    /// Calls `f` whenever the text changes.
    func onChange(_ f: @escaping () -> Void) {
        let s = ClosureSleeve(f)
        addTarget(s, action: #selector(ClosureSleeve.invoke), for: .editingChanged)
        objc_setAssociatedObject(self, &changeKey, s, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    var digits: String { return String((text ?? "").filter { $0.isNumber }.prefix(3)) }
}

// MARK: - "How many questions?" before a quiz

final class QuizCountDialog: DialogViewController, UITextFieldDelegate {
    private let mode: Mode
    private let maxWords: Int
    private let onStart: (Int) -> Void
    private let field = styledField(placeholder: "", keyboard: .numberPad)
    private var chips = [(Int, ChipButton)]()
    private var startBtn: UIButton!
    private var errLabel: UILabel!

    init(mode: Mode, maxWords: Int, onStart: @escaping (Int) -> Void) {
        self.mode = mode; self.maxWords = maxWords; self.onStart = onStart
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }

    private var value: Int? {
        if let n = Int(field.digits), n >= 1, n <= maxWords { return n }
        return nil
    }

    override func buildBody() {
        body.addArrangedSubview(lbl("How many questions should contain in one quiz?", 18, .bold))
        body.addArrangedSubview(lbl("\(mode.title) · \(mode.sub)", 13, .regular, C.muted))
        body.addArrangedSubview(spacer(2))
        body.addArrangedSubview(lbl("Select question count:", 14, .bold))

        let cur = min(Store.shared.quizCount, maxWords)
        field.text = "\(cur)"
        field.placeholder = "Custom number (1–\(maxWords))"
        field.delegate = self

        var views = [UIView]()
        for n in [5, 10, 20, 30, 50, 100, maxWords] where !chips.contains(where: { $0.0 == n }) && n <= maxWords {
            let c = ChipButton(n == maxWords ? "All (\(maxWords))" : "\(n)", on: n == cur, size: 13) { [weak self] in
                self?.field.text = "\(n)"
                self?.refresh()
            }
            chips.append((n, c)); views.append(c)
        }
        body.addArrangedSubview(hscroll(views, spacing: 6, height: 38))
        body.addArrangedSubview(field)
        errLabel = lbl("Enter a number from 1 to \(maxWords).", 12, .regular, C.red)
        body.addArrangedSubview(errLabel)
        field.onChange { [weak self] in
            guard let self = self else { return }
            self.field.text = self.field.digits
            self.refresh()
        }

        let cancel = textButton("Cancel", C.muted, size: 15) { [weak self] in self?.close() }
        startBtn = filledButton("Start Quiz", C.red, size: 15, height: 44, radius: 12) { [weak self] in
            guard let self = self, let n = self.value else { return }
            Store.shared.setCount(n)
            self.dismiss(animated: true) { self.onStart(n) }
        }
        let row = hstack([flexSpacer(), cancel, startBtn], spacing: 14)
        startBtn.widthAnchor.constraint(equalToConstant: 130).isActive = true
        body.addArrangedSubview(row)
        refresh()
    }

    private func refresh() {
        let v = value
        for (n, c) in chips { c.setOn(v == n) }
        field.layer.borderColor = (v == nil ? C.red : C.line).cgColor
        errLabel.isHidden = v != nil
        startBtn.isEnabled = v != nil
        startBtn.alpha = v != nil ? 1 : 0.5
    }

    func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }
}

// MARK: - word range (serial number / letter) for Pick words

enum RangeApplyMode { case add, replace, remove }

final class RangeDialog: DialogViewController, UITextFieldDelegate {
    private let words: [Word]
    private let apply: ([Int], RangeApplyMode) -> Void
    private var tab = 0
    private let fromNum: UITextField = styledField(placeholder: "From #", keyboard: .numberPad)
    private let toNum: UITextField = styledField(placeholder: "To #", keyboard: .numberPad)
    private var fromLetter: Character = "A"
    private var toLetter: Character = "C"
    private let content = UIStackView()
    private let summary = UIStackView()
    private var tabLabels = [UILabel]()
    private var addBtn: UIButton!
    private var replBtn: UIButton!

    init(words: [Word], apply: @escaping ([Int], RangeApplyMode) -> Void) {
        self.words = words; self.apply = apply
        super.init()
    }
    required init?(coder: NSCoder) { fatalError() }

    private var targets: [Word] {
        if tab == 0 {
            let a = max(1, min(words.count, Int(fromNum.digits) ?? 1))
            let b = max(1, min(words.count, Int(toNum.digits) ?? 1))
            let r = min(a, b)...max(a, b)
            return words.filter { r.contains($0.id) }
        }
        let lo = min(fromLetter, toLetter), hi = max(fromLetter, toLetter)
        return words.filter { w in
            guard let f = w.plain.uppercased().first else { return false }
            return f >= lo && f <= hi
        }
    }

    override func buildBody() {
        fromNum.text = "1"; toNum.text = "50"
        fromNum.delegate = self; toNum.delegate = self
        fromNum.onChange { [weak self] in self?.fromNum.text = self?.fromNum.digits; self?.refreshSummary() }
        toNum.onChange { [weak self] in self?.toNum.text = self?.toNum.digits; self?.refreshSummary() }

        body.addArrangedSubview(lbl("Select Word Range", 18, .bold))
        body.addArrangedSubview(lbl("Select words by serial number or letter range", 12, .regular, C.muted))

        // tab switcher
        let bar = UIView(); bar.backgroundColor = C.soft; bar.layer.cornerRadius = 12
        let t0 = tabLabel("Serial # (1–\(words.count))", 0), t1 = tabLabel("Letter Range (A–Z)", 1)
        tabLabels = [t0, t1]
        let tabs = hstack([t0, t1], spacing: 4, align: .fill, dist: .fillEqually)
        bar.addSubview(tabs); tabs.pin(bar, UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        body.addArrangedSubview(bar)

        content.axis = .vertical; content.spacing = 10
        body.addArrangedSubview(content)
        summary.axis = .vertical; summary.spacing = 2
        let sc = Card(bg: C.soft, radius: 12, border: C.line, padding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        sc.add(summary)
        body.addArrangedSubview(sc)

        addBtn = filledButton("Add Range", C.teal, size: 12, height: 40, radius: 10) { [weak self] in self?.go(.add) }
        replBtn = filledButton("Select ONLY Range", C.red, size: 12, height: 40, radius: 10) { [weak self] in self?.go(.replace) }
        let cancel = textButton("Cancel", C.muted, size: 15) { [weak self] in self?.close() }
        body.addArrangedSubview(hstack([addBtn, replBtn], spacing: 8, align: .fill, dist: .fillEqually))
        body.addArrangedSubview(cancel)
        rebuildContent()
    }

    private func tabLabel(_ t: String, _ i: Int) -> UILabel {
        let l = PillLabel()
        l.text = t; l.textAlignment = .center
        l.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        l.insets = UIEdgeInsets(top: 9, left: 4, bottom: 9, right: 4)
        l.onTap { [weak self] in self?.tab = i; self?.rebuildContent() }
        return l
    }

    private func go(_ m: RangeApplyMode) {
        let ids = targets.map { $0.id }
        if ids.isEmpty { return }
        apply(ids, m)
        close()
    }

    private func rebuildContent() {
        for (i, l) in tabLabels.enumerated() {
            l.backgroundColor = i == tab ? C.red : .clear
            l.textColor = i == tab ? .white : C.ink
        }
        for v in content.arrangedSubviews { content.removeArrangedSubview(v); v.removeFromSuperview() }
        content.addArrangedSubview(lbl("Presets:", 12, .bold))
        if tab == 0 {
            var presets = [(Int, Int)]()
            if words.count > HSK1_WORDS { presets.append((HSK1_WORDS + 1, words.count)) }
            var st = 1
            while st <= words.count { presets.append((st, min(st + 49, words.count))); st += 50 }
            let chips = presets.map { (a, b) -> UIView in
                ChipButton("\(a)–\(b)", on: false, size: 12) { [weak self] in
                    self?.fromNum.text = "\(a)"; self?.toNum.text = "\(b)"; self?.refreshSummary()
                }
            }
            content.addArrangedSubview(hscroll(chips, spacing: 6, height: 36))
            let to = lbl("to", 14, .bold, C.muted)
            content.addArrangedSubview(hstack([fromNum, to, toNum], spacing: 8, dist: .fill))
            fromNum.widthAnchor.constraint(equalTo: toNum.widthAnchor).isActive = true
        } else {
            let pairs: [(Character, Character)] = [("A", "C"), ("D", "G"), ("H", "L"), ("M", "R"), ("S", "W"), ("X", "Z")]
            let chips = pairs.map { (a, b) -> UIView in
                ChipButton("\(a)–\(b)", on: false, size: 12) { [weak self] in
                    self?.fromLetter = a; self?.toLetter = b; self?.rebuildContent()
                }
            }
            content.addArrangedSubview(hscroll(chips, spacing: 6, height: 36))
            content.addArrangedSubview(lbl("From Letter:", 12, .bold))
            content.addArrangedSubview(letterRow(selected: fromLetter) { [weak self] c in self?.fromLetter = c; self?.rebuildContent() })
            content.addArrangedSubview(lbl("To Letter:", 12, .bold))
            content.addArrangedSubview(letterRow(selected: toLetter) { [weak self] c in self?.toLetter = c; self?.rebuildContent() })
        }
        refreshSummary()
    }

    private func letterRow(selected: Character, pick: @escaping (Character) -> Void) -> UIView {
        let views = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { ch -> UIView in
            let b = UIButton(type: .system)
            b.setTitle(String(ch), for: .normal)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            let sel = ch == selected
            b.setTitleColor(sel ? .white : C.ink, for: .normal)
            b.backgroundColor = sel ? C.red : C.soft
            b.layer.cornerRadius = 16
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 32).isActive = true
            b.heightAnchor.constraint(equalToConstant: 32).isActive = true
            b.onTouch { pick(ch) }
            return b
        }
        return hscroll(views, spacing: 4, height: 34)
    }

    private func refreshSummary() {
        for v in summary.arrangedSubviews { summary.removeArrangedSubview(v); v.removeFromSuperview() }
        let t = targets
        summary.addArrangedSubview(lbl("\(t.count) words in range", 13, .bold))
        if let f = t.first, let l = t.last {
            summary.addArrangedSubview(lbl("#\(f.id) \(f.hanzi) (\(f.pinyin)) ➔ #\(l.id) \(l.hanzi) (\(l.pinyin))", 12, .regular, C.muted))
        } else {
            summary.addArrangedSubview(lbl("No words found in this range", 12, .regular, C.red))
        }
        addBtn?.isEnabled = !t.isEmpty; replBtn?.isEnabled = !t.isEmpty
        addBtn?.alpha = t.isEmpty ? 0.5 : 1; replBtn?.alpha = t.isEmpty ? 0.5 : 1
    }

    func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }
}
