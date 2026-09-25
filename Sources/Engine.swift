// Vietnamese composition engine: raw keystrokes of one word -> Unicode (precomposed).
// Stateless: the controller keeps the raw buffer and re-composes on every key.

enum Method: String { case telex, vni }

private enum Mark { case none, hat, breve, horn, stroke }

private struct Ch {
    var base: Character   // lowercase ASCII letter
    var mark: Mark = .none
    var upper: Bool
    var fromW = false     // Telex lone "w" -> "ư"; "ww" turns it back into "w"
}

private enum Action { case tone(Int), hat(Set<Character>), horn, breve, stroke, w }

private let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]

private func action(_ k: Character, _ m: Method) -> Action? {
    switch m {
    case .telex:
        switch k {
        case "s": return .tone(1)
        case "f": return .tone(2)
        case "r": return .tone(3)
        case "x": return .tone(4)
        case "j": return .tone(5)
        case "z": return .tone(0)
        case "a", "e", "o": return .hat([k])
        case "w": return .w
        case "d": return .stroke
        default: return nil
        }
    case .vni:
        switch k {
        case "1"..."5": return .tone(Int(String(k))!)
        case "0": return .tone(0)
        case "6": return .hat(["a", "e", "o"])
        case "7": return .horn
        case "8": return .breve
        case "9": return .stroke
        default: return nil
        }
    }
}

// Indices of the syllable's vowels; the "u" of "qu" and the "i" of "gi" count as consonant.
private func vowelIndices(_ w: [Ch]) -> [Int] {
    var r = w.indices.filter { vowels.contains(w[$0].base) }
    if r.count > 1, r[0] == 1 {
        let (c0, c1) = (w[0].base, w[1].base)
        if (c0 == "q" && c1 == "u") || (c0 == "g" && c1 == "i") { r.removeFirst() }
    }
    return r
}

/// Live display while typing: as soon as the word can no longer become Vietnamese, show the
/// keys exactly as typed ("bôk" -> "book", "gểna" -> "genera"), so nothing needs undoing.
func compose(_ raw: String, method: Method) -> String {
    let p = parse(raw, method)
    return isSyllable(p.w, tone: p.tone, prefix: true) ? render(p) : raw
}

/// Word end (Space…): anything that isn't a complete Vietnamese syllable stays as typed.
func finish(_ raw: String, method: Method) -> String {
    let p = parse(raw, method)
    return isSyllable(p.w, tone: p.tone) ? render(p) : raw
}

/// The typed keys minus the key that cancelled a mark by double-typing — what the user meant
/// when they undid an accent on an English word ("itss" -> "its", "generrated" -> "generated").
/// nil when no mark was cancelled.
/// Index in `raw` of the key that cancelled a mark by double-typing, if any.
func undoKeyIndex(_ raw: String, method: Method) -> Int? { parse(raw, method).undoAt }

func withoutUndoKey(_ raw: String, method: Method) -> String? {
    guard let i = parse(raw, method).undoAt else { return nil }
    var keys = Array(raw)
    keys.remove(at: i)
    return String(keys)
}

/// The word can no longer become Vietnamese: it is shown and committed exactly as typed.
func isLiteral(_ raw: String, method: Method) -> Bool {
    let p = parse(raw, method)
    return !isSyllable(p.w, tone: p.tone, prefix: true)
}

/// Delete removes the last *visible* character, like UniKey ("việt" -> "việ", not "viêt").
/// A literal (non-Vietnamese) word just loses its last key and stays literal ("depe" not "dêp").
func backspace(_ raw: String, literal: Bool, method: Method) -> (raw: String, literal: Bool) {
    if literal {
        // Deleting the key that broke the word makes it Vietnamese again ("TYooi" -> "T" + "ooi" = "Tôi"),
        // unless composing would change what is on screen ("mess" stays "mess", not "mes").
        let r = String(raw.dropLast())
        return (r, !r.isEmpty && (isLiteral(r, method: method) || compose(r, method: method) != r))
    }
    let shown = String(compose(raw, method: method).dropLast())
    if shown.isEmpty { return ("", false) }
    let k = keys(for: shown, method: method)
    // Re-typing may place the tone elsewhere ("hoà" -> "hòa"); then keep the text as is.
    return compose(k, method: method) == shown ? (k, false) : (shown, true)
}

