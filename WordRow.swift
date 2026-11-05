import UIKit

struct RowStyle {
    var bg: UIColor = .white
    var border: UIColor = C.line
    var borderWidth: CGFloat = 1
}

/// One word row: [index] hanzi | pinyin + english | ★ / bookmark / custom trailing view.
func makeWordRow(_ w: Word, index: Int?, mastered: Bool, trailing: UIView? = nil,
                 bookmark: (isOn: Bool, toggle: () -> Void)? = nil, style: RowStyle = RowStyle()) -> UIView {
    let card = Card(bg: style.bg, radius: 14, border: style.border, borderWidth: style.borderWidth,
                    padding: UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14))
    var items = [UIView]()
    if let i = index {
        let l = lbl("\(i).", 14, .bold, C.muted)
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: 38).isActive = true
        items.append(l)
    }
    let h = lbl(w.hanzi, 24, .bold, C.ink, lines: 1)
    h.adjustsFontSizeToFitWidth = true
    h.minimumScaleFactor = 0.5
    h.translatesAutoresizingMaskIntoConstraints = false
    h.widthAnchor.constraint(equalToConstant: 96).isActive = true
    items.append(h)
    let col = vstack([pinyinLabel(w.pinyin, 15), lbl(w.english, 12, .regular, C.muted)], spacing: 1)
    col.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
    items.append(col)
    if mastered { items.append(lbl("★", 18, .regular, C.gold)) }
    if let b = bookmark {
        let btn = UIButton(type: .system)
        btn.setTitle("🔖", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        btn.alpha = b.isOn ? 1 : 0.3
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        btn.onTouch(b.toggle)
        items.append(btn)
    }
    if let t = trailing { items.append(t) }
    card.add(hstack(items, spacing: 0))
    return card
}

final class WordCell: UITableViewCell {
    static let id = "WordCell"
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(_ v: UIView) {
        for s in contentView.subviews { s.removeFromSuperview() }
        contentView.addSubview(v)
        v.pin(contentView, UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16))
    }
}

func matches(_ w: Word, _ query: String) -> Bool {
    let s = query.trimmingCharacters(in: .whitespaces).lowercased()
    if s.isEmpty { return true }
    let st = stripTones(s)
    return w.hanzi.contains(s) || (!st.isEmpty && w.plain.contains(st)) || w.english.lowercased().contains(s)
}

/// Back arrow + title + optional trailing view, used at the top of list screens.
func screenHeader(title: String, subtitle: String? = nil, trailing: UIView? = nil, back: @escaping () -> Void) -> UIView {
    let b = UIButton(type: .system)
    b.setTitle("←", for: .normal)
    b.titleLabel?.font = UIFont.systemFont(ofSize: 22)
    b.setTitleColor(C.red, for: .normal)
    b.translatesAutoresizingMaskIntoConstraints = false
    b.widthAnchor.constraint(equalToConstant: 44).isActive = true
    b.heightAnchor.constraint(equalToConstant: 44).isActive = true
    b.onTouch(back)
    var col: [UIView] = [lbl(title, 18, .bold)]
    if let s = subtitle { col.append(lbl(s, 12, .regular, C.muted)) }
    let titleStack = vstack(col, spacing: 1)
    titleStack.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
    var items: [UIView] = [b, titleStack]
    if let t = trailing { items.append(t) }
    let row = hstack(items, spacing: 4)
    return padded(row, UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 12))
}

/// Base for the word-list screens (Browse words, Pick words).
class WordListBase: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    let store = Store.shared
    let words = AppContext.lex.words
    var query = ""
    var shown = [Word]()
    let table = UITableView(frame: .zero, style: .plain)
    private let headerHolder = UIStackView()
    private let extrasHolder = UIStackView()
    private let search = styledField(placeholder: "Search Chinese, pinyin or English")

    // override in subclasses
    var baseList: [Word] { return words }
    func makeHeader() -> UIView { return UIView() }
    func makeExtras() -> [UIView] { return [] }
    func rowView(for w: Word, index: Int) -> UIView { return makeWordRow(w, index: index + 1, mastered: false) }
    func didSelect(_ w: Word, index: Int) {}
    func emptyState() -> UIView? { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = C.cream
        headerHolder.axis = .vertical
        extrasHolder.axis = .vertical
        extrasHolder.spacing = 8
        search.delegate = self
        search.onChange { [weak self] in
            guard let self = self else { return }
            self.query = self.search.text ?? ""
            self.reload()
        }
        let searchWrap = padded(search, UIEdgeInsets(top: 4, left: 16, bottom: 8, right: 16))
        let top = vstack([headerHolder, searchWrap, extrasHolder])
        top.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.keyboardDismissMode = .onDrag
        table.register(WordCell.self, forCellReuseIdentifier: WordCell.id)
        table.estimatedRowHeight = 68
        table.rowHeight = UITableView.automaticDimension
        view.addSubview(table)
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.topAnchor.constraint(equalTo: top.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged), name: Store.didChange, object: nil)
        reload()
    }

    @objc private func storeChanged() { reload() }

    func reload() {
        shown = baseList.filter { matches($0, query) }
        for v in headerHolder.arrangedSubviews { headerHolder.removeArrangedSubview(v); v.removeFromSuperview() }
        headerHolder.addArrangedSubview(makeHeader())
        for v in extrasHolder.arrangedSubviews { extrasHolder.removeArrangedSubview(v); v.removeFromSuperview() }
        for v in makeExtras() { extrasHolder.addArrangedSubview(v) }
        table.backgroundView = shown.isEmpty ? emptyState() : nil
        table.reloadData()
    }

    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { return shown.count }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = t.dequeueReusableCell(withIdentifier: WordCell.id, for: ip) as! WordCell
        c.set(rowView(for: shown[ip.row], index: ip.row))
        return c
    }
    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) {
        t.deselectRow(at: ip, animated: false)
        didSelect(shown[ip.row], index: ip.row)
    }
    func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }
}
