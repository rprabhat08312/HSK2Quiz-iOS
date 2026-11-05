import UIKit

final class HomeViewController: PageViewController, UITextFieldDelegate {
    private let store = Store.shared
    private var lex: Lexicon { return AppContext.lex }
    private var heroTop: NSLayoutConstraint?
    private var countField: UITextField?

    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        scroll.contentInsetAdjustmentBehavior = .never
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Store.didChange, object: nil)
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rebuild()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        heroTop?.constant = view.safeAreaInsets.top + 28
    }

    @objc private func refresh() {
        if countField?.isFirstResponder == true { return }
        rebuild()
    }

    // MARK: build

    private func rebuild() {
        clearStack()
        let words = lex.words
        let mastered = store.masteredCount(words)
        let acc = store.totalAnswered == 0 ? 0 : store.totalRight * 100 / store.totalAnswered

        stack.addArrangedSubview(hero(words.count))

        // stats card
        let statsCard = Card(shadow: true, padding: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))
        statsCard.add(hstack([stat("\(mastered)", "mastered"), stat("\(acc)%", "accuracy"), stat("\(store.bestStreak)", "best streak")],
                             align: .center, dist: .fillEqually))
        statsCard.add(spacer(14))
        let bar = Bar(fillColor: C.gold)
        bar.progress = words.isEmpty ? 0 : CGFloat(mastered) / CGFloat(words.count)
        statsCard.add(bar)
        statsCard.add(spacer(6))
        statsCard.add(lbl("\(mastered) of \(words.count) words mastered", 12, .regular, C.muted))
        statsCard.add(spacer(10))
        let sw = UISwitch()
        sw.isOn = store.showLevel
        sw.onTintColor = C.olive
        sw.onTouchValue { [weak self] on in self?.store.showLevel = on }
        let swText = vstack([lbl("Show HSK level labels", 14, .semibold),
                             lbl("Turn off to hide the \"HSK 1\" / \"HSK 2\" tag on words", 11, .regular, C.muted)], spacing: 2)
        statsCard.add(hstack([swText, sw], spacing: 10))
        addPadded(statsCard, top: 16)

        // feature cards
        addPadded(feature("写", C.gold, C.ink, C.gold, "Watch & learn",
                          "Stroke-order animation for all \(words.count) words  ·  \(store.learnedCount) learned", nil) {
            Router.comingSoon("Watch & learn", stage: 2) }, top: 14)
        addPadded(feature("源", C.red, .white, C.red, "Learn through historical animation",
                          "Watch each word grow from its old picture to today's form", nil) {
            Router.comingSoon("Historical animation", stage: 2) }, top: 10)
        addPadded(feature("🎈", C.blue, .white, C.blue, "Bubble Quiz",
                          "Pop floating bubbles with Hanzi, Roman font & meaning · Focuses on missed words", "Speed Control") {
            Router.comingSoon("Bubble Quiz", stage: 4) }, top: 10)
        addPadded(feature("故", C.olive, .white, C.olive, "Story time",
                          "A new story every time, made from your learned & picked words. Tap a line for Roman + English", nil) {
            Router.comingSoon("Story time", stage: 3) }, top: 10)
        addPadded(feature("配", C.purple, .white, C.purple, "Match & Recognize",
                          "Tell look-alike characters apart, and link words with similar meanings", nil) {
            Router.comingSoon("Match & Recognize", stage: 4) }, top: 10)
        addPadded(feature("四", C.red, .white, C.red, "Four lenses",
                          "Every word by radical, meaning, shape and history, with a test-yourself mode", nil) {
            Router.comingSoon("Four lenses", stage: 3) }, top: 10)
        addPadded(feature("📄", C.pink, .white, C.pink, "PDF Reader Mode",
                          "Upload Chinese PDFs with Pinyin, literal & grammatical meaning toggles + HSK #475.1 numbering", nil) {
            Router.comingSoon("PDF Reader", stage: 5) }, top: 10)
        if store.pickedCount > 0 {
            addPadded(feature(nil, C.teal, .white, C.teal, "Watch & learn picked words",
                              "Stroke order for only your \(store.pickedCount) picked words", nil) {
                Router.comingSoon("Watch & learn", stage: 2) }, top: 10)
        }

        // scope card
        let learnedN = store.learnedCount, pickedN = store.pickedCount, sc = store.scope
        let canQuiz: Bool = sc == SCOPE_LEARNED ? learnedN >= MIN_LEARNED : (sc == SCOPE_PICKED ? pickedN >= MIN_LEARNED : true)
        let scopeCard = Card(shadow: true, spacing: 8)
        scopeCard.add(lbl("Quiz on", 16, .bold))
        let chipsRow = hstack([
            ChipButton("All \(words.count)", on: sc == SCOPE_ALL) { [weak self] in self?.store.scope = SCOPE_ALL },
            ChipButton("Learned (\(learnedN))", on: sc == SCOPE_LEARNED) { [weak self] in self?.store.scope = SCOPE_LEARNED },
            ChipButton("Picked (\(pickedN))", on: sc == SCOPE_PICKED) { [weak self] in self?.store.scope = SCOPE_PICKED },
        ], spacing: 8, align: .fill, dist: .fillEqually)
        scopeCard.add(chipsRow)
        let hint: String
        switch sc {
        case SCOPE_LEARNED:
            hint = learnedN < MIN_LEARNED
                ? "Mark at least \(MIN_LEARNED) words as learned in Watch & learn first (you have \(learnedN))."
                : "Questions come only from the \(learnedN) words you marked as learned."
        case SCOPE_PICKED:
            hint = pickedN < MIN_LEARNED
                ? "Pick at least \(MIN_LEARNED) words first (you have \(pickedN))."
                : "Questions come only from the \(pickedN) words you picked."
        default: hint = "Questions come from all \(words.count) words."
        }
        scopeCard.add(lbl(hint, 12, .regular, canQuiz ? C.muted : C.red))
        if sc == SCOPE_PICKED {
            scopeCard.add(filledButton(pickedN == 0 ? "Choose words" : "Choose / change words", C.teal, size: 15, height: 46, radius: 14) {
                Router.push(PickViewController()) })
        }
        if sc == SCOPE_LEARNED && learnedN > 0 {
            let b = textButton("Clear learned list", C.muted, size: 12) { [weak self] in self?.store.clearLearned() }
            b.contentHorizontalAlignment = .left
            scopeCard.add(b)
        }
        addPadded(scopeCard, top: 14)

        addPadded(countPicker(total: words.count), top: 14)

        let h = lbl("Choose a quiz", 18, .bold)
        stack.addArrangedSubview(padded(h, UIEdgeInsets(top: 18, left: 20, bottom: 8, right: 20)))
        for m in Mode.allCases {
            let c = feature(m.badge, C.red, .white, nil, m.title, m.sub, nil, chevron: C.gold) { [weak self] in
                self?.startSetup(m)
            }
            c.alpha = canQuiz ? 1 : 0.45
            c.isUserInteractionEnabled = canQuiz
            addPadded(c, top: 6, bottom: 6)
        }

        addPadded(outlineButton("Browse all \(words.count) words", C.red) { Router.push(WordsViewController()) }, top: 12, bottom: 12)
        let reset = textButton("Reset progress", C.muted, size: 12) { [weak self] in self?.store.reset() }
        stack.addArrangedSubview(reset)
        stack.addArrangedSubview(spacer(24))
    }

    private func hero(_ n: Int) -> UIView {
        let g = GradientView(C.deepRed, C.red)
        let t = lbl("汉语 · HSK 2", 36, .heavy, .white)
        let s = lbl("\(n) words (HSK 1 + 2) · listen · read · recognise", 14, .regular, UIColor(hex: 0xFFD9D2))
        let col = vstack([t, spacer(4), s])
        g.addSubview(col)
        col.translatesAutoresizingMaskIntoConstraints = false
        let top = col.topAnchor.constraint(equalTo: g.topAnchor, constant: view.safeAreaInsets.top + 28)
        heroTop = top
        NSLayoutConstraint.activate([
            top,
            col.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -28),
            col.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24),
            col.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -24),
        ])
        return g
    }

    private func stat(_ value: String, _ label: String) -> UIView {
        return vstack([lbl(value, 26, .heavy, C.red, align: .center), lbl(label, 12, .regular, C.muted, align: .center)], align: .fill)
    }

    private func feature(_ badge: String?, _ badgeBg: UIColor, _ badgeFg: UIColor, _ border: UIColor?,
                         _ title: String, _ sub: String, _ pillText: String?, chevron: UIColor? = nil,
                         action: @escaping () -> Void) -> UIView {
        let card = Card(border: border, borderWidth: 1.5, shadow: true, padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        var items = [UIView]()
        if let b = badge {
            let box = UIView()
            box.backgroundColor = badgeBg
            box.layer.cornerRadius = 16
            let l = lbl(b, 28, .bold, badgeFg, align: .center)
            box.addSubview(l)
            l.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                l.centerXAnchor.constraint(equalTo: box.centerXAnchor),
                l.centerYAnchor.constraint(equalTo: box.centerYAnchor),
                box.widthAnchor.constraint(equalToConstant: 54),
                box.heightAnchor.constraint(equalToConstant: 54),
            ])
            items.append(box)
        }
        let tl = lbl(title, 17, .bold)
        var titleRow: UIView = tl
        if let p = pillText { titleRow = hstack([tl, pill(p, badgeBg), flexSpacer()], spacing: 6) }
        let col = vstack([titleRow, lbl(sub, 13, .regular, C.muted)], spacing: 2)
        items.append(col)
        items.append(lbl("›", 28, .bold, chevron ?? border ?? C.gold))
        let row = hstack(items, spacing: 16)
        col.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        card.add(row)
        card.onTap(action)
        return card
    }

    // MARK: count picker (shown on Home)

    private func countPicker(total: Int) -> UIView {
        let count = store.quizCount
        let card = Card(shadow: true, spacing: 10)
        let titleL = lbl("How many questions should contain in one quiz?", 16, .bold)
        let cnt = lbl("\(count)", 22, .heavy, C.red)
        cnt.setContentHuggingPriority(.required, for: .horizontal)
        card.add(hstack([titleL, cnt], spacing: 8))
        let chips = [5, 10, 20, 30, 50, 100, total].map { n -> UIView in
            ChipButton(n == total ? "All \(total)" : "\(n)", on: n == count, size: 14) { [weak self] in self?.store.setCount(n) }
        }
        card.add(hscroll(chips, spacing: 8, height: 40))
        let f = styledField(placeholder: "Custom number (1–\(total))", keyboard: .numberPad)
        f.text = "\(count)"
        f.delegate = self
        f.tag = total
        countField = f
        f.onChange { [unowned f] in
            f.text = f.digits
            let n = Int(f.digits) ?? 0
            f.layer.borderColor = (n >= 1 && n <= total ? C.line : C.red).cgColor
        }
        card.add(f)
        return card
    }

    func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }

    func textFieldDidEndEditing(_ tf: UITextField) {
        let total = tf.tag
        if let n = Int(tf.digits), n >= 1, n <= total { store.setCount(n) } else { rebuild() }
    }

    // MARK: start a quiz

    private func startSetup(_ m: Mode) {
        let maxWords = store.scopeWords(lex.words).count
        if maxWords == 0 { return }
        let d = QuizCountDialog(mode: m, maxWords: maxWords) { [weak self] n in
            guard let self = self else { return }
            Router.push(QuizViewController(mode: m, count: min(n, maxWords), scope: self.store.scope))
        }
        present(d, animated: true, completion: nil)
    }
}

// UISwitch value helper
private var switchKey: UInt8 = 0
extension UISwitch {
    func onTouchValue(_ f: @escaping (Bool) -> Void) {
        let s = ClosureSleeve { [unowned self] in f(self.isOn) }
        addTarget(s, action: #selector(ClosureSleeve.invoke), for: .valueChanged)
        objc_setAssociatedObject(self, &switchKey, s, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