/// Keystrokes that compose back into `text` (tone key last): "việ" -> "vieej" / "vie65".
func keys(for text: String, method: Method) -> String {
    var out = "", tone = 0
    for ch in text {
        guard let (base, mark, t) = reverseTable[Character(ch.lowercased())] else { out.append(ch); continue }
        if t != 0 { tone = t }
        out.append(ch.isUppercase ? Character(base.uppercased()) : base)
        switch (mark, method) {
        case ("^", .telex): out.append(base)
        case ("(", .telex), ("+", .telex): out.append("w")
        case ("d", .telex): out.append("d")
        case ("^", .vni): out.append("6")
        case ("+", .vni): out.append("7")
        case ("(", .vni): out.append("8")
        case ("d", .vni): out.append("9")
        default: break
        }
    }
    if tone != 0 { out.append(method == .telex ? Array("sfrxj")[tone - 1] : Character(String(tone))) }
    return out
}

private func parse(_ raw: String, _ method: Method) -> (w: [Ch], tone: Int, undoAt: Int?) {
    var w: [Ch] = []
    var tone = 0 // 1 sắc, 2 huyền, 3 hỏi, 4 ngã, 5 nặng
    var literal = false // after a double-key undo the rest of the word is typed as-is (UniKey)
    var prev: (key: Character, applied: Bool)? // undo only when the key repeats right away ("ss")
    var undoAt: Int?  // index in raw of the key that cancelled a mark
    var idx = -1

    for key in raw {
        idx += 1
        let k = Character(key.lowercased())
        let lit = Ch(base: k, upper: key.isUppercase)
        let canUndo = prev?.key == k && prev?.applied == true
        var applied = false
        defer { prev = (k, applied) }
        guard !literal, let act = action(k, method) else { w.append(lit); continue }
        let vi = vowelIndices(w)
        // A transform that breaks the syllable while the plain letter wouldn't is typed as the plain
        // letter instead (UniKey): "khoeo" keeps its o, not "khôe".
        let before = (w, tone)
        defer {
            if applied, !isSyllable(w, tone: tone, prefix: true),
               isSyllable(before.0 + [lit], tone: before.1, prefix: true) {
                (w, tone) = before; w.append(lit); applied = false
            }
        }

        // Set `mark` on index i. Repeating the key right away undoes it and emits the key;
        // a later repeat ("banana") is just a letter.
        func toggle(_ i: Int, _ mark: Mark) {
            if w[i].mark != mark { w[i].mark = mark; applied = true; return }
            if canUndo { w[i].mark = .none; literal = true; undoAt = undoAt ?? idx }
            w.append(lit)
        }
        // Horn on "uo" pair -> "ươ"; returns false if there is no such pair.
        func hornPair() -> Bool {
            guard let p = vi.firstIndex(where: { w[$0].base == "u" }), p + 1 < vi.count,
                  w[vi[p + 1]].base == "o", vi[p + 1] == vi[p] + 1 else { return false }
            let (u, o) = (vi[p], vi[p + 1])
            if w[u].mark == .horn && w[o].mark == .horn {
                if canUndo { w[u].mark = .none; w[o].mark = .none; literal = true; undoAt = undoAt ?? idx }
                w.append(lit)
            } else { w[u].mark = .horn; w[o].mark = .horn; applied = true }
            return true
        }

        switch act {
        case .tone(let t):
            if vi.isEmpty || (t == 0 && tone == 0) { w.append(lit) }
            else if t == tone && t != 0 {
                if canUndo { tone = 0; literal = true; undoAt = undoAt ?? idx }
                w.append(lit)
            } else { tone = t; applied = true }
        case .hat(let targets):
            if let i = vi.last(where: { targets.contains(w[$0].base) }) { toggle(i, .hat) } else { w.append(lit) }
        case .breve:
            if let i = vi.last(where: { w[$0].base == "a" }) { toggle(i, .breve) } else { w.append(lit) }
        case .horn:
            if hornPair() { break }
            if let i = vi.last(where: { "ou".contains(w[$0].base) }) { toggle(i, .horn) } else { w.append(lit) }
        case .w:
            if canUndo, let i = w.indices.last, w[i].fromW { w[i] = lit; literal = true; undoAt = undoAt ?? idx; break } // "ww" -> "w"
            if hornPair() { break }
            if let i = vi.last(where: { "aou".contains(w[$0].base) }) {
                toggle(i, w[i].base == "a" ? .breve : .horn)
            } else if vi.isEmpty {
                w.append(Ch(base: "u", mark: .horn, upper: lit.upper, fromW: true)); applied = true
            } else { w.append(lit) }
        case .stroke:
            if let f = w.first, f.base == "d" { toggle(0, .stroke) } else { w.append(lit) }
        }
    }
    // "ưo" followed by anything is always "ươ" (UniKey): "dduwocj" -> "được".
    for i in w.indices.dropLast(2) where w[i].base == "u" && w[i].mark == .horn && w[i + 1].base == "o" && w[i + 1].mark == .none {
        w[i + 1].mark = .horn
    }
    // "ươ" never ends a Vietnamese syllable: word-final it is "uơ" (thuở, huơ).
    if w.count >= 2, w[w.count - 1].base == "o", w[w.count - 1].mark == .horn,
       w[w.count - 2].base == "u", w[w.count - 2].mark == .horn { w[w.count - 2].mark = .none }
    return (w, tone, undoAt)
}

