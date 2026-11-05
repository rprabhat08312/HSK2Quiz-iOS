import Foundation

// MARK: - model

/// The first 300 words are HSK 1; everything after them in words.tsv is new at HSK 2.
let HSK1_WORDS = 300

struct Word: Hashable {
    let id: Int
    let hanzi: String
    let pinyin: String
    let pos: String
    let english: String
    let example: String
    let exampleEn: String
    let extra: Bool      // look-alike character outside the word list
    let looks: String    // HSK 1/2 characters this extra one resembles
    let plain: String
    let meanings: Set<String>

    init(id: Int, hanzi: String, pinyin: String, pos: String, english: String,
         example: String = "", exampleEn: String = "", extra: Bool = false, looks: String = "") {
        self.id = id; self.hanzi = hanzi; self.pinyin = pinyin; self.pos = pos
        self.english = english; self.example = example; self.exampleEn = exampleEn
        self.extra = extra; self.looks = looks
        self.plain = stripTones(pinyin)
        let cleaned = english.lowercased()
            .replacingOccurrences(of: "\\s*\\(.*?\\)", with: "", options: .regularExpression)
        var set = Set<String>()
        for part in cleaned.components(separatedBy: CharacterSet(charactersIn: ";/,")) {
            var t = part.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("to ") { t = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
            if !t.isEmpty { set.insert(t) }
        }
        self.meanings = set
    }

    static func == (a: Word, b: Word) -> Bool { return a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var level: String { return extra ? "Beyond HSK 2" : (id <= HSK1_WORDS ? "HSK 1" : "HSK 2") }

    /// "(particle) suggestion / confirmation tone" style line.
    func meaningLine() -> String {
        return pos.trimmingCharacters(in: .whitespaces).isEmpty ? english : "(\(posLong(pos).lowercased())) \(english)"
    }
}

enum Mode: Int, CaseIterable {
    case listen, hanzi, meaning
    var title: String {
        switch self {
        case .listen: return "Listen & pick"
        case .hanzi: return "Read & pick pinyin"
        case .meaning: return "Meaning to Chinese"
        }
    }
    var sub: String {
        switch self {
        case .listen: return "Hear the word, choose the right Chinese"
        case .hanzi: return "See the characters, choose the pinyin"
        case .meaning: return "Read the English, choose the Chinese"
        }
    }
    var badge: String {
        switch self {
        case .listen: return "听"
        case .hanzi: return "字"
        case .meaning: return "义"
        }
    }
}

struct Question {
    let target: Word
    let options: [Word]
    let mode: Mode
}

/// Words that mean nearly the same thing (synonyms.tsv), with a one-line note.
struct SynGroup {
    let words: [Word]
    let note: String
}

final class Lexicon {
    let words: [Word]
    let extras: [Word]
    let synonyms: [SynGroup]
    let all: [Word]
    init(words: [Word], extras: [Word], synonyms: [SynGroup]) {
        self.words = words; self.extras = extras; self.synonyms = synonyms
        self.all = words + extras
    }
}

enum AppContext {
    static let lex: Lexicon = loadLexicon()
}

func readLines(_ name: String, ext: String = "tsv") -> [String] {
    guard let path = Bundle.main.path(forResource: name, ofType: ext),
          var text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
    if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
    return text.components(separatedBy: .newlines)
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
}

private func at(_ a: [String], _ i: Int) -> String {
    return i < a.count ? a[i].trimmingCharacters(in: .whitespaces) : ""
}

func loadLexicon() -> Lexicon {
    var ex = [String: (String, String)]()
    for l in readLines("examples") {
        let p = l.components(separatedBy: "|")
        if p.count >= 3 { ex[at(p, 0)] = (at(p, 1), at(p, 2)) }
    }
    var words = [Word]()
    for (i, l) in readLines("words").enumerated() {
        let p = l.components(separatedBy: "|")
        let h = at(p, 0)
        let e = ex[h]
        words.append(Word(id: i + 1, hanzi: h, pinyin: at(p, 1), pos: at(p, 2), english: at(p, 3),
                          example: e?.0 ?? "", exampleEn: e?.1 ?? ""))
    }
    var extras = [Word]()
    for (i, l) in readLines("confusables").enumerated() {
        let p = l.components(separatedBy: "|")
        if p.count < 4 { continue }
        extras.append(Word(id: 1000 + i, hanzi: at(p, 0), pinyin: at(p, 1), pos: "", english: at(p, 2),
                           extra: true, looks: at(p, 3).replacingOccurrences(of: ",", with: "")))
    }
    var byHanzi = [String: Word]()
    for w in words { byHanzi[w.hanzi] = w }
    var syn = [SynGroup]()
    for l in readLines("synonyms") {
        let p = l.components(separatedBy: "|")
        var ws = [Word]()
        for h in p[0].components(separatedBy: ",") {
            if let w = byHanzi[h.trimmingCharacters(in: .whitespaces)], !ws.contains(w) { ws.append(w) }
        }
        if ws.count >= 2 { syn.append(SynGroup(words: ws, note: at(p, 1))) }
    }
    return Lexicon(words: words, extras: extras, synonyms: syn)
}

/// Words with a similar meaning to `w` (from every synonym group it belongs to).
func synonymsOf(_ w: Word, _ groups: [SynGroup]) -> [Word] {
    var out = [Word]()
    for g in groups where g.words.contains(where: { $0.id == w.id }) {
        for x in g.words where x.id != w.id && !out.contains(x) { out.append(x) }
    }
    return out
}

func synonymNote(_ a: Word, _ b: Word, _ groups: [SynGroup]) -> String {
    for g in groups where g.words.contains(where: { $0.id == a.id }) && g.words.contains(where: { $0.id == b.id }) {
        return g.note
    }
    return ""
}

// MARK: - pinyin helpers

func stripTones(_ s: String) -> String {
    let d = s.decomposedStringWithCanonicalMapping
    var out = ""
    for u in d.unicodeScalars {
        if u.properties.generalCategory == .nonspacingMark { continue }
        let c = Character(u)
        for l in String(c).lowercased() where (l >= "a" && l <= "z") || l == "/" { out.append(l) }
    }
    return out
}

func toneOf(_ c: Character) -> Int {
    switch c {
    case "ā", "ē", "ī", "ō", "ū", "ǖ", "Ā", "Ē", "Ī", "Ō", "Ū": return 1
    case "á", "é", "í", "ó", "ú", "ǘ", "Á", "É", "Í", "Ó", "Ú": return 2
    case "ǎ", "ě", "ǐ", "ǒ", "ǔ", "ǚ", "Ǎ", "Ě", "Ǐ", "Ǒ", "Ǔ": return 3
    case "à", "è", "ì", "ò", "ù", "ǜ", "À", "È", "Ì", "Ò", "Ù": return 4
    default: return 0
    }
}

private let posNames: [String: String] = [
    "n.": "noun", "v.": "verb", "adj.": "adjective", "adv.": "adverb",
    "pron.": "pronoun", "num.": "numeral", "mw.": "measure word",
    "prep.": "preposition", "conj.": "conjunction", "part.": "particle",
    "interj.": "interjection", "phr.": "phrase", "suffix": "suffix",
    "prefix": "prefix", "num.-mw.": "numeral-measure word", "v. phr.": "verb phrase",
]

func posLong(_ p: String) -> String {
    return p.components(separatedBy: "/").map { part -> String in
        let t = part.trimmingCharacters(in: .whitespaces)
        return posNames[t] ?? t
    }.joined(separator: " / ")
}

// MARK: - look-alike data

private let shapeGroups: [String] = [
    "买卖", "他她它", "在再", "哪那", "吗妈吧", "们问间", "千午牛", "大太天", "人八", "日月白",
    "明朋", "说谁", "做坐", "玩元", "找我", "候后", "二三", "十七", "九几", "少小", "雨雪",
    "字学", "休体", "块快", "有月", "回四",
    "国回四", "午年", "九几机", "钟钱", "点店", "哥歌", "作昨", "外多", "高亮", "能脑",
    "么公", "来米", "同司", "白百", "第弟", "要西", "你您", "没汉", "起超",
    "往住", "忘忙", "洗先", "姓性生", "周同", "左右在", "右有", "近进", "让认", "词同司",
    "完元玩院", "远元", "请晴情", "们问间门", "跑包", "着看", "跟很根", "画面", "药约",
    "题提", "球求", "己已", "鸟乌", "肉内", "站占", "裤库", "酒洒", "坏怀", "别另", "最取", "阴阳",
]

private let radicalGroups: [String] = [
    "说谁请认识谢课读话", "饭饺", "吃喝唱吗吧呢哪听喂叫问同", "妈姐妹好她女", "他们你件什住便做休",
    "椅桌杯本", "找打", "想怎忙", "这边还", "时晚昨明早星", "雨雪", "钱",
    "见现视觉", "汉没漂", "猫狗", "租和", "热点", "家客宜", "床店", "钱钟", "起超",
    "校样机条杯果来桌椅本", "这边还道都", "打找手", "玩现", "作做休件什住便他你", "奶妈姐妹她好女",
    "哥歌欢", "新亲", "睡眼",
    "位住件什但他们你", "跑路跳踢跟", "药茶苹菜花", "鸟鸡", "笔笑第等", "洗游泳酒汉没漂",
    "记词让告诉说请认识谢课读话谁", "姓妻奶妈姐妹好她女", "球玩现", "楼校样机", "红绿",
    "错钱钟", "慢忙快怎想", "阴院", "睡眼睛",
]

private func groupMap(_ g: [String]) -> [Character: Set<Int>] {
    var m = [Character: Set<Int>]()
    for (i, s) in g.enumerated() {
        for c in s { m[c, default: []].insert(i) }
    }
    return m
}

private let shapeMap = groupMap(shapeGroups)
private let radMap = groupMap(radicalGroups)

private func share(_ m: [Character: Set<Int>], _ a: Character, _ b: Character) -> Bool {
    guard let x = m[a], let y = m[b] else { return false }
    return !x.isDisjoint(with: y)
}

private func lev(_ sa: String, _ sb: String) -> Int {
    let a = Array(sa), b = Array(sb)
    var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in 0...a.count { d[i][0] = i }
    for j in 0...b.count { d[0][j] = j }
    if a.isEmpty || b.isEmpty { return d[a.count][b.count] }
    for i in 1...a.count {
        for j in 1...b.count {
            let c = a[i - 1] == b[j - 1] ? 0 : 1
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + c)
        }
    }
    return d[a.count][b.count]
}

private func extraLook(_ t: Word, _ c: Word) -> Bool {
    if c.extra && c.looks.contains(where: { t.hanzi.contains($0) }) { return true }
    if t.extra && t.looks.contains(where: { c.hanzi.contains($0) }) { return true }
    return false
}

private func lookalike(_ t: Word, _ c: Word) -> Bool {
    if extraLook(t, c) { return true }
    for a in t.hanzi { for b in c.hanzi where a != b && share(shapeMap, a, b) { return true } }
    return false
}

private func anyRadical(_ t: Word, _ c: Word) -> Bool {
    for a in t.hanzi { for b in c.hanzi where share(radMap, a, b) { return true } }
    return false
}

private func anyRadicalDifferent(_ t: Word, _ c: Word) -> Bool {
    for a in t.hanzi { for b in c.hanzi where a != b && share(radMap, a, b) { return true } }
    return false
}

// MARK: - confusability

private func charScore(_ t: Word, _ c: Word) -> Double {
    var s = 0.0
    for a in t.hanzi {
        for b in c.hanzi {
            if a == b { s += 3.0 }
            else if share(shapeMap, a, b) { s += 4.0 }
            else if share(radMap, a, b) { s += 1.5 }
        }
    }
    if extraLook(t, c) { s += 6.0 }
    return s
}

func similarity(_ t: Word, _ c: Word) -> Double {
    var s = charScore(t, c)
    if t.hanzi.count == c.hanzi.count { s += 1.0 }
    if t.plain == c.plain { s += 4.0 } else {
        let d = lev(t.plain, c.plain)
        if d <= 1 { s += 2.5 } else if d == 2 { s += 1.0 }
    }
    if !t.pos.trimmingCharacters(in: .whitespaces).isEmpty,
       t.pos.components(separatedBy: "/")[0].trimmingCharacters(in: .whitespaces)
        == c.pos.components(separatedBy: "/")[0].trimmingCharacters(in: .whitespaces) { s += 0.5 }
    return s
}

func confusionTag(_ t: Word, _ c: Word) -> String {
    if lookalike(t, c) { return "Look-alike" }
    if t.plain == c.plain { return "Same letters" }
    if !Set(t.hanzi).isDisjoint(with: Set(c.hanzi)) { return "Shared character" }
    if lev(t.plain, c.plain) <= 2 { return "Similar sound" }
    if anyRadical(t, c) { return "Same radical" }
    return "Confusable"
}

func confusionNote(_ t: Word, _ c: Word) -> String {
    var r = [String]()
    let shared = Set(t.hanzi).intersection(Set(c.hanzi))
    if !shared.isEmpty { r.append("shares the character " + shared.map { String($0) }.joined(separator: "、")) }
    if lookalike(t, c) { r.append("has a look-alike character") }
    else if anyRadicalDifferent(t, c) { r.append("uses a similar radical") }
    if t.plain == c.plain { r.append("same letters, different tone") }
    else if lev(t.plain, c.plain) <= 2 { r.append("sounds similar") }
    if r.isEmpty { return "A different word of similar length." }
    let s = r.joined(separator: "; ")
    return s.prefix(1).uppercased() + s.dropFirst() + "."
}

/// Words/characters most easily confused with `w` (look-alike, similar sound, shared character).
func confusablesOf(_ w: Word, _ all: [Word]) -> [Word] {
    let scored = all.filter { $0.id != w.id && $0.hanzi != w.hanzi }
        .map { (x: Word) -> (Word, Double) in (x, similarity(w, x)) }
        .filter { $0.1 >= 4.0 }
        .sorted { $0.1 > $1.1 }
    return scored.prefix(8).map { $0.0 }
}

/// Characters/words that LOOK like `w` (Watch & learn screen), best match first.
func lookAlikesOf(_ w: Word, _ all: [Word]) -> [Word] {
    let scored = all.filter { $0.id != w.id && $0.hanzi != w.hanzi }
        .map { (x: Word) -> (Word, Double) in (x, charScore(w, x)) }
        .filter { $0.1 >= 1.5 }
        .sorted { $0.1 > $1.1 }
    return scored.prefix(8).map { $0.0 }
}

/// Words that sound almost the same (same letters/different tone first, then one letter off).
func soundAlikesOf(_ w: Word, _ all: [Word]) -> [Word] {
    let pool = all.filter { !$0.extra && $0.id != w.id && $0.hanzi != w.hanzi }
    let close = pool.filter { lev(w.plain, $0.plain) <= 1 }.sorted { lev(w.plain, $0.plain) < lev(w.plain, $1.plain) }
    let list = close.count >= 3 ? close : close + pool.filter { lev(w.plain, $0.plain) == 2 && !close.contains($0) }
    return Array(list.prefix(6))
}

private func qkey(_ mode: Mode, _ w: Word) -> String { return mode == .hanzi ? w.pinyin : w.hanzi }

private func allowed(_ mode: Mode, _ t: Word, _ c: Word) -> Bool {
    switch mode {
    case .listen, .hanzi: return c.pinyin.lowercased() != t.pinyin.lowercased()
    case .meaning: return c.meanings.isDisjoint(with: t.meanings)
    }
}

/// `all` = pool the wrong options come from. `fallback` only tops up when `all` is too small.
func makeQuestion(_ all: [Word], _ t: Word, _ mode: Mode, fallback: [Word] = []) -> Question {
    let ranked = all.filter { $0.id != t.id && allowed(mode, t, $0) }
        .map { (x: Word) -> (Word, Double) in (x, similarity(t, x) + Double.random(in: 0..<1) * 1.5) }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    var pool = Array(ranked.prefix(12))
    var picked = [Word]()
    func ok(_ w: Word) -> Bool {
        return !picked.contains(where: { qkey(mode, $0) == qkey(mode, w) }) && qkey(mode, w) != qkey(mode, t)
    }
    while picked.count < 3 && !pool.isEmpty {
        let w = pool.remove(at: Int.random(in: 0..<min(pool.count, 5)))
        if ok(w) { picked.append(w) }
    }
    if picked.count < 3 {
        for w in ranked.dropFirst(12).shuffled() {
            if picked.count >= 3 { break }
            if ok(w) { picked.append(w) }
        }
    }
    if picked.count < 3 && !fallback.isEmpty {
        for w in fallback.filter({ $0.id != t.id && allowed(mode, t, $0) }).shuffled() {
            if picked.count >= 3 { break }
            if ok(w) { picked.append(w) }
        }
    }
    return Question(target: t, options: (picked + [t]).shuffled(), mode: mode)
}

func relatedWords(_ w: Word, _ words: [Word]) -> [Word] {
    let rel = words.filter { o in o.id != w.id && o.hanzi.contains(where: { w.hanzi.contains($0) }) }
        .sorted { $0.hanzi.count < $1.hanzi.count }
    return Array(rel.prefix(8))
}

// MARK: - progress

let SCOPE_ALL = 0
let SCOPE_LEARNED = 1
let SCOPE_PICKED = 2
let MIN_LEARNED = 4

final class Store {
    static let shared = Store()
    static let didChange = Notification.Name("HSK2StoreDidChange")

