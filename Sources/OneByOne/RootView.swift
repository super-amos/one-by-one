import OneByOneCore
import SwiftUI

/// The window: whichever page is open, plus the sheets and alerts any page can raise.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            Theme.background.ignoresSafeArea()
            switch model.page {
            case .home: HomeView().transition(.opacity)
            case .edit: EditView().transition(.opacity)
            case .history: HistoryView().transition(.opacity)
            case .trash: TrashView().transition(.opacity)
            case .rewards: RewardsView().transition(.opacity)
            }
        }
        .sheet(item: $model.sheet) { sheet in
            SheetView(sheet: sheet)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.problem ?? "")
        }
    }
}

/// Picks a sheet's contents. Each sheet applies its change through the model.
private struct SheetView: View {
    @Environment(AppModel.self) private var model
    let sheet: AppModel.Sheet

    var body: some View {
        switch sheet {
        case .add:
            CardEditor(mode: .add, defaultValue: model.deck.defaultValue, currency: model.settings.currency) { card, placement in
                withAnimation(.card) { model.add(card, placement: placement) }
            }
        case .edit(let card):
            CardEditor(mode: .edit(card), defaultValue: model.deck.defaultValue, currency: model.settings.currency) { card, _ in
                withAnimation(.card) { model.update(card) }
            }
        case .split(let card):
            SplitSheet(card: card, value: model.money(model.deck.value(of: card))) { titles in
                withAnimation(.card) { model.split(card.id, into: titles) }
            }
        case .addMany:
            AddManySheet { text in
                withAnimation(.card) { _ = model.addLines(text) }
            }
        case .setValue(let ids):
            SetValueSheet(count: ids.count, defaultValue: model.money(model.deck.defaultValue)) { value in
                withAnimation(.card) { model.setValue(value, for: ids) }
            }
        case .spend(let spend):
            SpendSheet(
                existing: spend,
                balance: model.state.balance,
                currency: model.settings.currency,
                interestRate: model.settings.interestRate
            ) { saved in
                withAnimation {
                    if spend == nil { model.logSpend(saved) } else { model.updateSpend(saved) }
                }
            }
        }
    }
}
