import XCTest
@testable import PokeTokenBar

/// Players who hatch by the app's own draw and send off what brings them nothing: a group's luck must average out.
final class HatchLuckSimulationTests: XCTestCase {
    private static let start = Date(timeIntervalSince1970: 1_793_534_400)   // 2026-11-01 12:00 UTC

    private let index = [16, 10, 13, 19, 21, 23, 29, 32].map { BaseSpecies(id: $0, captureRate: 255) }
        + [BaseSpecies(id: 83, captureRate: 255)]
        + [58, 37, 77].map { BaseSpecies(id: $0, captureRate: 90) }
        + [147, 246].map { BaseSpecies(id: $0, captureRate: 45) }
        + [243, 244].map { BaseSpecies(id: $0, captureRate: 3, isUnbreedableLegendary: true) }

    private func egg(_ rng: inout SeededRNG) -> HatchEgg {
        switch Int.random(in: 0..<20, using: &rng) {
        case 0: return .legendary
        case 1: return .tier(.rare)
        case 2, 3: return .tier(.uncommon)
        default: return .tier(nil)
        }
    }

    private func chance(_ odds: Double, _ rng: inout SeededRNG) -> Bool { Double.random(in: 0..<1, using: &rng) < odds }

    /// One player's Pokédex, the last hatch still being raised before its first evolution.
    private func play(hatches: Int, _ rng: inout SeededRNG) -> [DexEntry] {
        var collection = CompanionState()
        var entries: [DexEntry] = []
        for i in 0..<hatches {
            let at = Self.start.addingTimeInterval(Double(i) * 86_400)
            let draw = HatchDraw(collection: collection, items: [], rules: HatchRules(rolledAt: at, firstHatch: Self.start))
            let egg = egg(&rng)
            let outcomes = draw.outcomes(egg, index: index)
            var left = Double.random(in: 0..<outcomes.reduce(0) { $0 + $1.weight }, using: &rng)
            var pick = outcomes[outcomes.count - 1]
            for outcome in outcomes {
                left -= outcome.weight
                if left < 0 { pick = outcome; break }
            }
            let isDisguise = pick.rarity == .common && PokemonEvolutionData.stageCount(from: pick.id) >= 2
                && draw.letsDittoHide(baseID: pick.id, egg: egg.spec ?? .init(), fromFossilEgg: false)
                && chance(1 / Double(PokemonOdds.dittoDisguiseDenominator), &rng)
            let isRaised = i == hatches - 1
            let sentOffEarly = !isRaised && chance(draw.bringsNew()(pick.id, pick.form) ? 0.05 : 0.8, &rng)
            var entry: DexEntry
            if isDisguise && !sentOffEarly && !isRaised {
                let ditto = PokemonOdds.dittoSpeciesID
                entry = DexEntry(baseID: ditto, finalID: ditto, chainOrder: [ditto], rarity: .common, caughtAt: at)
                entry.hatch = HatchRecord(egg: egg, rolledBaseID: pick.id)
            } else {
                var path = [pick.id]
                while !sentOffEarly, !isRaised,
                      let next = PokemonEvolutionData.children(of: path.last!, form: pick.form)
                          .filter({ !path.contains($0) }).randomElement(using: &rng) {
                    path.append(next)
                }
                entry = DexEntry(baseID: pick.id, finalID: path.last!, chainOrder: path, rarity: pick.rarity, caughtAt: at,
                                 form: pick.form)
                entry.hatch = HatchRecord(egg: egg)
            }
            entry.isShiny = chance(pick.alwaysShiny ? 1 : draw.shinyChance, &rng)
            if sentOffEarly { entry.releasedAt = at }
            collection.lastHatchedBaseID = entry.hatch?.rolledBaseID ?? entry.baseID
            if !entry.isReleased { collection.collectedFinals.insert("\(entry.baseID):\(entry.finalID)") }
            collection.dex.append(entry)
            entries.append(entry)
        }
        return entries
    }

    func testEveryCriterionStaysCentred() {
        let players = 200, hatches = 60
        var rng = SeededRNG(seed: 7)
        var hits: [HatchLuck.Criterion: Double] = [:], expected = hits, variance = hits, percentile = hits
        for _ in 0..<players {
            let luck = HatchLuck(entries: play(hatches: hatches, &rng), includesActive: true, today: CompanionState(),
                                 index: index, now: Self.start.addingTimeInterval(Double(hatches) * 86_400))
            for result in luck.criteria { percentile[result.criterion, default: 0] += result.percentile }
            for hatch in luck.hatches {
                for (criterion, judgement) in hatch.judged {
                    hits[criterion, default: 0] += judgement.hit ? 1 : 0
                    expected[criterion, default: 0] += judgement.odds
                    variance[criterion, default: 0] += judgement.odds * (1 - judgement.odds)
                }
            }
        }
        for criterion in HatchLuck.Criterion.allCases {
            let (h, e, v) = (hits[criterion] ?? 0, expected[criterion] ?? 0, variance[criterion] ?? 0)
            XCTAssertLessThan(abs(h - e) / v.squareRoot(), 3.5, "\(criterion): \(h) for \(e) expected")
            XCTAssertEqual((percentile[criterion] ?? 0) / Double(players), 0.5, accuracy: 0.08, "\(criterion)")
        }
    }
}