    private let sp = UserDefaults.standard
    var streak = 0
    private var learned: Set<Int>
    private var picked: Set<Int>
    private var bookmarked: Set<Int>
    private let totalWords: Int

    private func ints(_ k: String) -> Set<Int> {
        return Set((sp.array(forKey: k) as? [Int]) ?? [])
    }
    private func int(_ k: String, _ def: Int) -> Int {
        return sp.object(forKey: k) != nil ? sp.integer(forKey: k) : def
    }
    private func notify() {
        NotificationCenter.default.post(name: Store.didChange, object: nil)
    }

    private init() {
        totalWords = readLines("words").count
        learned = Set((sp.array(forKey: "lw") as? [Int]) ?? [])
        bookmarked = Set((sp.array(forKey: "bm") as? [Int]) ?? [])
        if sp.object(forKey: "sw") != nil {
            picked = Set((sp.array(forKey: "sw") as? [Int]) ?? [])
        } else if totalWords > HSK1_WORDS {
            picked = Set((HSK1_WORDS + 1)...totalWords)   // first run: the new HSK 2 words
        } else {
            picked = []
        }
        // First run: practise only the new HSK 2 words.
        if sp.object(forKey: "sw") == nil && sp.object(forKey: "qs") == nil && !picked.isEmpty {
            sp.set(Array(picked), forKey: "sw")
            sp.set(SCOPE_PICKED, forKey: "qs")
        }
    }

