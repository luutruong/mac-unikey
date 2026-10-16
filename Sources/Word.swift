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
    /// 1. at word end: V is a valid syllable (xò, đệch, tét); while typing: V is a dictionary word
    /// 2. a mark was cancelled by a double key  -> keys minus that key (ass -> as, thiss -> this, ww -> w)
    /// 3. while typing: V; at word end: keys as typed (json, book)
    private func decide(_ v: String, _ m: Method, final: Bool) -> String {
        if let a = abbreviation(m) { return a }
        // At word end v is finish(raw): already raw unless the keys form a valid syllable.
        if v != raw && final { return v }
        // The dictionary only decides between V and an undone mark: skip the lookup on most keys (Telegram waits on us).
        guard !resumedLiteral, let u = withoutUndoKey(raw, method: m) else { return final ? raw : v }
        return v != raw && !final && Dictionaries.isVietnamese(v) ? v : u
    }

    /// Teen-code abbreviations: đ alone or + consonants (đ, đc, đt, đk). Not a syllable, but UniKey keeps the đ.
    private func abbreviation(_ m: Method) -> String? {
        let head = compose(String(raw.prefix(2)), method: m), tail = raw.dropFirst(2)
        guard head.lowercased() == "đ",
              tail.allSatisfy({ "bcfghjklmnpqrstvxz".contains($0.lowercased()) }) else { return nil }
        return head + tail
    }
}

/// Auto-capitalize a sentence's first letter: after . ! ? and a space ("đi. Về").
/// Not after Return: new code lines (GoLand) must stay lowercase.
struct SentenceStart {
    private var afterStop = false
    private(set) var armed = false
    /// A key that is not part of a word (space, punctuation…).
    mutating func other(_ c: Character) {
        if ".!?".contains(c) { afterStop = true; armed = false }
        else if c == " " && (afterStop || armed) { armed = true } // ". " and ".  " both arm
        else { clear() }
    }
    mutating func clear() { afterStop = false; armed = false } // letter typed, Delete, click, shortcut
    /// Text right before the cursor starts a sentence: start of the document, or . ! ? then space(s). Not after Return.
    /// Preferred over the key history when the app tells us its text (survives Delete and clicks).
    static func starts(after before: String, at location: Int) -> Bool {
        if location == 0 { return true }
        let t = before.reversed().drop { $0 == " " }
        return t.count < before.count && t.first.map { ".!?".contains($0) } == true
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
