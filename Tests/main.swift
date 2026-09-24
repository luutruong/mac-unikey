import Foundation

// After Space (finish)
let cases: [(String, Method, String)] = [
    ("vieetj", .telex, "việt"), ("tieengs", .telex, "tiếng"), ("tiengse", .telex, "tiếng"),
    ("hoaf", .telex, "hòa"), ("nguowif", .telex, "người"), ("dduwowcj", .telex, "được"),
    ("quar", .telex, "quả"), ("gif", .telex, "gì"), ("gias", .telex, "giá"),
    ("ass", .telex, "ass"), ("aaa", .telex, "aaa"), ("xooong", .telex, "xoong"), ("tw", .telex, "tư"), ("ww", .telex, "ww"), ("off", .telex, "off"), ("pass", .telex, "pass"),
    ("hoawcj", .telex, "hoặc"), ("khuyur", .telex, "khuỷu"), ("Vieetj", .telex, "Việt"),
    ("DDi", .telex, "Đi"), ("asz", .telex, "a"), ("str", .telex, "str"), ("uoiw", .telex, "ươi"),
    ("hoanf", .telex, "hoàn"), ("muaf", .telex, "mùa"), ("tuaanf", .telex, "tuần"),
    ("vie6t5", .vni, "việt"), ("d9i", .vni, "đi"), ("nguo72i", .vni, "người"),
    // spell check: English words stay as typed
    ("book", .telex, "book"), ("coffee", .telex, "coffee"), ("windows", .telex, "windows"),
    ("Text", .telex, "Text"), ("message", .telex, "message"), ("class", .telex, "class"), ("test", .telex, "tét"), ("banana", .telex, "banana"), ("google", .telex, "google"),
    ("hello", .telex, "hello"), ("generated", .telex, "generated"), ("matf", .telex, "matf"), ("mats", .telex, "mát"),
    ("a88", .vni, "a88"), ("thuowr", .telex, "thuở"), ("huow", .telex, "huơ"),
    ("thuowngf", .telex, "thường"), ("gieengs", .telex, "giếng"), ("quys", .telex, "quý"), ("hoa8c5", .vni, "hoặc"), ("to6i", .vni, "tôi"),
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
for (input, m, want) in cases { check(input, finish(input, method: m), want) }
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
print(fail == 0 ? "OK all cases" : "\(fail) failed")
exit(fail == 0 ? 0 : 1)
