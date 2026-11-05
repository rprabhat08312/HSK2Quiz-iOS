import UIKit

final class QuizViewController: PageViewController {
    private let mode: Mode
    private let count: Int
    private let scopeKind: Int
    private let store = Store.shared
    private let speaker = Speaker.shared
    private let lex = AppContext.lex

    private var optionPool = [Word]()
    private var targets = [Word]()
    private var idx = 0
    private var picked: Word?
    private var score = 0
    private var missed = [Word]()
    private var q: Question!

    init(mode: Mode, count: Int, scope: Int) {
        self.mode = mode; self.count = count; self.scopeKind = scope
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let pool = store.scopeWords(lex.words)
        optionPool = scopeKind != SCOPE_ALL ? pool : lex.all
        targets = pickRound(pool, store, count)
        if targets.isEmpty { Router.home(); return }
        nextQuestion()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        speaker.stop()
    }

    private func nextQuestion() {
        picked = nil
        q = makeQuestion(optionPool, targets[idx], mode, fallback: lex.all)
        render()
        scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
        if mode == .listen && speaker.ready {
            let i = idx
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self, self.idx == i, self.picked == nil else { return }
                self.speaker.speak(self.q.target.hanzi)
            }
        }
    }

    private func render() {
        clearStack()
        let answered = picked != nil

        // top bar
        let close = textButton("✕", C.muted, size: 20) { Router.home() }
        close.translatesAutoresizingMaskIntoConstraints = false
        close.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let bar = Bar(fillColor: C.red)
        bar.progress = CGFloat(idx + (answered ? 1 : 0)) / CGFloat(targets.count)
        let counter = lbl("Question \(idx + 1) of \(targets.count)", 14, .bold, C.red, lines: 1)
        counter.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(padded(hstack([close, bar, counter], spacing: 8), UIEdgeInsets(top: 8, left: 8, bottom: 0, right: 16)))
        bar.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)

        if scopeKind != SCOPE_ALL {
            let p = pill(scopeKind == SCOPE_PICKED ? "Picked words only" : "Learned words only", C.teal)
            stack.addArrangedSubview(padded(hstack([flexSpacer(), p, flexSpacer()]), UIEdgeInsets(top: 8, left: 16, bottom: 0, right: 16)))
        }

        // question card
        let card = Card(radius: 24, shadow: true, padding: UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16))
        card.stack.alignment = .center
        card.add(lbl("Question \(idx + 1) of \(targets.count)", 16, .heavy, C.red, align: .center))
        card.add(spacer(4))
        switch mode {
        case .listen:
            card.add(lbl("Which word did you hear?", 15, .regular, C.muted, align: .center))
            card.add(spacer(16))
            card.add(speakButton(96) { [weak self] in guard let s = self else { return }; s.speaker.speak(s.q.target.hanzi) })
            card.add(spacer(8))
            card.add(lbl("Tap to hear again", 12, .regular, C.muted, align: .center))
        case .hanzi:
            card.add(lbl("Choose the correct pinyin", 15, .regular, C.muted, align: .center))
            card.add(spacer(8))
            let h = lbl(q.target.hanzi, 64, .bold, C.ink, align: .center, lines: 1)
            h.adjustsFontSizeToFitWidth = true
            h.minimumScaleFactor = 0.4
            card.add(h)
            card.add(spacer(8))
            card.add(speakButton(44) { [weak self] in guard let s = self else { return }; s.speaker.speak(s.q.target.hanzi) })
        case .meaning:
            card.add(lbl("Choose the Chinese word", 15, .regular, C.muted, align: .center))
            card.add(spacer(12))
            card.add(lbl(q.target.meaningLine(), 24, .bold, C.ink, align: .center))
        }
        addPadded(card, top: 12)

        if speaker.missing {
            addPadded(lbl("No Chinese voice found. Install a Chinese voice in iPad Settings > Accessibility > Spoken Content > Voices to hear audio.",
                          12, .regular, C.red), top: 8)
        }
        stack.addArrangedSubview(spacer(16))

        // options
        for (i, w) in q.options.enumerated() {
            let state: Int
            if !answered { state = 0 }
            else if w.id == q.target.id { state = 1 }
            else if w.id == picked?.id { state = 2 }
            else { state = 3 }
            let oc = optionCard(w, state: state, revealed: answered, index: i + 1)
            oc.onTap { [weak self] in self?.tapped(w) }
            addPadded(oc, bottom: 10)
        }

        if answered {
            let ok = picked?.id == q.target.id
            addPadded(lbl(ok ? "✔ Correct!" : "✘ Answer: \(q.target.hanzi)  \(q.target.pinyin)", 17, .bold, ok ? C.good : C.red), top: 0)
            addPadded(lbl("Tap any option to see its explanation.", 12, .regular, C.muted), top: 2, bottom: 10)
            let last = idx + 1 >= targets.count
            addPadded(filledButton(last ? "See results" : "Next", C.red) { [weak self] in self?.advance() })
        }
        stack.addArrangedSubview(spacer(24))
    }

    private func tapped(_ w: Word) {
        if picked == nil {
            let ok = w.id == q.target.id
            picked = w
            store.record(q.target.id, ok)
            if ok { score += 1 } else { missed.append(q.target) }
            speaker.speak(q.target.hanzi)
            render()
        } else {
            Router.openWord(w, vs: q.target)
        }
    }

    private func advance() {
        if idx + 1 >= targets.count {
            Router.replace(ResultViewController(mode: mode, count: count, score: score, total: targets.count,
                                                missed: missed, scope: scopeKind))
        } else {
            idx += 1
            nextQuestion()
        }
    }

    private func optionCard(_ w: Word, state: Int, revealed: Bool, index: Int) -> UIView {
        let bg: UIColor = state == 1 ? UIColor(hex: 0xE8F5E9) : (state == 2 ? UIColor(hex: 0xFFEBEE) : .white)
        let bd: UIColor = state == 1 ? C.good : (state == 2 ? C.red : C.line)
        let card = Card(bg: bg, radius: 18, border: bd, borderWidth: (state == 1 || state == 2) ? 2 : 1,
                        padding: UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18))
        var col = [UIView]()
        if mode == .hanzi { col.append(pinyinLabel(w.pinyin, 26)) }
        else { col.append(lbl(w.hanzi, 32, .bold)) }
        if revealed {
            if mode == .hanzi { col.append(lbl(w.hanzi, 20, .bold)) }
            else { col.append(pinyinLabel(w.pinyin, 16)) }
            col.append(lbl(w.meaningLine(), 13, .regular, C.muted))
            if let lp = levelPill(w) { col.append(spacer(4)); col.append(hstack([lp, flexSpacer()])) }
        }
        let colStack = vstack(col, spacing: 1)
        colStack.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        var items = [UIView]()
        let n = lbl("\(index).", 18, .bold, C.muted)
        n.setContentHuggingPriority(.required, for: .horizontal)
        items.append(n)
        items.append(colStack)
        if revealed {
            let mark = state == 1 ? "✔" : (state == 2 ? "✘" : "ⓘ")
            let mc: UIColor = state == 1 ? C.good : (state == 2 ? C.red : C.muted)
            items.append(lbl(mark, 22, .bold, mc))
        }
        card.add(hstack(items, spacing: 12))
        return card
    }
}

