import PrehistoricTimesCore
import SpriteKit
import SwiftUI

/// The archipelago. Tap an island to see it, then explore.
struct MapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    @State private var scene = WorldMapScene()
    @State private var selected: String?
    @State private var showingPhoto = false
    /// The name of an island that has just been unlocked, shown in a banner for a few seconds.
    @State private var unlockBanner: String?

    private var states: [IslandState] {
        guard let profile = model.profile else { return [] }
        let currentID = Progression.nextLevel(for: profile, catalog: model.catalog).flatMap { model.catalog.island(containing: $0.id)?.id }
            ?? profile.lastLevelID.flatMap { model.catalog.island(containing: $0)?.id }
        return model.catalog.islands.map { island in
            IslandState(id: island.id, name: island.name, unlocked: Progression.isUnlocked(island: island, in: profile, catalog: model.catalog),
                        ready: island.ready, part: island.part,
                        hasCrystal: profile.crystals.contains(island.id), restoration: CGFloat(model.restoration(of: island)),
                        isCurrent: island.id == currentID)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                SceneBackdrop(scene: scene, extraTop: compact ? 50 : 80, extraBottom: compact ? 84 : 130)
                    .onChange(of: !reduceMotion && !model.settings.reducedMotion, initial: true) { _, active in
                        scene.cover.shader = active ? IslandAtmosphere.shader(for: "bg_map") : nil
                    }
                VStack(spacing: 0) {
                    HStack(spacing: compact ? 8 : 12) {
                        RoundButton(symbol: "house.fill", label: "Title screen") { model.route = .title }
                        CountChip(emoji: model.profile?.avatar ?? "🙂", text: model.profile?.nickname ?? "").fixedSize()
                        Spacer()
                        CountChip(emoji: "⭐️", text: "\(model.profile?.totalStars ?? 0)").fixedSize()
                        CountChip(emoji: "⚙️", text: "\(model.profile?.crystals.count ?? 0)/6").fixedSize()
                            .accessibilityLabel("\(model.profile?.crystals.count ?? 0) of 6 Times Machine parts")
                        TrophiesButton(size: compact ? 16 : 20, showsTitle: !compact)
                        let hasPhoto = GroupPhoto.isUnlocked(model.profile, catalog: model.catalog)
                        if hasPhoto {
                            GroupPhotoButton(size: compact ? 16 : 20, showsTitle: !compact) { showingPhoto = true }
                        }
                        // On a phone the bar is short of room once the photo is there, so Treasures shows just its picture.
                        Button(action: tapped { model.route = .collection }) {
                            if compact && hasPhoto {
                                Glyph("🎒", size: 16 * 1.35).padding(.vertical, -16 * 0.2)
                            } else {
                                IconLabel("Treasures", emoji: "🎒", size: compact ? 16 : 20)
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: compact ? 16 : 20))
                        .accessibilityLabel("Treasures")
                        Button(action: tapped { model.route = .museum }) {
                            if compact { Glyph("🦴", size: 16 * 1.35).padding(.vertical, -16 * 0.2) } else { IconLabel("Museum", emoji: "🦴", size: 20) }
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 16 : 20))
                        .accessibilityLabel("Fossil Museum")
                        Button(action: tapped { model.route = .home }) {
                            if compact { Glyph("🏕", size: 16 * 1.35).padding(.vertical, -16 * 0.2) } else { IconLabel("Camp", emoji: "🏕", size: 20) }
                        }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 16 : 20))
                        .accessibilityLabel("Crash Camp")
                    }
                    .padding(.horizontal, compact ? 6 : 20)
                    .padding(.top, compact ? 6 : 14)
                    if let unlockBanner {
                        IconLabel("New zone to explore: \(unlockBanner)!", emoji: "✨", size: compact ? 16 : 22)
                            .font(.game(compact ? 16 : 22)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 18).padding(.vertical, 8).panel(fill: Palette.gold, radius: 18)
                            .padding(.top, compact ? 6 : 14)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                    if model.breakSuggested {
                        IconLabel("Great playing today! This is a good moment for a break.", emoji: "🌙", size: compact ? 14 : 18)
                            .font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14).padding(.vertical, 6).panel(fill: Palette.gold, radius: 16)
                            .padding(.bottom, 6)
                    }
                    if selected == WorldMapScene.campID, let profile = model.profile {
                        campCard(profile: profile, compact: compact)
                            .scaleEffect(ScreenMetrics.scale(geometry), anchor: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, compact ? 6 : 24)
                    } else if let island = selected.flatMap({ model.catalog.island($0) }), let profile = model.profile {
                        card(island, profile: profile, compact: compact)
                            .scaleEffect(ScreenMetrics.scale(geometry), anchor: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, compact ? 6 : 24)
                    } else {
                        Text(states.first(where: { $0.isCurrent && $0.unlocked && $0.ready }).map { "Tap \($0.name) to play!" } ?? "Tap a zone to explore")
                            .font(.game(compact ? 15 : 22, weight: .bold)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 16).padding(.vertical, compact ? 5 : 8).panel(radius: 18)
                            .padding(.bottom, compact ? 6 : 24)
                    }
                }
                .animation(.spring(duration: 0.3), value: selected)
                .animation(.spring(duration: 0.4), value: unlockBanner)
                if showingPhoto { GroupPhotoViewer { showingPhoto = false } }
            }
            .environment(\.compact, compact)
        }
        .onAppear {
            scene.configure(states)
            if let profile = model.profile {
                scene.pets = profile.rewards.filter { model.catalog.reward($0)?.kind == .pet }.map { "reward_\($0)" }
            }
            scene.onSelect = { selected = $0 }
            if let id = model.unlockedIsland, let island = model.catalog.island(id), island.ready {
                model.unlockedIsland = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.7))
                    scene.celebrateUnlock(id)
                    selected = id
                    unlockBanner = island.name
                    try? await Task.sleep(for: .seconds(4))
                    unlockBanner = nil
                }
            }
        }
    }

    /// "×3", "×2 ×5 ×10", or "Mixed tables" when there are too many to list.
    static func tablesText(_ tables: [Int]) -> String {
        tables.count > 4 ? "Mixed tables" : tables.map { "×\($0)" }.joined(separator: " ")
    }

    /// Crash Camp: how the Times Machine is coming along, and the way into the camp and the museum.
    private func campCard(profile: Profile, compact: Bool) -> some View {
        let parts = profile.crystals.count
        return HStack(spacing: compact ? 12 : 20) {
            Image(parts == model.catalog.islands.count ? "machine_whole" : "machine_wrecked").resizable().scaledToFit()
                .frame(height: compact ? 64 : 100)
            VStack(alignment: .leading, spacing: 2) {
                Text("Crash Camp").font(.game(compact ? 22 : 30)).foregroundStyle(Palette.ink)
                Text(parts == model.catalog.islands.count ? "The Times Machine is fixed!"
                     : "\(parts) of \(model.catalog.islands.count) Times Machine parts back")
                    .font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
            }
            Spacer(minLength: 8)
            // Three ways in: the camp itself first, then the sing-along and the museum beneath it.
            VStack(alignment: .trailing, spacing: compact ? 6 : 12) {
                Button(action: tapped { model.route = .home }) { IconLabel("Visit camp", emoji: "🏕", size: compact ? 18 : 24) }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 18 : 24))
                HStack(spacing: compact ? 6 : 12) {
                    Button(action: tapped { model.route = .songShelf }) { IconLabel("Sing-Along", emoji: "🎵", size: compact ? 15 : 20) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: compact ? 15 : 20))
                        .accessibilityIdentifier("sing-along")
                    Button(action: tapped { model.route = .museum }) { IconLabel("Museum", emoji: "🦴", size: compact ? 15 : 20) }
                        .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 15 : 20))
                }
                // The optional speed games: the Raptor Race once the Dial is back, and Times Tables
                // Check practice when a grown-up has switched it on.
                let race = QuickFireRound.raceUnlocked(profile), check = profile.parent.mtcPractice
                if race || check {
                    HStack(spacing: compact ? 6 : 12) {
                        if race {
                            Button(action: tapped { model.route = .quickFire(.raptorRace) }) { IconLabel("Raptor Race", emoji: "🏁", size: compact ? 15 : 20) }
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.coral, ink: .white, size: compact ? 15 : 20))
                                .accessibilityIdentifier("raptor-race")
                        }
                        if check {
                            Button(action: tapped { model.route = .quickFire(.mtc) }) { IconLabel("Times Check", symbol: "stopwatch.fill", size: compact ? 15 : 20) }
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 15 : 20))
                                .accessibilityLabel("Times Tables Check practice")
                                .accessibilityIdentifier("times-check")
                        }
                    }
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 8 : 14)
        .panel()
        .frame(maxWidth: 780)
        .padding(.horizontal, 16)
    }

    private func card(_ island: Island, profile: Profile, compact: Bool) -> some View {
        let unlocked = Progression.isUnlocked(island: island, in: profile, catalog: model.catalog)
        let stars = island.levels.reduce(0) { $0 + profile.stars(for: $1.id) }
        let index = model.catalog.islands.firstIndex { $0.id == island.id } ?? 0
        return HStack(spacing: compact ? 12 : 20) {
            Image("island_\(island.id)").resizable().scaledToFit().frame(height: compact ? 64 : 100).saturation(unlocked && island.ready ? 1 : 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(island.name).font(.game(compact ? 22 : 30)).foregroundStyle(Palette.ink)
                HStack(spacing: 4) {
                    if !island.ready {
                        Text("Coming soon in the next update!")
                    } else if unlocked {
                        Text("\(Self.tablesText(ZonePlan.focus(zone: index, settings: profile.parent)))  ·")
                        Glyph("⭐️", size: compact ? 18 : 22)
                        Text("\(stars)/15")
                        if profile.crystals.contains(island.id) {
                            Text(" ·")
                            Glyph("⚙️", size: compact ? 18 : 22)
                            Text(island.partName)
                        }
                    } else {
                        Text("Win back the \(model.catalog.islands[max(index - 1, 0)].partName) first")
                    }
                }
                RoarRating(level: island.roar, size: compact ? 14 : 18)
                    .font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
            }
            Spacer(minLength: 8)
            if unlocked && island.ready {
                Button(action: tapped { model.route = .island(island.id) }) { IconLabel("Explore", symbol: "play.fill", size: compact ? 20 : 26, trailing: true) }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26))
            } else {
                Glyph("🔒", size: compact ? 42 : 58)
            }
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 8 : 14)
        .panel()
        .frame(maxWidth: 780)
        .padding(.horizontal, 16)
    }
}