private func render(_ p: (w: [Ch], tone: Int, undoAt: Int?)) -> String {
    let (w, tone, _) = p
    // Tone placement (old style, UniKey default).
    var pos: Int?
    let vi = vowelIndices(w)
    if tone != 0, let last = vi.last {
        if let m = vi.last(where: { w[$0].mark != .none }) { pos = m }         // ê ơ ư â ă ô first
        else if vi.count == 1 || last < w.count - 1 { pos = last }             // has final consonant
        else { pos = vi.count == 2 ? vi[0] : vi[1] }                           // hòa, múa / khuỷu
    }
    return w.indices.map { glyph(w[$0], tone: $0 == pos ? tone : 0) }.joined()
}

private let initials: [String] = ["", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "j", "k", "kh", "l", "m", "n",
    "ng", "ngh", "nh", "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x", "z"]  // j z: teen code (jì, zị); f would shake English f-words
// Vowel clusters that may take a final consonant, and those that end the syllable.
private let closedVowels: Set<String> = ["a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
    "iê", "yê", "oa", "oă", "oe", "oo", "uâ", "uê", "uô", "ươ", "uy", "uyê"]
private let openVowels: Set<String> = ["ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iu", "oi", "ôi", "ơi",
    "ui", "ưi", "ưu", "ua", "ưa", "uơ", "iêu", "yêu", "oai", "oay", "oeo", "uây", "uôi", "ươi", "ươu", "uya", "uyu"]
private let finals: Set<String> = ["c", "ch", "m", "n", "ng", "nh", "p", "t"]
private let vowelGlyphs = Set("aăâeêioôơuưy")

// Marks ignored for prefix checks: "tieng" may still become "tiêng".
private func strip(_ s: String) -> String {
    String(s.map { ["ă": "a", "â": "a", "ê": "e", "ô": "o", "ơ": "o", "ư": "u", "đ": "d"][$0] ?? $0 })
}
private func prefixes(_ set: Set<String>) -> Set<String> {
    Set(set.flatMap { s in (0...s.count).map { strip(String(s.prefix($0))) } })
}
private let allVowels = Array(closedVowels.union(openVowels)).map(Array.init)
// A half-typed vowel group can still grow into a real one: same letters, and every mark already
// typed matches ("tie" -> "tiê" ok, "ôe" -> nothing).
private func vowelPrefixOK(_ v: String) -> Bool {
    let v = Array(v)
    return allVowels.contains { c in
        c.count >= v.count && zip(v, c).allSatisfy { a, b in strip(String(a)) == strip(String(b)) && (a == b || strip(String(a)) == String(a)) }
    }
}
private let finalPrefixes = prefixes(finals)

/// prefix: true -> could more letters still turn `w` into a syllable?
private func isSyllable(_ w: [Ch], tone: Int, prefix: Bool = false) -> Bool {
    let s = w.map { glyph(Ch(base: $0.base, mark: $0.mark, upper: false), tone: 0) }.joined()
    if prefix && initials.contains(where: { $0.hasPrefix(s) }) { return true } // "q" -> "qu", "ng" -> "ngh"
    for ini in initials where s.hasPrefix(ini) {
        let rest = s.dropFirst(ini.count)
        let v = String(rest.prefix { vowelGlyphs.contains($0) })
        let fin = String(rest.dropFirst(v.count))
        if prefix {
            let stopOK = !(fin.hasPrefix("c") || fin.hasPrefix("p") || fin.hasPrefix("t")) || [0, 1, 5].contains(tone)
            if v.isEmpty ? fin.isEmpty : vowelPrefixOK(v) && finalPrefixes.contains(fin) && stopOK {
                return true
            }
            continue
        }
        if fin.isEmpty ? (closedVowels.contains(v) || openVowels.contains(v))
                       : (closedVowels.contains(v) && finals.contains(fin)
                          && (!["c", "ch", "p", "t"].contains(fin) || tone == 0 || tone == 1 || tone == 5)) {
            return true
        }
    }
    return false
}

