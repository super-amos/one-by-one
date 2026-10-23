import Foundation
import OneByOneCore

/// Formats and reads reward amounts in the user's currency.
enum Money {
    /// "$5" for whole amounts, "$0.66" otherwise, with a real minus sign when
    /// the user owes.
    static func format(_ value: Decimal, in currency: Currency) -> String {
        let style = Decimal.FormatStyle.Currency(code: currency.code, locale: Locale(identifier: "en_US"))
        let isWhole = value.rounded(scale: 0, .plain) == value.rounded(scale: 2, .plain)
        let text = abs(value).formatted(style.precision(.fractionLength(isWhole ? 0 : 2)))
        return value < 0 ? "\u{2212}" + text : text
    }

    /// The currency's symbol on its own, like "$" or "₪".
    static func symbol(of currency: Currency) -> String {
        format(1, in: currency).replacing(/[\d\s]/, with: "")
    }

    /// Reads an amount the user typed, like "5", "2.50" or "$3". Returns nil
    /// for anything else, including an empty field.
    static func parse(_ text: String) -> Decimal? {
        let number = String(text.trimmingCharacters(in: .whitespaces).drop { !$0.isNumber && $0 != "." })
        guard number.wholeMatch(of: /\d+(\.\d{1,2})?/) != nil else { return nil }
        return Decimal(string: number, locale: Locale(identifier: "en_US_POSIX"))
    }
}
