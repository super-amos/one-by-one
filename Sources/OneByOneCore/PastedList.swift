/// Turns pasted text into task titles: one per line, without the bullets,
/// numbers or checkboxes notes apps put in front, and skipping blank lines.
public enum PastedList {
    public static func titles(from text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { line in
                String(line)
                    .replacing(/^\s*(?:(?:[-*•]|\d+[.)]|\[[ xX]?\])\s+)+/, with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }
}
