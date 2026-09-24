import Foundation

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
    ("tesst", .telex, "tesst"), ("test", .telex, "tét"), ("banana", .telex, "banana"), ("google", .telex, "google"),
    ("hello", .telex, "hello"), ("matf", .telex, "matf"), ("mats", .telex, "mát"),
    ("a88", .vni, "a88"), ("hoa8c5", .vni, "hoặc"), ("to6i", .vni, "tôi"),
]

var fail = 0
for (input, m, want) in cases {
    let got = compose(input, method: m)
    if got != want { print("FAIL \(input) -> \(got), want \(want)"); fail += 1 }
}
print(fail == 0 ? "OK \(cases.count) cases" : "\(fail) failed")
exit(fail == 0 ? 0 : 1)
