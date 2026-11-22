import PrehistoricTimesCore
import SwiftUI

/// One Dino Fact card: a real fact about the zone's dinosaurs, with the zone's friend on it.
struct DinoFactCard: View {
    let level: LevelDef
    let island: Island
    let fact: DialogueLine
    var compact: Bool

    var body: some View {
        HStack(spacing: compact ? 12 : 22) {
            Image(IslandTheme.island(island.id).guardianHappy)
                .resizable().scaledToFit()
                .frame(width: compact ? 120 : 220, height: compact ? 110 : 200)
                .background(Circle().fill(Color(hex: UInt32(island.colour.dropFirst(), radix: 16) ?? 0x7BC86C).opacity(0.35)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                IconLabel("Dino Fact", emoji: "🦖", size: compact ? 16 : 22)
                    .font(.game(compact ? 16 : 22)).foregroundStyle(Palette.coral)
                Text(fact.text)
                    .font(.game(compact ? 18 : 28))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)
                Text("\(island.name) · \(level.title)")
                    .font(.game(compact ? 12 : 15, weight: .bold))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(compact ? 14 : 26)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.cream)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.ink, lineWidth: 4))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.gold, lineWidth: 3).padding(8)))
        .accessibilityElement(children: .combine)
    }
}

/// The card handed over the first time a level is cleared. The narrator reads it out.
struct DinoFactReveal: View {
    let level: LevelDef
    let island: Island
    let fact: DialogueLine
    var done: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: compact ? 8 : 18) {
                Text("You found a Dino Fact card!")
                    .font(.game(compact ? 22 : 34)).foregroundStyle(.white).gameTracking()
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                DinoFactCard(level: level, island: island, fact: fact, compact: compact)
                    .frame(maxWidth: compact ? 620 : 820)
                    .scaleEffect(shown ? 1 : 0.6)
                    .rotationEffect(.degrees(shown ? 0 : -8))
                    .opacity(shown ? 1 : 0)
                HStack(spacing: 14) {
                    Button(action: tapped(read)) { IconLabel("Hear it again", symbol: "speaker.wave.2.fill", size: compact ? 17 : 22) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                    Button(action: tapped(done)) { IconLabel("Keep it!", symbol: "checkmark", size: compact ? 20 : 26, trailing: true) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26))
                }
                Text("It's in your Treasures, with your other Dino Facts.")
                    .font(.game(compact ? 12 : 15, weight: .bold)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(compact ? 10 : 30)
        }
        .onAppear {
            AudioManager.shared.play(.unlock, volume: 0.7)
            withAnimation(model.settings.reducedMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.45)) { shown = true }
            read()
        }
        .onDisappear { Narrator.shared.stop() }
    }

    private func read() { Narrator.shared.say(key: fact.audioKey, fallback: fact.text) }
}

/// Every Dino Fact card, collected or still to find, for the Treasures screen.
struct DinoFactShelf: View {
    var compact: Bool
    @Environment(AppModel.self) private var model
    @Binding var open: String?

    var body: some View {
        let cards = model.catalog.factCards
        let found = cards.filter { (model.profile?.stars(for: $0.level.id) ?? 0) > 0 }.count
        VStack(alignment: .leading, spacing: 10) {
            Text("\(found) of \(cards.count) Dino Fact cards. Clear a level to find its card!")
                .font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 120 : 160), spacing: 12)], spacing: 12) {
                ForEach(cards, id: \.level.id) { card in
                    let owned = (model.profile?.stars(for: card.level.id) ?? 0) > 0
                    let island = model.catalog.island(containing: card.level.id)
                    Button(action: tapped { if owned { open = card.level.id } }) {
                        VStack(spacing: 4) {
                            if let island {
                                Image(IslandTheme.island(island.id).guardianHappy).resizable().scaledToFit()
                                    .frame(height: compact ? 46 : 64)
                                    .saturation(owned ? 1 : 0).opacity(owned ? 1 : 0.3)
                            }
                            Text(owned ? card.level.title : "???").font(.game(compact ? 13 : 17)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                            Text(owned ? "Tap to read" : island.map { "Somewhere in \($0.name)" } ?? "Keep exploring")
                                .font(.game(compact ? 10 : 12, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.6)).lineLimit(2).multilineTextAlignment(.center)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, minHeight: compact ? 104 : 140)
                        .background(RoundedRectangle(cornerRadius: 14).fill(owned ? .white : .white.opacity(0.5))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.ink.opacity(owned ? 1 : 0.3), lineWidth: 3)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!owned)
                    .accessibilityLabel(owned ? "Dino Fact: \(card.level.title)" : "Dino Fact card not found yet")
                }
            }
        }
    }
}

/// A collected fact card, opened from the shelf and read aloud.
struct DinoFactViewer: View {
    let levelID: String
    var close: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: close)
            if let level = model.catalog.level(levelID), let fact = level.fact, let island = model.catalog.island(containing: levelID) {
                VStack(spacing: compact ? 8 : 16) {
                    DinoFactCard(level: level, island: island, fact: fact, compact: compact).frame(maxWidth: compact ? 620 : 820)
                    HStack(spacing: 14) {
                        Button(action: tapped { Narrator.shared.say(key: fact.audioKey, fallback: fact.text) }) {
                            IconLabel("Hear it again", symbol: "speaker.wave.2.fill", size: compact ? 17 : 22)
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 17 : 22))
                        Button(action: tapped(close)) { IconLabel("Close", symbol: "xmark", size: compact ? 17 : 22) }
                            .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 17 : 22))
                    }
                }
                .padding(compact ? 10 : 30)
                .onAppear { Narrator.shared.say(key: fact.audioKey, fallback: fact.text) }
                .onDisappear { Narrator.shared.stop() }
            }
        }
    }
}
