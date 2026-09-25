# MacUnikey

Bộ gõ tiếng Việt cho macOS (InputMethodKit), gõ Telex hoặc VNI theo kiểu UniKey, có kiểm tra chính tả để từ tiếng Anh được giữ nguyên.

## Tính năng

- **Telex / VNI**: chọn trong menu của input source trên menu bar.
- **Tự nhận từ tiếng Anh**: `book`, `coffee`, `windows` được giữ nguyên, còn `vieetj` thành `việt`. Bộ gõ tra từ điển tiếng Việt và tiếng Anh có sẵn trên macOS.
- **Gõ lặp phím để huỷ dấu**: `ass` → `ass`, `ww` → `w`.
- **Chuyển Việt/Anh bằng Ctrl+Shift** (nhấn rồi thả), có nhãn nhỏ hiện dưới con trỏ.
- **Teen code**: `zij` → `zị`, `jif` → `jì`, `ohf` → `òh`.
- **Gõ ổn định trong app native** (Telegram, TextEdit…): sửa thẳng vào văn bản, không dùng marked text nên dòng chữ không bị nhảy. App Chromium/Electron vẫn dùng marked text.

## Yêu cầu

- macOS 14 trở lên
- Xcode Command Line Tools (`swiftc`, `iconutil`)

## Cài đặt

```bash
./build.sh
```

Script sẽ build `build/MacUnikey.app` rồi copy vào `~/Library/Input Methods`. Sau đó:

- **Cài lần đầu**: System Settings › Keyboard › Input Sources › Edit… › + › Vietnamese › MacUnikey
- **Đã thêm từ trước**: chuyển sang input source khác (ví dụ U.S.) rồi chuyển lại MacUnikey (Ctrl+Space)

### Quyền Accessibility

Khi đang gõ dở một từ mà nhấn Return, bộ gõ cần chốt từ rồi gửi lại phím Return. Việc này cần quyền Accessibility (macOS sẽ hỏi một lần). Nếu không cấp quyền, trong app Chromium có thể phải nhấn Return hai lần mới gửi được.

### Ký bằng chứng chỉ (tuỳ chọn)

Mỗi lần build, chữ ký ad-hoc lại khác nhau nên macOS bỏ quyền Accessibility đã cấp. Để quyền được giữ, ký bằng chứng chỉ Apple Development:

```bash
echo 'TEAM_ID=XXXXXXXXXX' > signing.local
```

Có thể dùng `SIGN_ID` (hash của identity) thay cho `TEAM_ID`. File `signing.local` đã được git-ignore.

### Log gõ phím (tuỳ chọn)

```bash
./build.sh --enable-logging
```

Bản build này ghi các từ đã gõ xong và các lần nhấn Delete (theo từng app) vào `~/Library/Application Support/MacUnikey/typing.log`, dùng để cải thiện luật gõ. Bản build thường không ghi lại nội dung gõ.

## Test

```bash
swiftc -O Sources/Engine.swift Sources/Word.swift Tests/main.swift -o build/t && ./build/t
```

Thêm `corpus` (`./build/t corpus`) để kiểm tra trên toàn bộ từ điển: mọi âm tiết tiếng Việt (Telex/VNI), mọi từ tiếng Anh macOS biết, độ nhảy chữ khi gõ và việc huỷ dấu bằng phím lặp. Chạy khá lâu.

## Cấu trúc

| File | Vai trò |
|------|---------|
| `Sources/Engine.swift` | Ghép phím thô của một từ thành chữ Unicode (Telex/VNI) |
| `Sources/Word.swift` | Trạng thái một từ: chọn giữa tiếng Việt và tiếng Anh, từ điển |
| `Sources/InputController.swift` | Controller của IMK: xử lý phím, Delete, Return, bật/tắt V/E, menu |
| `Sources/main.swift` | Khởi động IMK server; `--syllables` in danh sách âm tiết lúc build |
| `Tests/main.swift` | Test các case và test corpus |
| `build.sh` | Build, tạo icon, ký và cài đặt |
