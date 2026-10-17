import Foundation

// After Space (finish)
let cases: [(String, Method, String)] = [
    ("vieetj", .telex, "việt"), ("tieengs", .telex, "tiếng"), ("tiengse", .telex, "tiếng"),
    ("hoaf", .telex, "hòa"), ("nguowif", .telex, "người"), ("dduwowcj", .telex, "được"),
    ("quar", .telex, "quả"), ("gif", .telex, "gì"), ("gias", .telex, "giá"),
    ("ass", .telex, "as"), ("aaa", .telex, "aa"), ("xooong", .telex, "xoong"), ("tw", .telex, "tư"), ("ww", .telex, "w"), ("off", .telex, "of"), ("pass", .telex, "pas"), ("this", .telex, "thí"), ("thiss", .telex, "this"),
    ("hoawcj", .telex, "hoặc"), ("khuyur", .telex, "khuỷu"), ("Vieetj", .telex, "Việt"),
    ("DDi", .telex, "Đi"), ("asz", .telex, "a"), ("str", .telex, "str"), ("uoiw", .telex, "ươi"),
    ("hoanf", .telex, "hoàn"), ("muaf", .telex, "mùa"), ("tuaanf", .telex, "tuần"),
    ("vie6t5", .vni, "việt"), ("d9i", .vni, "đi"), ("nguo72i", .vni, "người"),
    // not Vietnamese: keys as typed; a doubled key cancels its mark (UniKey)
    ("book", .telex, "book"), ("coffee", .telex, "cofee"), ("windows", .telex, "windows"),
    ("Text", .telex, "Text"), ("message", .telex, "mesage"), ("class", .telex, "class"), ("Cross", .telex, "Cross"), ("process", .telex, "process"), ("cherry", .telex, "chery"), ("test", .telex, "tét"), ("banana", .telex, "banana"), ("google", .telex, "google"),
    ("hello", .telex, "hello"), ("generated", .telex, "generated"), ("matf", .telex, "matf"), ("mats", .telex, "mát"),
    ("a88", .vni, "a8"), ("thuowr", .telex, "thuở"), ("huow", .telex, "huơ"),
    ("thuowngf", .telex, "thường"), ("gieengs", .telex, "giếng"), ("quys", .telex, "quý"), ("dduwocj", .telex, "được"), ("nguwowif", .telex, "người"), ("huwowu", .telex, "hươu"), ("hoa8c5", .vni, "hoặc"), ("to6i", .vni, "tôi"),
    // teen code
    ("ddc", .telex, "đc"), ("DDc", .telex, "Đc"), ("ddk", .telex, "đk"), ("d9c", .vni, "đc"), ("ddd", .telex, "dd"), ("dd", .telex, "đ"), ("DD", .telex, "Đ"), ("d9", .vni, "đ"),
    ("Zij", .telex, "Zị"), ("Chooj", .telex, "Chộ"), ("zui", .telex, "zui"), ("jif", .telex, "jì"),
    ("fair", .telex, "fair"), ("zoo", .telex, "zô"), ("zoom", .telex, "zôm"), ("jeans", .telex, "jeans"), ("fix", .telex, "fix"),
    ("xof", .telex, "xò"), ("Xof", .telex, "Xò"), ("ddeechj", .telex, "đệch"), ("xo2", .vni, "xò"), ("tauj", .telex, "tạu"),
    ("Ohf", .telex, "Òh"), ("ahf", .telex, "àh"), ("uwh", .telex, "ưh"), ("oh", .telex, "oh"), ("ohm", .telex, "ohm"), ("each", .telex, "each"),
    // no Vietnamese syllable ends in ă/â, or in c ch p t without sắc/nặng
    ("data", .telex, "data"), ("deep", .telex, "deep"), ("loop", .telex, "loop"), ("raw", .telex, "raw"), ("aa", .telex, "aa"),
    ("dataa", .telex, "data"), ("vieet", .telex, "vieet"), ("a8", .vni, "a8"),
    // a vowel after the tone key: dictionary words only
    ("jira", .telex, "jira"), ("chore", .telex, "chore"), ("param", .telex, "param"), ("hofa", .telex, "hòa"), ("khore", .telex, "khỏe"), ("cura", .telex, "của"),
]

// While typing (compose): transforms shown even if the word isn't Vietnamese yet
let live: [(String, Method, String)] = [
    ("book", .telex, "book"), ("boo", .telex, "bô"), ("vieetj", .telex, "việt"), ("tiengs", .telex, "tiéng"),
    ("Tex", .telex, "Tẽ"), ("Text", .telex, "Text"), ("genera", .telex, "genera"), ("mess", .telex, "mess"),
    ("coffe", .telex, "coffe"), ("ngu", .telex, "ngu"), ("dduwow", .telex, "đuơ"), ("dduwowc", .telex, "đươc"),
]