    // learned
    var learnedCount: Int { return learned.count }
    func isLearned(_ id: Int) -> Bool { return learned.contains(id) }
    func learnedWords(_ words: [Word]) -> [Word] { return words.filter { learned.contains($0.id) } }
    private func saveLearned() { sp.set(Array(learned), forKey: "lw"); notify() }
    func setLearned(_ id: Int, _ on: Bool) { if on { learned.insert(id) } else { learned.remove(id) }; saveLearned() }
    func markLearned(_ ids: [Int]) { learned.formUnion(ids); saveLearned() }
    func clearLearned() { learned = []; saveLearned() }

    // picked
    var pickedCount: Int { return picked.count }
    func isPicked(_ id: Int) -> Bool { return picked.contains(id) }
    func pickedWords(_ words: [Word]) -> [Word] { return words.filter { picked.contains($0.id) } }
    private func savePicked() { sp.set(Array(picked), forKey: "sw"); notify() }
    func setPicked(_ id: Int, _ on: Bool) { if on { picked.insert(id) } else { picked.remove(id) }; savePicked() }
    func addPicked(_ ids: [Int]) { picked.formUnion(ids); savePicked() }
    func removePicked(_ ids: [Int]) { picked.subtract(ids); savePicked() }
    func replacePicked(_ ids: [Int]) { picked = Set(ids); savePicked() }
    func clearPicked() { picked = []; savePicked() }