// MARK: - results

final class ResultViewController: PageViewController {
    private let mode: Mode
    private let count: Int
    private let score: Int
    private let total: Int
    private let missed: [Word]
    private let scopeKind: Int

    init(mode: Mode, count: Int, score: Int, total: Int, missed: [Word], scope: Int) {
        self.mode = mode; self.count = count; self.score = score; self.total = total
        self.missed = missed; self.scopeKind = scope
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        stack.addArrangedSubview(spacer(24))
        stack.addArrangedSubview(lbl("\(score) / \(total)", 56, .heavy, C.red, align: .center))
        let msg: String
        if score == total { msg = "Perfect! 完美!" }
        else if Double(score) >= Double(total) * 0.7 { msg = "Great job! 很好!" }
        else { msg = "Keep going! 加油!" }
        stack.addArrangedSubview(lbl(msg, 20, .bold, C.ink, align: .center))
        if scopeKind != SCOPE_ALL {
            stack.addArrangedSubview(lbl(scopeKind == SCOPE_PICKED ? "Picked words only" : "Learned words only",
                                         13, .bold, C.teal, align: .center))
        }
        stack.addArrangedSubview(spacer(20))
        if !missed.isEmpty {
            addPadded(lbl("Review these (\(missed.count))", 16, .bold), side: 20, bottom: 8)
            for (i, w) in missed.enumerated() {
                let row = makeWordRow(w, index: i + 1, mastered: false)
                row.onTap { Router.openWord(w) }
                addPadded(row, side: 20, bottom: 8)
            }
        }
        stack.addArrangedSubview(spacer(12))
        let m = mode, c = count, s = scopeKind
        addPadded(filledButton("Play again (\(count) questions)", C.red) {
            Router.replace(QuizViewController(mode: m, count: c, scope: s))
        }, side: 20)
        let home = textButton("Home", C.muted, size: 16) { Router.home() }
        stack.addArrangedSubview(home)
        stack.addArrangedSubview(spacer(24))
    }
}
