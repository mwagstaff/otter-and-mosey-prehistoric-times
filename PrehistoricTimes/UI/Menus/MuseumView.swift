import SwiftUI
import PrehistoricTimesCore

/// The Fossil Museum: one dinosaur skeleton for each times table. A bone goes in when its fact is
/// secure (right first time, three times running, on two different days) and turns gold when it is
/// fluent, so children can watch their times tables being learnt. Bones are never taken back.
struct MuseumView: View {
    @Environment(AppModel.self) private var model

    /// Which dinosaur's skeleton stands for each table.
    static let dinosaurs = [1: "Compsognathus", 2: "Pteranodon", 3: "Triceratops", 4: "Stegosaurus", 5: "Ankylosaurus",
                            6: "Parasaurolophus", 7: "Brachiosaurus", 8: "Spinosaurus", 9: "Diplodocus", 10: "Velociraptor",
                            11: "Iguanodon", 12: "Tyrannosaurus rex"]

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let profile = model.profile
            let settings = profile?.parent ?? ParentSettings()
            let learner = profile?.learner ?? LearnerModel()
            let tables = ZonePlan.ordered(settings.usableTables)
            let others = ZonePlan.ordered(ParentSettings.allTables.filter { !tables.contains($0) })
            VStack(spacing: compact ? 6 : 12) {
                HStack {
                    RoundButton(symbol: "map.fill", label: "Crash Camp map") { model.route = .map }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("Fossil Museum").font(.game(compact ? 24 : 38)).foregroundStyle(Palette.ink)
                        Text(summary(tables: tables, learner: learner, multipliers: settings.usableMultipliers))
                            .font(.game(compact ? 13 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                    }
                    .padding(.horizontal, 22).padding(.vertical, 6).panel(radius: 20)
                    Spacer()
                    Glyph("🦴", size: compact ? 34 : 50).accessibilityHidden(true)
                }
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 250 : 330), spacing: compact ? 10 : 16)], spacing: compact ? 10 : 16) {
                        ForEach(tables, id: \.self) { table in
                            SkeletonCard(table: table, learner: learner, multipliers: settings.usableMultipliers, compact: compact)
                        }
                        ForEach(others, id: \.self) { table in
                            SkeletonCard(table: table, learner: learner, multipliers: settings.usableMultipliers, compact: compact, inStore: true)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(compact ? 8 : 24)
            .screenBackground("bg_camp", blur: 6, dim: 0.15)
            .environment(\.compact, compact)
        }
    }

    private func summary(tables: [Int], learner: LearnerModel, multipliers: [Int]) -> String {
        let placed = tables.reduce(0) { $0 + Fossils.placed(table: $1, learner: learner, multipliers: multipliers) }
        let needed = tables.reduce(0) { $0 + Fossils.needed(table: $1, multipliers: multipliers).count }
        return "\(placed) of \(needed) bones found"
    }
}

/// One skeleton: revealed left to right as its bones go in, with a bone for each fact underneath.
struct SkeletonCard: View {
    let table: Int
    let learner: LearnerModel
    let multipliers: [Int]
    let compact: Bool
    /// A table the grown-up hasn't switched on: shown as a teaser, still in the museum's stores.
    var inStore = false

    var body: some View {
        let bones = Fossils.bones(table: table, learner: learner)
        let needed = Set(Fossils.needed(table: table, multipliers: multipliers))
        let placed = bones.filter { needed.contains($0.fact.multiplier) && $0.placed }.count
        let gold = bones.filter { needed.contains($0.fact.multiplier) && $0.gold }.count
        let fraction = inStore ? 0 : CGFloat(placed) / CGFloat(max(needed.count, 1))
        let complete = !inStore && placed == needed.count
        VStack(spacing: compact ? 4 : 8) {
            HStack {
                Text("×\(table)").font(.game(compact ? 22 : 30, weight: .black)).foregroundStyle(Palette.ink)
                Text(MuseumView.dinosaurs[table] ?? "").font(.game(compact ? 15 : 20, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.75))
                Spacer()
                if complete { Glyph("🏆", size: compact ? 22 : 30) }
            }
            ZStack {
                Image("fossil_\(table)").resizable().scaledToFit().saturation(0).opacity(0.18)
                Image("fossil_\(table)").resizable().scaledToFit()
                    .mask(alignment: .leading) {
                        GeometryReader { box in Rectangle().frame(width: box.size.width * fraction) }
                    }
            }
            .frame(height: compact ? 90 : 140)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 6), spacing: 4) {
                ForEach(bones, id: \.fact.multiplier) { bone in
                    let counts = needed.contains(bone.fact.multiplier)
                    VStack(spacing: 0) {
                        Image("bone").resizable().scaledToFit()
                            .colorMultiply(bone.gold ? Color(red: 1, green: 0.8, blue: 0.25) : .white)
                            .saturation(bone.placed ? 1 : 0)
                            .opacity(inStore ? 0.15 : (bone.placed ? 1 : (counts ? 0.25 : 0.1)))
                            .frame(height: compact ? 18 : 26)
                        Text("×\(bone.fact.multiplier)").font(.game(compact ? 10 : 13, weight: .bold))
                            .foregroundStyle(Palette.ink.opacity(counts ? 0.8 : 0.3))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(bone.fact.multiplier) times \(table): \(bone.gold ? "gold bone" : bone.placed ? "bone found" : "not yet")")
                }
            }
            Text(inStore ? "Ask a grown-up to switch on the \(table)s!"
                 : complete ? "Complete! Every bone is in." : "\(placed) of \(needed.count) bones\(gold > 0 ? " · \(gold) gold" : "")")
                .font(.game(compact ? 12 : 15, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
        }
        .padding(compact ? 10 : 14)
        .panel(fill: complete ? Palette.gold.opacity(0.35) : Palette.cream.opacity(inStore ? 0.6 : 0.95), radius: 18)
        .opacity(inStore ? 0.75 : 1)
    }
}