/// How fierce a zone's boss is: footprints from 1 to 5, and "MAX" for the T-Rex.
struct RoarRating: View {
    let level: Int
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 3) {
            Text("Roar rating").font(.game(size, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
            if level >= 6 {
                Text("MAX").font(.game(size, weight: .black)).foregroundStyle(Palette.coral)
            } else {
                ForEach(0..<5, id: \.self) { index in
                    Glyph("🐾", size: size).opacity(index < level ? 1 : 0.22)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level >= 6 ? "Roar rating: maximum" : "Roar rating \(level) of 5")
    }
}

/// One zone's levels, laid out as a path. The scenery comes to life as levels are cleared.
struct IslandView: View {
    let island: Island
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let theme = IslandTheme.island(island.id)
            ZStack {
                VStack(spacing: compact ? 4 : 16) {
                    HStack {
                        RoundButton(symbol: "map.fill", label: "Crash Camp map") { model.route = .map }
                        Spacer()
                        VStack(spacing: 0) {
                            Text(island.name).font(.game(compact ? 26 : 40)).foregroundStyle(Palette.ink)
                            Text(island.tagline).font(.game(compact ? 13 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                        }
                        .padding(.horizontal, 22).padding(.vertical, 6).panel(radius: 20)
                        Spacer()
                        CountChip(emoji: "⭐️", text: "\(island.levels.reduce(0) { $0 + (model.profile?.stars(for: $1.id) ?? 0) })/15")
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .center, spacing: compact ? 6 : 16 * ScreenMetrics.scale(geometry)) {
                        ForEach(Array(island.levels.enumerated()), id: \.element.id) { index, level in
                            levelButton(level, index: index, theme: theme, compact: compact, scale: ScreenMetrics.scale(geometry))
                                .offset(y: index.isMultiple(of: 2) ? (compact ? 10 : 26) : (compact ? -10 : -26))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(compact ? 8 : 24)
            }
            .background {
                IslandScenery(art: theme.background, calmerMotion: model.settings.reducedMotion)
            }
            .environment(\.compact, compact)
        }
    }

    private func levelButton(_ level: LevelDef, index: Int, theme: IslandTheme, compact: Bool, scale: CGFloat) -> some View {
        let profile = model.profile
        let unlocked = island.ready && (profile.map { Progression.isUnlocked(levelID: level.id, in: $0, catalog: model.catalog) } ?? false)
        let stars = profile?.stars(for: level.id) ?? 0
        let isNext = unlocked && stars == 0
        let size: CGFloat = compact ? 74 : 118 * scale
        return Button(action: tapped { if unlocked { model.startLevel(level.id) } }) {
            VStack(spacing: compact ? 2 : 6) {
                ZStack {
                    Circle().fill(Palette.ink).offset(y: 5)
                    Circle().fill(unlocked ? Color(theme.tint.mixed(with: .white, amount: 0.55)) : Color.gray.opacity(0.85))
                    Circle().strokeBorder(isNext ? Palette.gold : Palette.ink, lineWidth: isNext ? 6 : 4)
                    if !unlocked {
                        Glyph("🔒", size: size * 0.5)
                    } else if level.mode == .guardian {
                        Image(stars > 0 ? theme.guardianHappy : theme.guardian).resizable().scaledToFit().padding(size * 0.1)
                    } else {
                        Glyph(icon(level.mode), size: size * 0.62)
                    }
                }
                .frame(width: size, height: size)
                .scaleEffect(isNext ? 1.08 : 1)
                StarRow(stars: stars, size: compact ? 14 : 20 * scale).opacity(unlocked ? 1 : 0.3)
                VStack(spacing: 0) {
                    Text(level.title).font(.game(compact ? 13 : 18 * scale)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
                    Text(level.blurb).font(.game(compact ? 10 : 13 * scale, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .frame(width: compact ? 130 : 196 * scale)
                .panel(fill: Palette.cream.opacity(unlocked ? 1 : 0.7), radius: 12)
            }
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel("\(level.title). \(unlocked ? "\(stars) stars" : "Locked")")
    }

    private func icon(_ mode: GameMode) -> String {
        switch mode {
        case .mathsSplash: "🌊"
        case .bridgeBuilder: "🪨"
        case .eggRescue: "🥚"
        case .guardian: "🦖"
        case .dinoDash: "🏃"
        case .tiptoe: "🤫"
        case .skySnatch: "☁️"
        }
    }
}