    // bookmarks
    var bookmarkedCount: Int { return bookmarked.count }
    func isBookmarked(_ id: Int) -> Bool { return bookmarked.contains(id) }
    func bookmarkedWords(_ words: [Word]) -> [Word] { return words.filter { bookmarked.contains($0.id) } }
    private func saveBookmarked() { sp.set(Array(bookmarked), forKey: "bm"); notify() }
    func toggleBookmark(_ id: Int) {
        if bookmarked.contains(id) { bookmarked.remove(id) } else { bookmarked.insert(id) }
        saveBookmarked()
    }
    func clearBookmarked() { bookmarked = []; saveBookmarked() }

    var showLevel: Bool {
        get { return sp.object(forKey: "show_level") != nil ? sp.bool(forKey: "show_level") : true }
        set { sp.set(newValue, forKey: "show_level"); notify() }
    }

    var scope: Int {
        get {
            if sp.object(forKey: "qs") != nil { return sp.integer(forKey: "qs") }
            return sp.bool(forKey: "lo") ? SCOPE_LEARNED : SCOPE_ALL
        }
        set { sp.set(newValue, forKey: "qs"); notify() }
    }

    func scopeWords(_ words: [Word]) -> [Word] {
        switch scope {
        case SCOPE_LEARNED: return learnedWords(words)
        case SCOPE_PICKED: return pickedWords(words)
        default: return words
        }
    }

