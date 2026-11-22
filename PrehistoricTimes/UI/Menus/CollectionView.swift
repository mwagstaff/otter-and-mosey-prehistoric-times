import PrehistoricTimesCore
import SwiftUI

/// Everything the player has collected: machine parts, the Dino Nursery, hats and Dino Fact cards.
/// Trophies have their own cabinet.
struct CollectionView: View {
    @Environment(AppModel.self) private var model
    @State private var tab = 0
    @State private var showingPhoto = false
    @State private var openFact: String?
    private let tabs = [("⚙️", "Parts"), ("🥚", "Nursery"), ("🎩", "Hats"), ("🦖", "Facts")]

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                VStack(spacing: compact ? 6 : 14) {
                    HStack(spacing: 8) {
                        RoundButton(symbol: "chevron.left", label: "Back to map") { model.route = .map }
                        Spacer()
                        ForEach(tabs.indices, id: \.self) { index in
                            Button(action: tapped { tab = index }) { IconLabel(tabs[index].1, emoji: tabs[index].0, size: compact ? 15 : 20) }
                                .buttonStyle(ChunkyButtonStyle(fill: tab == index ? Palette.gold : Palette.cream, size: compact ? 15 : 20))
                        }
                        Spacer()
                    }
                    ScrollView {
                        content(compact: compact).padding(compact ? 10 : 20)
                    }
                    .panel(fill: Palette.cream.opacity(0.96))
                }
                .padding(compact ? 8 : 24)
                if showingPhoto { GroupPhotoViewer { showingPhoto = false } }
                if let openFact { DinoFactViewer(levelID: openFact) { self.openFact = nil }.transition(.opacity) }
            }
            .animation(.easeInOut(duration: 0.2), value: openFact)
            .screenBackground("bg_camp", blur: 8, dim: 0.4)
            .environment(\.compact, compact)
        }
    }

    @ViewBuilder private func content(compact: Bool) -> some View {
        let profile = model.profile
        let columns = [GridItem(.adaptive(minimum: compact ? 130 : 170), spacing: 12)]
        switch tab {
        case 0:
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.catalog.islands) { island in
                    let found = profile?.crystals.contains(island.id) ?? false
                    tile(compact: compact, title: island.partName, subtitle: found ? "Won back from \(island.guardian.name)!" : "Still missing…", earned: found) {
                        Image("part_\(island.part)").resizable().scaledToFit().saturation(found ? 1 : 0).opacity(found ? 1 : 0.35)
                    }
                }
                // The group photo from the finale, once every part is back. Tapping it plays the ending again.
                if let profile, profile.crystals.count == model.catalog.islands.count {
                    Button(action: tapped { showingPhoto = true }) {
                        tile(compact: compact, title: "Group photo", subtitle: "Tap to look at it", earned: true) {
                            Image("bg_ending").resizable().aspectRatio(1.5, contentMode: .fill)
                                .frame(width: compact ? 66 : 96, height: compact ? 44 : 64).clipped()
                                .padding(3).padding(.bottom, 4).background(.white)
                                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                                .rotationEffect(.degrees(-3))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        case 1:
            VStack(alignment: .leading, spacing: 10) {
                let pets = model.catalog.rewards.filter { $0.kind == .pet }
                Text("The Dino Nursery: \(pets.filter { profile?.has($0.id) == true }.count) of \(pets.count) baby dinosaurs. They play at Crash Camp!")
                    .font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                rewardGrid(.pet, columns: columns, compact: compact)
            }
        case 2: rewardGrid(.accessory, columns: columns, compact: compact)
        default: DinoFactShelf(compact: compact, open: $openFact)
        }
    }

    private func rewardGrid(_ kind: RewardKind, columns: [GridItem], compact: Bool) -> some View {
        let profile = model.profile
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(model.catalog.rewards.filter { $0.kind == kind }) { reward in
                let owned = profile?.has(reward.id) ?? false
                let worn = profile?.equippedAccessory == reward.id
                Button(action: tapped {
                    guard owned, kind == .accessory else { return }
                    model.update { $0.wear(worn ? nil : reward.id) }
                }) {
                    tile(compact: compact, title: owned ? reward.name : "???",
                         subtitle: !owned ? "Keep exploring to find it" : (kind == .accessory ? (worn ? "Both wearing it! Tap to take off" : "Tap for both to wear") : "Hatched and happy"),
                         earned: owned, highlight: worn) {
                        Glyph(reward.emoji, size: compact ? 50 : 70, art: reward.art).saturation(owned ? 1 : 0).opacity(owned ? 1 : 0.25)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tile<Icon: View>(compact: Bool, title: String, subtitle: String, earned: Bool, highlight: Bool = false, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: 4) {
            icon().frame(height: compact ? 50 : 70)
            Text(title).font(.game(compact ? 14 : 18)).foregroundStyle(Palette.ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
            Text(subtitle).font(.game(compact ? 11 : 13, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.6)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: compact ? 118 : 160)
        .background(RoundedRectangle(cornerRadius: 16).fill(highlight ? Palette.gold.opacity(0.6) : (earned ? .white : .white.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.ink.opacity(earned ? 1 : 0.3), lineWidth: 3)))
    }
}

/// The home island, which the player decorates with things earned on the adventure.
struct HomeIslandView: View {
    @Environment(AppModel.self) private var model
    @State private var dragging: UUID?
    /// The last quick tap on a decoration, so a second one soon after puts it away.
    @State private var lastTap: (id: UUID, time: Date)?

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let itemSize: CGFloat = compact ? 54 : 84 * ScreenMetrics.scale(geometry)
            let insets = geometry.safeAreaInsets
            let paintingFrame = CGRect(x: -insets.leading, y: -insets.top,
                width: geometry.size.width + insets.leading + insets.trailing,
                height: geometry.size.height + insets.top + insets.bottom)
            let ground = CampGround(paintingFrame: paintingFrame, viewport: paintingFrame,
                decorations: (model.profile?.decorations ?? []).map {
                    CGPoint(x: $0.x * geometry.size.width, y: $0.y * geometry.size.height)
                }, propSize: itemSize * 1.25)
            ZStack {
                // Stagger the rescued pets across the near and far sides of the clearing.
                ForEach(Array(pets.enumerated()), id: \.element.id) { index, pet in
                    let columns = pets.count <= 4 ? pets.count : (pets.count + 1) / 2
                    let column = pets.count <= 4 ? index : index / 2
                    let x = CGFloat(column) / CGFloat(max(columns - 1, 1))
                    let start = ground.screen(CGPoint(x: 309 + 337 * x,
                                                      y: index.isMultiple(of: 2) ? 437 : 495))
                    CampPet(pet: pet, index: index, size: geometry.size, iconSize: itemSize * 0.85, ground: ground,
                            home: model.profile?.campPetSpots[pet.id] ?? CampSpot(
                                x: start.x / geometry.size.width, y: start.y / geometry.size.height),
                            calmer: model.settings.reducedMotion) { spot in
                        model.update { $0.campPetSpots[pet.id] = spot }
                    }

                }
                ForEach(model.profile?.decorations ?? []) { placed in
                    if let reward = model.catalog.reward(placed.reward) {
                        Glyph(reward.emoji, size: itemSize * 1.25, art: reward.art)
                            .scaleEffect(dragging == placed.id ? 1.2 : 1)
                            // One gesture does both, because a drag that starts on touch-down swallows the
                            // taps a separate double-tap would need: a real drag moves the decoration,
                            // and two quick taps that barely move put it away.
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("campGround"))
                                .onChanged { value in
                                    guard hypot(value.translation.width, value.translation.height) > 6 else { return }
                                    dragging = placed.id
                                    move(placed.id, to: value.location, in: geometry.size, persist: false)
                                }
                                .onEnded { value in
                                    dragging = nil
                                    guard hypot(value.translation.width, value.translation.height) > 6 else {
                                        tap(placed.id)
                                        return
                                    }
                                    move(placed.id, to: value.location, in: geometry.size, persist: true)
                                })
                            .position(x: placed.x * geometry.size.width, y: placed.y * geometry.size.height)
                            .zIndex(placed.y + itemSize * 1.25 * 0.46 / geometry.size.height)
                    }
                }
                // The trophy cabinet stands at the camp too.
                Button(action: tapped { model.openTrophies() }) {
                    VStack(spacing: 2) {
                        Image("trophy_cabinet").resizable().scaledToFit().frame(height: itemSize * 2)
                        Text("Trophies").font(.game(compact ? 12 : 16)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 10).padding(.vertical, 2).panel(radius: 10)
                    }
                }
                .buttonStyle(.plain)
                .position(x: geometry.size.width * 0.88, y: geometry.size.height * 0.4)
                .accessibilityLabel("Trophy cabinet")
                .zIndex(2)
                // The campfire band, the way into the Campfire Sing-Along, stands on the dirt by the
                // fire. Pets walk round it and pass in front of or behind it by depth.
                let bandFoot = ground.screen(CampGround.bandBase)
                let bandSize = CampGround.bandHeight * ground.scale
                Button(action: tapped { model.route = .songShelf }) {
                    Image("camp_band").resizable().scaledToFit().frame(width: bandSize, height: bandSize)
                        .overlay(alignment: .bottom) {
                            IconLabel("Sing-Along", emoji: "🎵", size: compact ? 12 : 17).font(.game(compact ? 12 : 17)).foregroundStyle(Palette.ink)
                                .padding(.horizontal, 10).padding(.vertical, 3).panel(fill: Palette.gold, radius: 12)
                                .fixedSize()
                                .offset(y: bandSize * 0.06)
                        }
                }
                .buttonStyle(.plain)
                // The picture's grass ends about 85% of the way down, which is where it meets the ground.
                .position(x: bandFoot.x, y: bandFoot.y - bandSize * 0.35)
                .accessibilityLabel("Sing-Along")
                .zIndex(Double(bandFoot.y / max(geometry.size.height, 1)))
                VStack {
                    // Everything sits along the top, so the ground is free for decorations.
                    HStack(alignment: .top, spacing: 10) {
                        RoundButton(symbol: "chevron.left", label: "Back to map") { model.route = .map }
                        VStack(spacing: 2) {
                            Text("Crash Camp").font(.game(compact ? 22 : 32)).foregroundStyle(Palette.ink)
                            Text("Tap to add. Drag to move. Double-tap to put away.")
                                .font(.game(compact ? 11 : 14, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6).panel(radius: 18)
                        .fixedSize()
                        Spacer(minLength: 0)
                    }
                    // The decorations in a row of their own, scrolling sideways when there are lots.
                    HStack {
                        Spacer(minLength: 0)
                        ScrollView(.horizontal, showsIndicators: false) { decorationTray(compact: compact) }
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: geometry.size.width * 0.8)
                    }
                    Spacer()
                }
                .padding(compact ? 8 : 24)
                .zIndex(3)
            }
            .coordinateSpace(name: "campGround")
            .background {
                CampBackdrop(calmerMotion: model.settings.reducedMotion, ground: ground)
                    .ignoresSafeArea().accessibilityHidden(true)
            }
        }
    }

    /// The decorations earned so far, ready to add.
    private func decorationTray(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 10) {
                        ForEach(decorations) { reward in
                            Button(action: tapped { add(reward) }) {
                                Glyph(reward.emoji, size: compact ? 38 : 52, art: reward.art)
                                    .frame(width: compact ? 52 : 68, height: compact ? 52 : 68)
                                    .background(Circle().fill(.white).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(reward.name)")
                        }
        }
        .padding(.horizontal, compact ? 8 : 14).padding(.vertical, compact ? 6 : 8)
        .panel(fill: Palette.cream.opacity(0.95))
    }

    private var pets: [Reward] {
        model.catalog.rewards.filter { $0.kind == .pet && (model.profile?.has($0.id) ?? false) }
    }

    private var decorations: [Reward] {
        model.catalog.rewards.filter { $0.kind == .decoration && (model.profile?.has($0.id) ?? false) }
    }

    private func add(_ reward: Reward) {
        model.update { profile in
            guard profile.decorations.count < 24 else { return }
            profile.decorations.append(PlacedDecoration(reward: reward.id, x: .random(in: 0.25...0.75), y: .random(in: 0.65...0.88)))
        }
        AudioManager.shared.play(.pop, volume: 0.6)
    }

    /// A second quick tap on the same decoration puts it away.
    private func tap(_ id: UUID) {
        if let last = lastTap, last.id == id, Date().timeIntervalSince(last.time) < 0.45 {
            lastTap = nil
            model.update { $0.decorations.removeAll { $0.id == id } }
            AudioManager.shared.play(.pop, volume: 0.5)
        } else {
            lastTap = (id, Date())
        }
    }

    private func move(_ id: UUID, to point: CGPoint, in size: CGSize, persist: Bool) {
        let x = min(max(point.x / size.width, 0.04), 0.96), y = min(max(point.y / size.height, 0.22), 0.94)
        model.update { profile in
            guard let index = profile.decorations.firstIndex(where: { $0.id == id }) else { return }
            profile.decorations[index].x = x
            profile.decorations[index].y = y
        }
    }
}

/// A rescued pet wanders near its chosen home. Only an intentional drop writes the save.
private struct CampPet: View {
    let pet: Reward
    let index: Int
    let size: CGSize
    let iconSize: CGFloat
    let ground: CampGround
    let home: CampSpot
    let calmer: Bool
    let place: (CampSpot) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduced
    @Environment(\.scenePhase) private var phase
    @State private var walk: CampWalk?
    @State private var resting: CGPoint?
    @State private var departed = Date()
    @State private var speed: CGFloat = 14
    @State private var facingLeft = false
    @State private var looking = false
    @State private var greetingUntil = Date.distantPast
    @State private var dragOrigin: CGPoint?
    @State private var depth: Double = 0
    @GestureState private var translation = CGSize.zero

    private var call: (String, SFX) {
        switch pet.id {
        case "pet-pip", "pet-chomp", "pet-nubbin", "pet-spike", "pet-stretch", "pet-bonk", "pet-clubby", "pet-dot": ("Raar!", .roarMaia)
        case "pet-paddle": ("Glub glub!", .glub)
        case "pet-flap", "pet-feather": ("Squawk!", .chirp)
        case "pet-scoot": ("Cluck cluck!", .chirp)
        default: ("Chirp!", .chirp)
        }
    }

    private var walkArt: String? {
        switch pet.id {
        case "pet-pip", "pet-nubbin", "pet-chomp": "camp_" + String(pet.id.dropFirst(4))
        default: nil
        }
    }

    private var area: CampWalkingArea {
        ground.walkingArea(width: iconSize / ground.scale, height: iconSize / ground.scale)
    }

    private func restingPoint(_ requested: CGPoint) -> CGPoint? {
        area.nearest(ground.painting(requested)).map(ground.screen)
    }

    private var spawn: CGPoint {
        ground.painting(CGPoint(x: size.width * home.x, y: size.height * home.y))
    }

    private func pose(at date: Date) -> (point: CGPoint, frame: Int, facingLeft: Bool)? {
        if let walk {
            let distance = max(0, date.timeIntervalSince(departed)) * speed
            let sample = walk.sample(distance)
            let stride = iconSize / ground.scale * (pet.id == "pet-nubbin" ? 0.43 : 0.58)
            return (ground.screen(sample.point), Int(distance / max(1, stride / 4)) % 4, sample.west)
        }
        return (resting ?? area.nearest(spawn)).map { (ground.screen($0), 1, facingLeft) }
    }

    private struct TravelInputs: Equatable {
        let ground: CampGround
        let home: CampSpot
        let suspended: Bool
        let diameter: CGFloat
        let greeting: Date
    }

    /// Plan once per outing or layout change. The animation clock only samples a route.
    private func explore() async {
        let map = area
        let here = pose(at: Date()).map { ground.painting($0.point) } ?? spawn
        resting = map.nearest(here)
        walk = nil
        looking = false
        guard phase == .active, !calmer, !reduced, dragOrigin == nil else { return }
        do {
            while let start = resting, !Task.isCancelled {
                try await Task.sleep(for: .seconds(Double.random(in: 0.6...2.4)))
                if Bool.random() {
                    looking = true
                    facingLeft.toggle()
                    try await Task.sleep(for: .seconds(Double.random(in: 0.6...1.5)))
                    looking = false
                }
                // Mix short investigations with occasional trips across the clearing.
                let x = Bool.random() ? start.x + .random(in: -100...100) : .random(in: map.bounds.minX...map.bounds.maxX)
                let wish = CGPoint(x: x,
                                   y: start.y + .random(in: -110...110))
                guard let end = map.nearest(wish), hypot(end.x - start.x, end.y - start.y) > 22,
                      let route = map.route(from: start, to: end) else { continue }
                speed = (pet.id == "pet-nubbin" ? 14 : 19) * .random(in: 0.85...1.2)
                departed = Date()
                walk = route
                try await Task.sleep(for: .seconds(route.length / speed))
                facingLeft = route.sample(route.length).west
                resting = end
                walk = nil
            }
        } catch { /* SwiftUI cancels the outing on drag, scene exit or a changed obstacle. */ }
    }

    private func greet() {
        AudioManager.shared.play(call.1, volume: 0.6)
        greetingUntil = Date().addingTimeInterval(1)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: phase != .active)) { clock in
            if let pose = pose(at: clock.date) {
                let roaming = pose.point
                let target = dragOrigin.map { CGPoint(x: $0.x + translation.width, y: $0.y + translation.height) }
                // Carry freely over scenery. Only the released position needs walkable ground.
                let centre = target ?? roaming
                let feet = (roaming.y + iconSize * 0.38) / size.height
                Group {
                    if let art = walkArt {
                        Image(art + "_" + String(target == nil ? pose.frame : 1))
                            .resizable().scaledToFit().frame(width: iconSize, height: iconSize)
                            .rotationEffect(.degrees(looking ? (pose.facingLeft ? -4 : 4) : 0), anchor: .bottom)
                                .scaleEffect(x: pose.facingLeft ? -1 : 1, y: 1)
                    } else {
                        Glyph(pet.emoji, size: iconSize, art: pet.art)
                    }
                }
                    .frame(width: max(44, iconSize), height: max(44, iconSize))
                    .contentShape(Rectangle())
                    .overlay(alignment: .top) {
                        if clock.date < greetingUntil {
                            Text(call.0).font(.caption.bold()).padding(4).background(.regularMaterial, in: Capsule())
                                .fixedSize().offset(y: -20).allowsHitTesting(false)
                        }
                    }
                    .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("campGround"))
                        .updating($translation) { drag, offset, _ in offset = drag.translation }
                        .onChanged { _ in if dragOrigin == nil { dragOrigin = roaming } }
                        .onEnded { drag in
                            let origin = dragOrigin ?? roaming
                            guard let drop = restingPoint(CGPoint(x: origin.x + drag.translation.width, y: origin.y + drag.translation.height)) else { dragOrigin = nil; return }
                            place(CampSpot(x: drop.x / size.width, y: drop.y / size.height))
                            walk = nil
                            resting = ground.painting(drop)
                            dragOrigin = nil
                        }
                        .exclusively(before: TapGesture().onEnded { greet() }))
                    .onChange(of: translation) { _, offset in if offset == .zero { dragOrigin = nil } }
                    .accessibilityLabel(pet.name)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { greet() }
                    .position(centre)
                    .onChange(of: feet, initial: true) { _, value in depth = value }
            }
        }
        .zIndex(dragOrigin == nil ? depth : 4)
        .task(id: TravelInputs(ground: ground, home: home,
                               suspended: phase != .active || calmer || reduced || dragOrigin != nil,
                               diameter: iconSize, greeting: greetingUntil)) { await explore() }
    }
}

