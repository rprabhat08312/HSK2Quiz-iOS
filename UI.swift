import UIKit

// MARK: - theme

enum C {
    static let red = UIColor(hex: 0xC62828)
    static let deepRed = UIColor(hex: 0x8E0000)
    static let gold = UIColor(hex: 0xF9A825)
    static let cream = UIColor(hex: 0xFFF8F0)
    static let ink = UIColor(hex: 0x2B1B17)
    static let muted = UIColor(hex: 0x8A7468)
    static let good = UIColor(hex: 0x2E7D32)
    static let line = UIColor(hex: 0xE6D5C8)
    static let olive = UIColor(hex: 0x9CAF5B)
    static let teal = UIColor(hex: 0x0F6B57)
    static let soft = UIColor(hex: 0xF7F4EE)
    static let track = UIColor(hex: 0xF3E5D8)
    static let blue = UIColor(hex: 0x1565C0)
    static let purple = UIColor(hex: 0x6A1B9A)
    static let pink = UIColor(hex: 0xD81B60)
    static func tone(_ t: Int) -> UIColor {
        switch t {
        case 1: return UIColor(hex: 0xE53935)
        case 2: return UIColor(hex: 0xEF6C00)
        case 3: return UIColor(hex: 0x2E7D32)
        default: return UIColor(hex: 0x1565C0)
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - closures on views / controls

private var tapKey: UInt8 = 0
private var touchKey: UInt8 = 0

final class ClosureSleeve: NSObject {
    let f: () -> Void
    init(_ f: @escaping () -> Void) { self.f = f }
    @objc func invoke() { f() }
}

extension UIView {
    func onTap(_ f: @escaping () -> Void) {
        isUserInteractionEnabled = true
        let s = ClosureSleeve(f)
        addGestureRecognizer(UITapGestureRecognizer(target: s, action: #selector(ClosureSleeve.invoke)))
        objc_setAssociatedObject(self, &tapKey, s, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func pin(_ other: UIView, _ i: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor, constant: i.top),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -i.bottom),
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: i.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -i.right),
        ])
    }

    func sized(w: CGFloat? = nil, h: CGFloat? = nil) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        if let w = w { widthAnchor.constraint(equalToConstant: w).isActive = true }
        if let h = h { heightAnchor.constraint(equalToConstant: h).isActive = true }
        return self
    }
}

extension UIControl {
    func onTouch(_ f: @escaping () -> Void) {
        let s = ClosureSleeve(f)
        addTarget(s, action: #selector(ClosureSleeve.invoke), for: .touchUpInside)
        objc_setAssociatedObject(self, &touchKey, s, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - text

func lbl(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight = .regular, _ color: UIColor = C.ink,
         align: NSTextAlignment = .natural, lines: Int = 0) -> UILabel {
    let l = UILabel()
    l.text = text
    l.font = UIFont.systemFont(ofSize: size, weight: weight)
    l.textColor = color
    l.numberOfLines = lines
    l.textAlignment = align
    return l
}

func pinyinAttr(_ p: String, _ size: CGFloat, _ weight: UIFont.Weight = .semibold,
                align: NSTextAlignment = .natural) -> NSAttributedString {
    let ps = NSMutableParagraphStyle()
    ps.alignment = align
    let out = NSMutableAttributedString()
    for ch in p {
        let k = toneOf(ch)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: C.ink, .paragraphStyle: ps,
        ]
        if k > 0 {
            attrs[.foregroundColor] = C.tone(k)
            attrs[.font] = UIFont.systemFont(ofSize: size, weight: .heavy)
        }
        out.append(NSAttributedString(string: String(ch), attributes: attrs))
    }
    return out
}

func pinyinLabel(_ p: String, _ size: CGFloat, _ weight: UIFont.Weight = .semibold,
                 align: NSTextAlignment = .natural) -> UILabel {
    let l = UILabel()
    l.numberOfLines = 0
    l.attributedText = pinyinAttr(p, size, weight, align: align)
    return l
}

// MARK: - small views

final class PillLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right, height: s.height + insets.top + insets.bottom)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        layer.masksToBounds = true
    }
}

func pill(_ text: String, _ bg: UIColor, _ fg: UIColor = .white) -> UIView {
    let l = PillLabel()
    l.text = text
    l.font = UIFont.systemFont(ofSize: 11, weight: .bold)
    l.textColor = fg
    l.backgroundColor = bg
    l.setContentHuggingPriority(.required, for: .horizontal)
    return l
}

func levelPill(_ w: Word) -> UIView? {
    if !Store.shared.showLevel { return nil }
    if w.extra { return pill(w.level, UIColor(hex: 0xEDE7E1), C.muted) }
    return pill(w.level, C.olive)
}

/// Rounded white box with a border, optional shadow and inner padding. Add children with `add`.
final class Card: UIView {
    let stack = UIStackView()
    init(bg: UIColor = .white, radius: CGFloat = 20, border: UIColor? = nil, borderWidth: CGFloat = 1,
         shadow: Bool = false, padding: UIEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
         spacing: CGFloat = 0) {
        super.init(frame: .zero)
        backgroundColor = bg
        layer.cornerRadius = radius
        if let b = border { layer.borderColor = b.cgColor; layer.borderWidth = borderWidth }
        if shadow {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.10
            layer.shadowRadius = 4
            layer.shadowOffset = CGSize(width: 0, height: 2)
        }
        stack.axis = .vertical
        stack.spacing = spacing
        addSubview(stack)
        stack.pin(self, padding)
    }
    required init?(coder: NSCoder) { fatalError() }
    func add(_ v: UIView) { stack.addArrangedSubview(v) }
}

final class GradientView: UIView {
    override class var layerClass: AnyClass { return CAGradientLayer.self }
    init(_ top: UIColor, _ bottom: UIColor) {
        super.init(frame: .zero)
        (layer as! CAGradientLayer).colors = [top.cgColor, bottom.cgColor]
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class Bar: UIView {
    private let fill = UIView()
    var progress: CGFloat = 0 { didSet { setNeedsLayout() } }
    init(fillColor: UIColor, track: UIColor = C.track, height: CGFloat = 8) {
        super.init(frame: .zero)
        backgroundColor = track
        fill.backgroundColor = fillColor
        addSubview(fill)
        layer.cornerRadius = height / 2
        layer.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * max(0, min(1, progress)), height: bounds.height)
    }
}

final class ChipButton: UIButton {
    private var on = false
    init(_ title: String, on: Bool = false, size: CGFloat = 13, action: @escaping () -> Void) {
        super.init(frame: .zero)
        titleLabel?.font = UIFont.systemFont(ofSize: size, weight: .bold)
        setTitle(title, for: .normal)
        contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        layer.borderWidth = 1
        setOn(on)
        onTouch(action)
        setContentHuggingPriority(.required, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }
    func setOn(_ v: Bool) {
        on = v
        backgroundColor = v ? C.red : C.soft
        layer.borderColor = (v ? C.red : C.line).cgColor
        setTitleColor(v ? .white : C.ink, for: .normal)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

func filledButton(_ title: String, _ bg: UIColor, fg: UIColor = .white, size: CGFloat = 16,
                  height: CGFloat = 54, radius: CGFloat = 16, action: @escaping () -> Void) -> UIButton {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.titleLabel?.font = UIFont.systemFont(ofSize: size, weight: .bold)
    b.setTitleColor(fg, for: .normal)
    b.setTitleColor(fg.withAlphaComponent(0.5), for: .disabled)
    b.backgroundColor = bg
    b.layer.cornerRadius = radius
    b.translatesAutoresizingMaskIntoConstraints = false
    b.heightAnchor.constraint(equalToConstant: height).isActive = true
    b.onTouch(action)
    return b
}

func outlineButton(_ title: String, _ color: UIColor, height: CGFloat = 52, action: @escaping () -> Void) -> UIButton {
    let b = filledButton(title, .clear, fg: color, height: height, radius: 16, action: action)
    b.layer.borderColor = color.cgColor
    b.layer.borderWidth = 1.5
    return b
}

func textButton(_ title: String, _ color: UIColor = C.muted, size: CGFloat = 12, action: @escaping () -> Void) -> UIButton {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.titleLabel?.font = UIFont.systemFont(ofSize: size, weight: .regular)
    b.setTitleColor(color, for: .normal)
    b.onTouch(action)
    return b
}

func speakButton(_ size: CGFloat, action: @escaping () -> Void) -> UIButton {
    let b = UIButton(type: .system)
    b.setTitle("🔊", for: .normal)
    b.titleLabel?.font = UIFont.systemFont(ofSize: size / 2.4)
    b.backgroundColor = C.red
    b.layer.cornerRadius = size / 2
    b.translatesAutoresizingMaskIntoConstraints = false
    b.widthAnchor.constraint(equalToConstant: size).isActive = true
    b.heightAnchor.constraint(equalToConstant: size).isActive = true
    b.onTouch(action)
    return b
}

/// Square-ish box showing a Chinese word (like the Android HanziBox).
func hanziBox(_ text: String, box: CGFloat, font: CGFloat) -> UIView {
    let sz = text.count <= 2 ? font : (font * 0.62).rounded()
    let v = UIView()
    v.backgroundColor = .white
    v.layer.cornerRadius = 14
    v.layer.borderColor = C.line.cgColor
    v.layer.borderWidth = 1
    let l = lbl(text, sz, .medium, UIColor(hex: 0x1B2238), align: .center)
    l.translatesAutoresizingMaskIntoConstraints = false
    v.addSubview(l)
    NSLayoutConstraint.activate([
        l.topAnchor.constraint(equalTo: v.topAnchor, constant: 6),
        l.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -6),
        l.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 10),
        l.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10),
        v.widthAnchor.constraint(greaterThanOrEqualToConstant: box),
        v.heightAnchor.constraint(greaterThanOrEqualToConstant: box),
    ])
    return v
}

// MARK: - stack helpers

func vstack(_ views: [UIView], spacing: CGFloat = 0, align: UIStackView.Alignment = .fill) -> UIStackView {
    let s = UIStackView(arrangedSubviews: views)
    s.axis = .vertical; s.spacing = spacing; s.alignment = align
    return s
}

func hstack(_ views: [UIView], spacing: CGFloat = 0, align: UIStackView.Alignment = .center,
            dist: UIStackView.Distribution = .fill) -> UIStackView {
    let s = UIStackView(arrangedSubviews: views)
    s.axis = .horizontal; s.spacing = spacing; s.alignment = align; s.distribution = dist
    return s
}

func spacer(_ h: CGFloat) -> UIView {
    let v = UIView()
    v.translatesAutoresizingMaskIntoConstraints = false
    v.heightAnchor.constraint(equalToConstant: h).isActive = true
    return v
}

func flexSpacer() -> UIView {
    let v = UIView()
    v.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
    v.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
    return v
}

/// Wraps a view with side/top/bottom padding (so full-width stack children can be inset).
func padded(_ v: UIView, _ i: UIEdgeInsets) -> UIView {
    let c = UIView()
    c.addSubview(v)
    v.pin(c, i)
    return c
}

func hscroll(_ views: [UIView], spacing: CGFloat = 8, height: CGFloat = 40, sidePad: CGFloat = 0) -> UIScrollView {
    let sv = UIScrollView()
    sv.showsHorizontalScrollIndicator = false
    sv.translatesAutoresizingMaskIntoConstraints = false
    let st = hstack(views, spacing: spacing)
    st.translatesAutoresizingMaskIntoConstraints = false
    sv.addSubview(st)
    NSLayoutConstraint.activate([
        st.topAnchor.constraint(equalTo: sv.topAnchor),
        st.bottomAnchor.constraint(equalTo: sv.bottomAnchor),
        st.leadingAnchor.constraint(equalTo: sv.leadingAnchor, constant: sidePad),
        st.trailingAnchor.constraint(equalTo: sv.trailingAnchor, constant: -sidePad),
        st.heightAnchor.constraint(equalTo: sv.heightAnchor),
        sv.heightAnchor.constraint(equalToConstant: height),
    ])
    return sv
}

func styledField(placeholder: String, keyboard: UIKeyboardType = .default) -> UITextField {
    let f = PaddedField()
    f.placeholder = placeholder
    f.keyboardType = keyboard
    f.font = UIFont.systemFont(ofSize: 16)
    f.textColor = C.ink
    f.backgroundColor = .white
    f.layer.cornerRadius = 14
    f.layer.borderWidth = 1
    f.layer.borderColor = C.line.cgColor
    f.autocorrectionType = .no
    f.autocapitalizationType = .none
    f.clearButtonMode = .whileEditing
    f.returnKeyType = .done
    f.translatesAutoresizingMaskIntoConstraints = false
    f.heightAnchor.constraint(equalToConstant: 48).isActive = true
    return f
}

final class PaddedField: UITextField {
    private let pad = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 10)
    override func textRect(forBounds b: CGRect) -> CGRect { return b.inset(by: pad) }
    override func editingRect(forBounds b: CGRect) -> CGRect { return b.inset(by: pad) }
    override func placeholderRect(forBounds b: CGRect) -> CGRect { return b.inset(by: pad) }
}

// MARK: - pages & dialogs

/// A vertical scrolling page: add content to `stack`.
class PageViewController: UIViewController {
    let scroll = UIScrollView()
    let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = C.cream
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .onDrag
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])
    }

    func clearStack() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
    }

    /// Adds a child with the standard side padding.
    func addPadded(_ v: UIView, top: CGFloat = 0, side: CGFloat = 16, bottom: CGFloat = 0) {
        stack.addArrangedSubview(padded(v, UIEdgeInsets(top: top, left: side, bottom: bottom, right: side)))
    }
}