    func right(_ id: Int) -> Int { return sp.integer(forKey: "c\(id)") }
    func wrong(_ id: Int) -> Int { return sp.integer(forKey: "w\(id)") }
    func mastered(_ id: Int) -> Bool { return right(id) >= 3 && right(id) >= 2 * wrong(id) }
    func seen(_ id: Int) -> Bool { return right(id) + wrong(id) > 0 }
    var totalRight: Int { return sp.integer(forKey: "tr") }
    var totalAnswered: Int { return sp.integer(forKey: "ta") }
    var bestStreak: Int { return sp.integer(forKey: "bs") }
    var quizCount: Int { return int("qn", 10) }
    var learnIndex: Int {
        get { return int("li", totalWords > HSK1_WORDS ? HSK1_WORDS : 0) }
        set { sp.set(newValue, forKey: "li") }
    }

    func setCount(_ n: Int) {
        sp.set(max(1, min(1000, n)), forKey: "qn")
        notify()
    }

    func masteredCount(_ words: [Word]) -> Int { return words.filter { mastered($0.id) }.count }

    func record(_ id: Int, _ ok: Bool) {
        if ok {
            sp.set(right(id) + 1, forKey: "c\(id)")
            sp.set(totalRight + 1, forKey: "tr")
            streak += 1
            if streak > bestStreak { sp.set(streak, forKey: "bs") }
        } else {
            sp.set(wrong(id) + 1, forKey: "w\(id)")
            streak = 0
        }
        sp.set(totalAnswered + 1, forKey: "ta")
        notify()
    }

    /// Clears scores/streaks; keeps quiz count, learn position, scope and the three word lists.
    func reset() {
        for k in sp.dictionaryRepresentation().keys {
            if k == "tr" || k == "ta" || k == "bs" || k == "show_level" || k == "lo" { sp.removeObject(forKey: k) }
            else if k.range(of: "^[cw][0-9]+$", options: .regularExpression) != nil { sp.removeObject(forKey: k) }
        }
        streak = 0
        notify()
    }
}

func pickRound(_ words: [Word], _ store: Store, _ n: Int) -> [Word] {
    var pool = words
    var out = [Word]()
    func weight(_ w: Word) -> Double {
        if !store.seen(w.id) { return 3.0 }
        if store.mastered(w.id) { return 0.4 }
        return 1.0 + Double(store.wrong(w.id)) * 1.5
    }
    while out.count < n && !pool.isEmpty {
        let ws = pool.map { weight($0) }
        var r = Double.random(in: 0..<1) * ws.reduce(0, +)
        var idx = ws.count - 1
        for i in 0..<ws.count {
            r -= ws[i]
            if r <= 0 { idx = i; break }
        }
        out.append(pool.remove(at: idx))
    }
    return out
}