var fail = 0
func check(_ input: String, _ got: String, _ want: String) {
    if got != want { print("FAIL \(input) -> \(got), want \(want)"); fail += 1 }
}
// (cases are checked through Word below, exactly as the app types them)
for (input, m, want) in live { check(input, compose(input, method: m), want) }

// Simulates the controller: type `input`, press Delete `n` times, return what's shown.
func typeThenDelete(_ input: String, _ n: Int, _ m: Method) -> String {
    var raw = "", literal = false
    for c in input { raw.append(c); if !literal && isLiteral(raw, method: m) { literal = true } }
    for _ in 0..<n { (raw, literal) = backspace(raw, literal: literal, method: m) }
    return literal ? raw : compose(raw, method: m)
}
let deletes: [(String, Int, Method, String)] = [
    ("depends", 1, .telex, "depend"), ("depends", 3, .telex, "depe"), ("depends", 4, .telex, "dep"),
    ("vieetj", 1, .telex, "việ"), ("nguowif", 1, .telex, "ngườ"), ("hoanf", 1, .telex, "hoà"),
    ("vie6t5", 1, .vni, "việ"), ("book", 1, .telex, "boo"), ("tieengs", 7, .telex, ""),
]
for (input, n, m, want) in deletes { check("\(input) ⌫\(n)", typeThenDelete(input, n, m), want) }
// keys(for:) round-trips, so typing continues naturally after Delete ("việ" + "t" -> "việt")
for word in ["việt", "người", "được", "tiếng", "khuỷu", "quả", "giếng", "Đi", "hoặc", "thuở", "Việt"] {
    for m in [Method.telex, .vni] { check("keys(\(word))", compose(keys(for: word, method: m), method: m), word) }
}
check("việ⌫+t", compose(keys(for: "việ", method: .telex) + "t", method: .telex), "việt")
// What the app commits: the same Word state machine the input controller uses.
func typed(_ input: String, _ m: Method) -> String {
    var w = Word()
    for c in input { w.type(c, m) }
    return w.commit(m)
}
for (input, m, want) in cases { check("typed \(input)", typed(input, m), want) }
// Gõ tắt: looked up by the committed word, following its case.
let macros = ["đc": "được", "tks": "cảm ơn nhiều"]
for (input, want) in [("ddc", "được"), ("DDc", "Được"), ("DDC", "ĐƯỢC"), ("tks", "cảm ơn nhiều"), ("Tks", "Cảm ơn nhiều"), ("book", "book")] {
    let w = typed(input, .telex)
    check("macro \(input)", Macros.expand(w, macros) ?? w, want)
}
// Typo, Delete back past it, type on ("TYooi" ⌫⌫⌫⌫ "ooi"), and continuing a word left in the text.
func typedEdit(_ first: String, _ n: Int, _ then: String, _ m: Method) -> String {
    var w = Word()
    for c in first { w.type(c, m) }
    for _ in 0..<n { w.delete(m) }
    for c in then { w.type(c, m) }
    return w.commit(m)
}
check("TYooi⌫4+ooi", typedEdit("TYooi", 4, "ooi", .telex), "Tôi")
check("messa⌫1", typedEdit("messa", 1, "", .telex), "mes")
for (text, more, want) in [("co", "nf", "còn"), ("ch", "ayj", "chạy"), ("việ", "t", "việt"), ("timeo", "ut", "timeout"), ("cros", "s", "cross"), ("proces", "s", "process"), ("vieet", "j", "việt")] {
    var w = Word(resuming: text, .telex)
    for c in more { w.type(c, .telex) }
    check("resume \(text)+\(more)", w.commit(.telex), want)
}
// Auto-capitalization: armed after . ! ? + space, not after "e.g", "3.5", Return or Tab; a letter disarms it.
for (keys, want) in [("đi. ", true), ("? ", true), (".  ", true), ("e.g", false), ("3.5", false), (".\r", false), ("! \t", false), (". a", false)] {
    var st = SentenceStart()
    for k in keys { if k.isLetter { st.clear() } else { st.other(k) } }
    check("sentence \(keys.debugDescription)", "\(st.armed)", "\(want)")
}
for (before, at, want) in [("", 0, true), ("đi. ", 4, true), ("đi.  ", 5, true), ("đi.", 3, false), ("e.g", 3, false), ("đi.\n", 4, false), ("abc ", 4, false)] {
    check("starts \(before.debugDescription)", "\(SentenceStart.starts(after: before, at: at))", "\(want)")
}
check("typed Vieetj", typed("Vieetj", .telex), "Việt")
check("typed Ddi", typed("Ddi", .telex), "Đi")
// Typing log replay: `./t log` — logged words the current rules commit differently (regressions or fixes).
if CommandLine.arguments.contains("log") {
    let path = NSHomeDirectory() + "/Library/Application Support/MacUnikey/typing.log"
    var changed: [String: Int] = [:]
    for line in ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").split(separator: "\n") {
        let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard f.count >= 6, f[1] == "word", let m = Method(rawValue: f[3]) else { continue }
        let now = typed(f[4], m)
        if now != f[5] { changed["\(f[4]): \(f[5]) -> \(now)", default: 0] += 1 }
    }
    print("Typing log: \(changed.values.reduce(0, +)) words now commit differently")
    for (k, n) in changed.sorted(by: { ($0.value, $1.key) > ($1.value, $0.key) }) { print("  \(n)x", k) }
}
// Corpus run (slow): `./t corpus` — whole-dictionary checks instead of hand-picked words.
if CommandLine.arguments.contains("corpus") {
    // Vietnamese: every syllable the macOS Vietnamese dictionary accepts, typed in Telex and VNI,
    // tone key last ("tieengs") and right after its vowel ("tieesng"). Another real tone-placement
    // style of the same word (hoà vs hòa) counts as a variant, not a failure.
    let real = Set(candidateSyllables().filter { Dictionaries.isVietnamese($0) })
    var vOK = 0, vVariant = 0, vFail: [String] = []
    // Plain "oo" (xoong, coong) needs "ooo" in Telex because "oo" means "ô": tested by hand above.
    let plainOO = real.filter { $0.folding(options: .diacriticInsensitive, locale: nil).contains("oo") && !$0.contains("ô") }
    for syl in real.subtracting(plainOO).sorted() {
        for m in [Method.telex, .vni] {
            for input in [keys(for: syl, method: m), syl.map { keys(for: String($0), method: m) }.joined()] {
                let got = typed(input, m)
                if got == syl { vOK += 1 }
                else if toneVariants(got).contains(syl) { vVariant += 1 }
                else { vFail.append("\(syl) [\(input)] -> \(got)") }
            }
        }
    }
    print("Vietnamese: \(real.count) syllables (\(plainOO.count) plain-oo skipped), \(vOK) ok, \(vVariant) other tone placement, \(vFail.count) failed")
    for f in vFail.prefix(40) { print("  VI FAIL", f) }

    // Plain lowercase words from /usr/share/dict/words, for the jitter check below.
    let words = ((try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8)) ?? "")
        .split(separator: "\n").map(String.init)
        .filter { (2...12).contains($0.count) && $0.allSatisfy { ("a"..."z").contains($0) } }

    // Jitter: while typing, the text shown (accents removed) should only grow. A key after which
    // letters vanish or change ("mess" -> "mesa" -> "messag") makes the word shake on screen.
    func fold(_ s: String) -> String { s.folding(options: .diacriticInsensitive, locale: nil).replacingOccurrences(of: "đ", with: "d") }
    // One jump per word is inherent (an accent shown, then undone by the next letter); two or more
    // is the text flipping back and forth — that's what looks like shaking.
    func jumps(_ input: String, _ m: Method) -> [String] {
        var w = Word(), prev = "", out: [String] = []
        for c in input {
            w.type(c, m)
            let now = w.display(m)
            if !fold(now).hasPrefix(fold(prev)) { out.append("\(prev)→\(now)") }
            prev = now
        }
        return out
    }
    let enJumps = words.map { ($0, jumps($0, .telex)) }
    let viJumps = real.subtracting(plainOO).sorted().map { ($0, jumps(keys(for: $0, method: .telex), .telex)) }
    let enOne = enJumps.filter { $0.1.count == 1 }.count, enMany = enJumps.filter { $0.1.count >= 2 }
    let viAny = viJumps.filter { !$0.1.isEmpty }
    print("Jitter: English \(enOne) words jump once, \(enMany.count) flip back and forth; Vietnamese \(viAny.count)/\(viJumps.count) syllables jump")
    for (w, j) in enMany.prefix(12) { print("  FLIP", w, j.joined(separator: " ")) }
    for (w, j) in viAny.prefix(15) { print("  VI JUMP", w, j.joined(separator: " ")) }

    // Compensation: whenever an English word shows accents while typing, the user presses that
    // key once more to cancel them, then finishes the word. Result must be the word.
    var cTried = 0, cOK = 0, cFail: [String] = []
    for w in words where w.count >= 3 {
        var word = Word(), extra = false
        for c in w {
            let hadMarks = word.display(.telex).contains(where: { !$0.isASCII }) // this key adds the marks
            word.type(c, .telex)
            // only a key that adds marks (tone s f r x j, hat a e o, w, d) can be pressed again to cancel them
            let marked = word.display(.telex).contains(where: { !$0.isASCII })
            if !extra, "sfrxjaeowd".contains(c), marked, !hadMarks {
                word.type(c, .telex); extra = true
            }
        }
        guard extra else { continue }
        cTried += 1
        let got = word.commit(.telex)
        if got == w { cOK += 1 } else { cFail.append("\(w) [\(word.raw)] -> \(got)") }
    }
    print("Compensation: \(cTried) English words showed accents, \(cOK) recovered, \(cFail.count) failed")
    for f in cFail.prefix(40) { print("  COMP FAIL", f) }
}
print(fail == 0 ? "OK all cases" : "\(fail) failed")
exit(fail == 0 ? 0 : 1)
