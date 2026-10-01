import AppKit

/// One word being typed: the only place that decides what is shown and what is committed.
/// The input controller and the tests both drive this, so they can't drift apart.
struct Word {
    private(set) var raw = ""      // keys as typed
    private(set) var literal = false // can no longer be Vietnamese: sticky until word end
    private var resumedLiteral = false // continues plain text ("cros" + "s"): its letters cancel no mark

    var isEmpty: Bool { raw.isEmpty }

    init() {}
    /// Continue a word already in the text ("co" after Delete, + "nf" -> "còn").
    init(resuming text: String, _ m: Method) {
        let k = keys(for: text, method: m)
        if isLiteral(k, method: m) || compose(k, method: m) == text { (raw, literal) = (k, isLiteral(k, method: m)) }
        else { (raw, literal) = (text, true) }
        resumedLiteral = literal
    }

    mutating func type(_ c: Character, _ m: Method) {
        raw.append(c)
        if !literal && isLiteral(raw, method: m) { literal = true }
    }

    mutating func delete(_ m: Method) { (raw, literal) = backspace(raw, literal: literal, method: m) }

    func display(_ m: Method) -> String { decide(literal ? raw : compose(raw, method: m), m, final: false) }
    func commit(_ m: Method) -> String { decide(literal ? raw : finish(raw, method: m), m, final: true) }

    /// UniKey rules, no English guessing:
    /// 1. V is a real Vietnamese word          -> V (tiếng, thí, tét)
    /// 2. a mark was cancelled by a double key  -> keys minus that key (ass -> as, thiss -> this, ww -> w)
    /// 3. while typing: V; at word end: keys as typed (json, book)
    private func decide(_ v: String, _ m: Method, final: Bool) -> String {
        if v != raw && Dictionaries.isVietnamese(v) { return v }
        if !resumedLiteral, let u = withoutUndoKey(raw, method: m) { return u }
        return final ? raw : v
    }
}

/// macOS's built-in spelling dictionaries, cached per string (lookups run on every keystroke).
enum Dictionaries {
    private static var cache: [String: Bool] = [:]

    // The spell checker skips words with digits: check letters first.
    // ponytail: hand-picked teen code the vi dictionary lacks; add words as they show up in the typing log
    private static let teenCode: Set<String> = ["chộ"]
    /// Teen code the dictionary lacks: the list, and a marked vowel + h (òh, ừh).
    static func isTeen(_ w: String) -> Bool {
        let w = w.lowercased()
        return teenCode.contains(w) || (w.count == 2 && w.hasSuffix("h") && !w.first!.isASCII)
    }
    static func isVietnamese(_ w: String) -> Bool {
        w.allSatisfy(\.isLetter) && (isTeen(w) || toneVariants(w).contains { lookup($0, "vi") })
    }

    private static func lookup(_ w: String, _ lang: String) -> Bool {
        let key = lang + ":" + w
        if let v = cache[key] { return v }
        let v = NSSpellChecker.shared.checkSpelling(of: w, startingAt: 0, language: lang, wrap: false,
                                                    inSpellDocumentWithTag: 0, wordCount: nil).location == NSNotFound
        if cache.count > 50_000 { cache.removeAll() } // ponytail: crude bound, fine for one user's typing
        cache[key] = v
        return v
    }
}