/// Sound and accessibility options for the grown-ups area.
struct SettingsOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { model.showSettings = false }
                VStack(spacing: compact ? 6 : 14) {
                    HStack {
                        Text("Settings").font(.game(compact ? 26 : 36)).foregroundStyle(Palette.ink)
                        Spacer()
                        RoundButton(symbol: "xmark", size: 50, label: "Close") { model.showSettings = false }
                    }
                    ScrollView {
                        SettingsControls(compact: compact)
                    }
                }
                .padding(compact ? 14 : 28)
                .frame(maxWidth: 720, maxHeight: geometry.size.height * 0.94)
                .panel()
                .padding(10)
            }
        }
    }
}

/// The shared sound and accessibility controls, used by Settings and the parent area.
struct SettingsControls: View {
    var compact: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        let settings = Binding(get: { model.settings }, set: { model.settings = $0 })
        VStack(spacing: compact ? 6 : 12) {
            slider("Music", "music.note", value: settings.musicVolume)
            slider("Sounds", "bell.fill", value: settings.effectsVolume)
            slider("Roars", "pawprint.fill", value: settings.roarVolume, sample: .roarMaia)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 250 : 300), spacing: 10)], spacing: compact ? 6 : 10) {
                toggle("Mute everything", "speaker.slash.fill", settings.muted)
                toggle("Read questions aloud", "text.bubble.fill", settings.spokenInstructions)
                toggle("Character voices", "person.wave.2.fill", settings.characterVoices)
                toggle("Read every sum word for word", "waveform", settings.deviceVoice)
                toggle("Vibration", "iphone.radiowaves.left.and.right", settings.haptics)
                toggle("Calmer motion", "tortoise.fill", settings.reducedMotion)
                toggle("High contrast", "circle.lefthalf.filled", settings.highContrast)
                toggle("Easy-read text", "textformat.size", settings.easyReadFont)
            }
        }
    }

    private func slider(_ title: String, _ symbol: String, value: Binding<Double>, sample: SFX = .correct) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.game(compact ? 17 : 22)).foregroundStyle(Palette.ink).frame(width: compact ? 130 : 170, alignment: .leading)
            Slider(value: value, in: 0...1) { editing in
                if !editing { AudioManager.shared.play(sample) }
            }
            .accessibilityLabel(title)
            .tint(Palette.teal)
            .frame(minHeight: 44)
        }
    }

    private func toggle(_ title: String, _ symbol: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Label(title, systemImage: symbol).font(.game(compact ? 16 : 20, weight: .bold)).foregroundStyle(Palette.ink)
        }
        .tint(Palette.teal)
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.7)))
    }
}