/// A centred dialog over a dimmed background.
class DialogViewController: UIViewController {
    let card = UIView()
    let body = UIStackView()

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        card.backgroundColor = .white
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        let lead = card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        lead.priority = UILayoutPriority(750)
        let trail = card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        trail.priority = UILayoutPriority(750)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 460),
            lead, trail,
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            card.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        body.axis = .vertical
        body.spacing = 10
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.keyboardDismissMode = .onDrag
        card.addSubview(sv)
        sv.pin(card)
        sv.addSubview(body)
        body.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: sv.topAnchor, constant: 20),
            body.bottomAnchor.constraint(equalTo: sv.bottomAnchor, constant: -16),
            body.leadingAnchor.constraint(equalTo: sv.leadingAnchor, constant: 20),
            body.trailingAnchor.constraint(equalTo: sv.trailingAnchor, constant: -20),
            body.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -40),
        ])
        // the card is as tall as its content, up to the available space
        let h = card.heightAnchor.constraint(equalTo: body.heightAnchor, constant: 36)
        h.priority = UILayoutPriority(500)
        h.isActive = true
        buildBody()
    }

    func buildBody() {}
    func close() { dismiss(animated: true, completion: nil) }
}

// MARK: - navigation

enum Router {
    static var nav: UINavigationController!

    static func push(_ vc: UIViewController) { nav.pushViewController(vc, animated: true) }
    static func home() { nav.popToRootViewController(animated: true) }
    /// Replaces the current screen (keeps Home underneath).
    static func replace(_ vc: UIViewController) {
        guard let root = nav.viewControllers.first else { return }
        nav.setViewControllers([root, vc], animated: true)
    }

    private static var topPresenter: UIViewController {
        var t: UIViewController = nav
        while let p = t.presentedViewController { t = p }
        return t
    }

    static func openWord(_ w: Word, vs: Word? = nil) {
        let d = DetailViewController(word: w, vs: vs)
        topPresenter.present(d, animated: true, completion: nil)
    }

    static func alert(_ title: String, _ message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        topPresenter.present(a, animated: true, completion: nil)
    }

    static func comingSoon(_ name: String, stage: Int) {
        alert(name, "This screen is added in Stage \(stage) of the port.")
    }
}
