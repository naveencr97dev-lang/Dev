import SwiftUI

/// Home: how the club makes money during the season, and what came in so far.
struct SeasonMoneyCard: View {
    @EnvironmentObject var store: GameStore
    let career: Career

    var body: some View {
        let c = career
        let earned: [MoneyCategory] = [.tickets, .sponsors, .merchandise, .sales, .revenue, .prizes]
        let spent: [MoneyCategory] = [.wages, .purchases, .facilities]
        let net = MoneyCategory.allCases.reduce(0) { $0 + c.seasonTotal($1) }
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Money this season")
            VStack(spacing: 0) {
                ForEach(earned.filter { c.seasonTotal($0) != 0 } + spent.filter { c.seasonTotal($0) != 0 }, id: \.self) { cat in
                    row(cat.label, c.seasonTotal(cat))
                    Hairline(inset: 14)
                }
                row("Net so far", net, bold: true)
                if let g = c.expectedGate {
                    Hairline(inset: 14)
                    HStack {
                        Text("Next home match").font(.system(size: 14 * TextScale.factor)).foregroundStyle(Palette.muted)
                        Spacer()
                        Text("~\(g.fans.formatted()) fans · \(Money.format(g.money))").font(.score(14)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                Hairline(inset: 14)
                HStack {
                    Text("Main sponsor").font(.system(size: 14 * TextScale.factor)).foregroundStyle(Palette.muted)
                    Spacer()
                    Text("\(c.sponsorName(c.userClubId)) · \(Money.format(c.sponsorMonthly(for: c.userClubId))) a month")
                        .font(.score(14)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                Hairline(inset: 14)
                HStack {
                    Text("Ticket price").font(.system(size: 14 * TextScale.factor)).foregroundStyle(Palette.muted)
                    Spacer()
                    Picker("Ticket price", selection: Binding(get: { c.settings.ticketPrice },
                                                              set: { store.careerSetTicketPrice($0) })) {
                        ForEach(TicketPrice.allCases) { t in Text(t.label).tag(t) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 210)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
            }
            .gameFrame()
            Text("Money comes in every week: tickets after each home match, merchandise every week, your sponsor every month, and fees when you sell players (Transfers). Central revenue and prize money arrive after the final. A bigger Stadium sells more tickets; the Commercial Hub brings more merchandise and a bigger sponsor deal.")
                .font(.system(size: 12 * TextScale.factor)).foregroundStyle(Palette.muted)
                .padding(.horizontal, 4)
        }
    }

    private func row(_ label: String, _ amount: Int, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 14 * TextScale.factor, weight: bold ? .semibold : .regular))
                .foregroundStyle(bold ? .white : Palette.muted)
            Spacer()
            Text((amount >= 0 ? "+" : "−") + Money.format(abs(amount)))
                .font(.score(14, weight: bold ? .bold : .regular))
                .foregroundStyle(amount >= 0 ? Palette.accent : Palette.wicket)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

/// Club › Money: this season's money (left) and the ledger (right).
struct MoneyScreen: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        PaneScreen(title: "Money") {
            if let c = store.career { SeasonMoneyCard(career: c) }
        } right: {
            if let c = store.career { FinanceCard(career: c) }
        }
    }
}
