import OneByOneCore
import SwiftUI

/// The layout every sheet shares: a small title, the fields, then Cancel and
/// a main button that's off until the fields make sense.
private struct SheetFrame<Content: View>: View {
    let title: String
    let action: String
    let canSave: Bool
    let width: CGFloat
    let onSave: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSecondary)
            content
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(action) {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: width)
    }
}

/// Adds a new card, or edits one.
struct CardEditor: View {
    enum Mode {
        case add
        case edit(Card)
    }

    let mode: Mode
    let defaultValue: Decimal
    let currency: Currency
    let onSave: (Card, Placement) -> Void

    @State private var title: String
    @State private var note: String
    @State private var valueText: String
    @State private var placement = Placement.last
    @FocusState private var isTitleFocused: Bool

    init(mode: Mode, defaultValue: Decimal, currency: Currency, onSave: @escaping (Card, Placement) -> Void) {
        self.mode = mode
        self.defaultValue = defaultValue
        self.currency = currency
        self.onSave = onSave
        let card: Card? = if case .edit(let card) = mode { card } else { nil }
        _title = State(initialValue: card?.title ?? "")
        _note = State(initialValue: card?.note ?? "")
        _valueText = State(initialValue: card?.value.map { "\($0)" } ?? "")
    }

    private var isAdding: Bool {
        if case .add = mode { true } else { false }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// An empty value field means "use the default".
    private var isValueValid: Bool {
        valueText.trimmingCharacters(in: .whitespaces).isEmpty || Money.parse(valueText) != nil
    }

    var body: some View {
        SheetFrame(
            title: isAdding ? "New task" : "Edit task",
            action: isAdding ? "Add" : "Save",
            canSave: !trimmedTitle.isEmpty && isValueValid,
            width: 460,
            onSave: save
        ) {
            TextField("What needs doing?", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium))
                .focused($isTitleFocused)
            TextField("Note (optional)", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...5)
            Divider()
            HStack(spacing: 10) {
                Text("Reward")
                    .foregroundStyle(Theme.inkSecondary)
                TextField("\(Money.format(defaultValue, in: currency)) (default)", text: $valueText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                Spacer()
                if isAdding {
                    Picker("Goes", selection: $placement) {
                        Text("Next").tag(Placement.next)
                        Text("Last").tag(Placement.last)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 130)
                }
            }
            if !isValueValid {
                Text("Enter an amount like 5 or 2.50.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.debt)
            }
        }
        .onAppear { isTitleFocused = true }
    }

    private func save() {
        var card: Card
        switch mode {
        case .add: card = Card(title: trimmedTitle)
        case .edit(let original): card = original
        }
        card.title = trimmedTitle
        card.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        card.value = Money.parse(valueText)
        onSave(card, placement)
    }
}

/// Turns a card into up to three smaller ones.
struct SplitSheet: View {
    let card: Card
    let value: String
    let onSplit: ([String]) -> Void

    @State private var steps = ["", "", ""]

    private static let placeholders = ["First small step", "Then", "Then (optional)"]

    private var filledSteps: [String] {
        steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var body: some View {
        SheetFrame(title: "Make it smaller", action: "Split", canSave: !filledSteps.isEmpty, width: 420) {
            onSplit(filledSteps)
        } content: {
            Text(card.title)
                .font(.system(size: 18, weight: .medium))
            ForEach(steps.indices, id: \.self) { index in
                TextField(Self.placeholders[index], text: $steps[index])
                    .textFieldStyle(.roundedBorder)
            }
            Text("The \(value) reward is shared between the steps.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
        }
    }
}

/// Adds many tasks at once from text, one per line.
struct AddManySheet: View {
    let onAdd: (String) -> Void

    @State private var text = ""

    private var titles: [String] { PastedList.titles(from: text) }

    var body: some View {
        SheetFrame(
            title: "Add a list",
            action: titles.isEmpty ? "Add" : "Add \(count(titles.count, "Task"))",
            canSave: !titles.isEmpty,
            width: 460
        ) {
            onAdd(text)
        } content: {
            Text("One task per line. Bullets and checkboxes from your notes are removed. The tasks go to the bottom of your deck.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 220)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.hairline))
        }
    }
}

/// Sets one reward for several cards.
struct SetValueSheet: View {
    let count: Int
    let defaultValue: String
    let onSet: (Decimal?) -> Void

    @State private var text = ""

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SheetFrame(
            title: count == 1 ? "Set the reward" : "Set the reward for \(count) tasks",
            action: "Set",
            canSave: isEmpty || Money.parse(text) != nil,
            width: 380
        ) {
            onSet(Money.parse(text))
        } content: {
            TextField("\(defaultValue) (default)", text: $text)
                .textFieldStyle(.roundedBorder)
            Text("Leave it empty to use the default.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
        }
    }
}

/// Logs reward money spent on something, or edits an entry.
struct SpendSheet: View {
    let existing: Spend?
    let balance: Decimal
    let currency: Currency
    let interestRate: Decimal
    let onSave: (Spend) -> Void

    @State private var note: String
    @State private var amountText: String
    @State private var date: Date
    @FocusState private var isNoteFocused: Bool

    init(existing: Spend?, balance: Decimal, currency: Currency, interestRate: Decimal, onSave: @escaping (Spend) -> Void) {
        self.existing = existing
        self.balance = balance
        self.currency = currency
        self.interestRate = interestRate
        self.onSave = onSave
        _note = State(initialValue: existing?.note ?? "")
        _amountText = State(initialValue: existing.map { "\($0.amount)" } ?? "")
        _date = State(initialValue: existing?.date ?? .now)
    }

    private var amount: Decimal? {
        Money.parse(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Warns when this spending takes the balance below zero.
    private var warning: String? {
        guard let amount else { return nil }
        let after = balance + (existing?.amount ?? 0) - amount
        guard after < 0 else { return nil }
        let rate = (interestRate * 100).formatted(.number.precision(.fractionLength(0...2)))
        return "This puts you \(Money.format(-after, in: currency)) in the red. Interest is \(rate)% a year until you earn it back."
    }

    var body: some View {
        SheetFrame(
            title: existing == nil ? "Spend rewards" : "Edit spending",
            action: existing == nil ? "Spend" : "Save",
            canSave: amount != nil,
            width: 440
        ) {
            guard let amount else { return }
            let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(Spend(id: existing?.id ?? UUID(), amount: amount, note: note, date: date))
        } content: {
            TextField("What did you treat yourself to?", text: $note)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .medium))
                .focused($isNoteFocused)
            Divider()
            HStack(spacing: 10) {
                Text("Amount")
                    .foregroundStyle(Theme.inkSecondary)
                TextField(Money.symbol(of: currency), text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                Spacer()
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
            }
            if let warning {
                Text(warning)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.debt)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { isNoteFocused = true }
    }
}