private let table: [String: [Character]] = [
    "a": Array("aáàảãạ"), "a^": Array("âấầẩẫậ"), "a(": Array("ăắằẳẵặ"),
    "e": Array("eéèẻẽẹ"), "e^": Array("êếềểễệ"),
    "i": Array("iíìỉĩị"),
    "o": Array("oóòỏõọ"), "o^": Array("ôốồổỗộ"), "o+": Array("ơớờởỡợ"),
    "u": Array("uúùủũụ"), "u+": Array("ưứừửữự"),
    "y": Array("yýỳỷỹỵ"),
]

/// `s` with its tone mark removed ("tiếng" -> "tiêng").
func withoutTone(_ s: String) -> String {
    String(s.map { c -> Character in
        guard let (base, mark, t) = reverseTable[Character(c.lowercased())], t != 0,
              let row = table["\(base)\(mark)"] else { return c }
        return c.isUppercase ? Character(row[0].uppercased()) : row[0]
    })
}

/// `s` with its tone mark moved to each vowel: both placement styles (hòa / hoà, khụy / khuỵ).
func toneVariants(_ s: String) -> [String] {
    let chars = Array(s)
    guard let (i, t) = chars.enumerated().lazy.compactMap({ i, c -> (Int, Int)? in
        guard let (_, _, t) = reverseTable[Character(c.lowercased())], t != 0 else { return nil }
        return (i, t)
    }).first else { return [s] }
    func toned(_ c: Character, _ t: Int) -> Character? {
        let lower = Character(c.lowercased())
        guard let (base, mark, _) = reverseTable[lower], let row = table["\(base)\(mark)"] else { return nil }
        return c.isUppercase ? Character(row[t].uppercased()) : row[t]
    }
    var out = [s]
    for j in chars.indices where j != i {
        guard let moved = toned(chars[j], t), let plain = toned(chars[i], 0) else { continue }
        var cs = chars
        cs[i] = plain; cs[j] = moved
        out.append(String(cs))
    }
    return out
}

/// Every initial + vowel cluster + final, with each tone on each vowel of the cluster: a superset
/// of real syllables in both tone-placement styles (hòa / hoà). Used by the corpus tests.
func candidateSyllables() -> [String] {
    var out: [String] = []
    for ini in initials {
        for v in closedVowels.union(openVowels) {
            let vs = Array(v)
            for fin in openVowels.contains(v) ? [""] : [""] + finals.sorted() {
                out.append(ini + v + fin)
                for t in 1...5 {
                    for pos in vs.indices {
                        guard let (base, mark, _) = reverseTable[vs[pos]], let row = table["\(base)\(mark)"] else { continue }
                        var cl = vs
                        cl[pos] = row[t]
                        out.append(ini + String(cl) + fin)
                    }
                }
            }
        }
    }
    return out
}

// Glyph -> (base letter, mark suffix as in `table`, tone); "d" marks đ.
private let reverseTable: [Character: (Character, String, Int)] = {
    var r: [Character: (Character, String, Int)] = ["đ": ("d", "d", 0)]
    for (k, chars) in table { for (t, c) in chars.enumerated() { r[c] = (k.first!, String(k.dropFirst()), t) } }
    return r
}()

private func glyph(_ c: Ch, tone: Int) -> String {
    var s: String
    switch c.mark {
    case .stroke: s = "đ"
    case .hat: s = table["\(c.base)^"].map { String($0[tone]) } ?? String(c.base)
    case .breve: s = table["\(c.base)("].map { String($0[tone]) } ?? String(c.base)
    case .horn: s = table["\(c.base)+"].map { String($0[tone]) } ?? String(c.base)
    case .none: s = table["\(c.base)"].map { String($0[tone]) } ?? String(c.base)
    }
    if c.upper { s = s.uppercased() }
    return s
}
