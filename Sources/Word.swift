import AppKit

/// One word being typed: the only place that decides what is shown and what is committed.
/// The input controller and the tests both drive this, so they can't drift apart.
struct Word {
    private(set) var raw = ""      // keys as typed
    private(set) var literal = false // can no longer be Vietnamese: sticky until word end

    var isEmpty: Bool { raw.isEmpty }

    init() {}
    /// Continue a word already in the text ("co" after Delete, + "nf" -> "còn").
    init(resuming text: String, _ m: Method) {
        let k = keys(for: text, method: m)
        if isLiteral(k, method: m) || compose(k, method: m) == text { (raw, literal) = (k, isLiteral(k, method: m)) }
        else { (raw, literal) = (text, true) }
    }

    mutating func type(_ c: Character, _ m: Method) {
        raw.append(c)
        if !literal && isLiteral(raw, method: m) { literal = true }
    }

    mutating func delete(_ m: Method) { (raw, literal) = backspace(raw, literal: literal, method: m) }

    func display(_ m: Method) -> String { decide(literal ? raw : compose(raw, method: m), m, final: false) }
    func commit(_ m: Method) -> String { decide(literal ? raw : finish(raw, method: m), m, final: true) }

    /// V = Vietnamese form, R = keys as typed, U = keys minus a cancelling double key.
    /// 1. V is a real Vietnamese word (either tone style) -> V (tiếng, ít, cả: ties go to Vietnamese)
    /// 2. R is an English word (3+ letters)                -> R (seems, message, coffee)
    ///    …unless U is English too and only U is in the plain word list: the spell checker also
    ///    accepts stretched forms, so "mixx" -> "mix", "errr" -> "err", but "pass" stays
    /// 3. U is an English word                             -> U (itss -> its, generrated -> generated)
    ///    — while typing only right after the cancelling key, otherwise the text would flip as
    ///    each prefix happens (not) to be English ("mess" -> "mesa" -> "messag")
    /// 4. while typing: V (half-typed Vietnamese like "tiê" isn't a word yet)
    ///    at word end: not a real Vietnamese word, so U if a mark was cancelled, else R
    ///    ("bara" not "bẩ", "tesst" -> "test", "json")
    private func decide(_ v: String, _ m: Method, final: Bool) -> String {
        if v != raw && Dictionaries.isVietnamese(v) { return v }
        let u = withoutUndoKey(raw, method: m)
        let uEnglish = u.map { $0.count >= 2 && Dictionaries.isEnglish($0) } ?? false
        if raw.count >= 3 && Dictionaries.isEnglish(raw) {
            // While typing, keep the Vietnamese form as long as it can still become a real word:
            // "naw" is English but "nă" is on its way to "năm" — flashing "naw" makes text shake.
            if !final, v != raw, Dictionaries.canBecomeVietnamese(v) { return v }
            if let u, uEnglish, !Dictionaries.inWordList(raw), Dictionaries.inWordList(u) { return u }
            return raw
        }
        if let u, uEnglish, final || undoKeyIndex(raw, method: m) == raw.count - 1 { return u }
        return final ? (u ?? raw) : v
    }
}

/// macOS's built-in spelling dictionaries, cached per string (lookups run on every keystroke).
enum Dictionaries {
    private static var cache: [String: Bool] = [:]

    // The spell checkers skip words with digits, and "en" skips non-ASCII letters: check letters first.
    static func isVietnamese(_ w: String) -> Bool {
        w.allSatisfy(\.isLetter) && toneVariants(w).contains { lookup($0, "vi") }
    }
    static func isEnglish(_ w: String) -> Bool {
        w.allSatisfy { $0.isASCII && $0.isLetter } && lookup(w, "en")
    }

    /// Every real Vietnamese syllable (from the vi dictionary, generated at build time into the app's
    /// Resources/vietnamese.txt; `MacUnikey --syllables` prints it), plus every beginning of one,
    /// with and without its tone. Answers "can this half-typed word still become Vietnamese?".
    private static let vietnamesePrefixes: Set<String> = {
        let file = Bundle.main.url(forResource: "vietnamese", withExtension: "txt")
            ?? URL(fileURLWithPath: "build/vietnamese.txt")
        let list = (try? String(contentsOf: file, encoding: .utf8)).map { $0.split(separator: "\n").map(String.init) }
            ?? realSyllables()
        var out = Set<String>()
        for s in list {
            for form in [s, withoutTone(s)] {
                for n in 1...form.count { out.insert(String(form.prefix(n))) }
            }
        }
        return out
    }()
    static func canBecomeVietnamese(_ w: String) -> Bool {
        let w = w.lowercased()
        return vietnamesePrefixes.contains(w) || vietnamesePrefixes.contains(withoutTone(w))
    }
    /// Slow (~10 s): checks every candidate syllable against the vi dictionary.
    static func realSyllables() -> [String] { candidateSyllables().filter { isVietnamese($0) } }

    /// /usr/share/dict/words: old and without inflections ("seems"), so only a tie-breaker.
    private static let wordList: Set<Substring> = {
        let text = (try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8)) ?? ""
        return Set(text.split(separator: "\n"))
    }()
    static func inWordList(_ w: String) -> Bool { wordList.contains(Substring(w.lowercased())) }

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
