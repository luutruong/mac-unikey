# MacUnikey

Bộ gõ tiếng Việt cho macOS (InputMethodKit), gõ Telex hoặc VNI theo kiểu UniKey.

## Tính năng

- **Telex / VNI**: chọn trong menu của input source trên menu bar.
- **Luật UniKey**: từ không phải tiếng Việt (`book`, `json`) được giữ như đã gõ; muốn bỏ dấu thì gõ lặp phím (`thiss` → `this`, `ass` → `as`, `ww` → `w`). Bộ gõ tra từ điển tiếng Việt có sẵn trên macOS.
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

Thêm `corpus` (`./build/t corpus`) để kiểm tra trên toàn bộ từ điển: mọi âm tiết tiếng Việt (Telex/VNI) và độ nhảy chữ khi gõ. Chạy khá lâu.

Thêm `log` (`./build/t log`) để gõ lại các từ trong `typing.log` bằng luật hiện tại và liệt kê những từ giờ ra kết quả khác lúc ghi log.

## Cấu trúc

| File | Vai trò |
|------|---------|
| `Sources/Engine.swift` | Ghép phím thô của một từ thành chữ Unicode (Telex/VNI) |
| `Sources/Word.swift` | Trạng thái một từ: chọn chữ hiển thị và chữ chốt, từ điển |
| `Sources/InputController.swift` | Controller của IMK: xử lý phím, Delete, Return, bật/tắt V/E, menu |
| `Sources/main.swift` | Khởi động IMK server |
| `Tests/main.swift` | Test các case và test corpus |
| `build.sh` | Build, tạo icon, ký và cài đặt |
