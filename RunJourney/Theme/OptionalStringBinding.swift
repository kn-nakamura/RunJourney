import SwiftUI

/// `Binding<String?>` を `TextField` 等に渡せる `Binding<String>` に変換するヘルパー。
/// 空文字列は nil として書き戻す（"" を保存しないようにする）。
extension Binding where Value == String? {
    var bound: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { newValue in
                self.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}

/// `Binding<Double?>` を文字列入力に橋渡しするヘルパー。
/// 空入力 / 不正な値は nil。それ以外は Double にパースして書き戻す。
extension Binding where Value == Double? {
    var stringBound: Binding<String> {
        Binding<String>(
            get: {
                if let v = self.wrappedValue {
                    // 末尾の余計な 0 を削る (42.195 → "42.195"、42 → "42")
                    return v.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(v))
                        : String(v)
                }
                return ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    self.wrappedValue = nil
                } else if let d = Double(trimmed) {
                    self.wrappedValue = d
                }
            }
        )
    }
}
