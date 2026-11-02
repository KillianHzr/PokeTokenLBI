import Foundation

/// The looped real-time battle (validated 2026-10-30): each Pokémon casts its moves in order, then again, each cast
/// lasting by the move and the caster's speed; both sides run on one clock, in milliseconds. Pure and deterministic:
/// it knows two sides and a seed, nothing of dungeons or saves, so a replay is a rerun, and battles against players or
/// trainers will only be other setups.
enum BattleEngine {
    static func run(_ setup: BattleSetup) -> BattleOutcome {
        var simulation = BattleSimulation(setup)
        return simulation.run()
    }
}

/// One battle being played. Every list is walked in a fixed order, so the same seed always gives the same battle.
struct BattleSimulation {
    struct Battler {
        let spec: BattlerSpec
        let side: Int
        var hp: Int
        var slot: Int?
        var types: [PokemonType]
        var stages: [BattleStat: Int] = [:]
        /// burn, poison, badPoison, paralysis, sleep or freeze.
        var status: BattleAilment?
        var toxicCount = 0
        var wakeAt = 0
        var confusedUntil = 0
        var trapUntil = 0
        var trappedBy: Int?
        var seededBy: Int?
        var yawnAt: Int?
        var moveIndex = 0
        var castMove: String?
        var castTarget: Int?
        var castEnds = 0
        var protectedUntil = 0
        var destinyBond = false
        var flashFire = false
        var loafing = false
        var ateBerry = false
        var slowStartUntil = 0

        var maxHP: Int { spec.stats.hp }
        var isFainted: Bool { hp <= 0 }
        var ability: String { spec.ability ?? "" }
        func stage(_ stat: BattleStat) -> Int { stages[stat] ?? 0 }
    }

    private let setup: BattleSetup
    private var battlers: [Battler] = []
    /// The battler standing in each slot of each side.
    private var field: [[Int?]] = []
    private var pendingEntries: [(time: Int, side: Int, slot: Int)] = []
    private var wishes: [(time: Int, side: Int, slot: Int, amount: Int)] = []
    private var berries: [[BattleBerry: Int]]
    private var weather: BattleWeather?
    private var weatherUntil = 0
    private var terrain: BattleTerrain?
    private var terrainUntil = 0
    private var now = 0
    private var random: BattleRandom
    private var events: [TimedBattleEvent] = []
    private var nextResidual = BattleRules.residualTick
    private var nextThaw = BattleRules.thawTick
    private var winner: Int?

    init(_ setup: BattleSetup) {
        self.setup = setup
        random = BattleRandom(seed: setup.seed)
        berries = setup.sides.map(\.berries)
        for (side, spec) in setup.sides.enumerated() {
            for battler in spec.battlers {
                battlers.append(Battler(spec: battler, side: side, hp: min(battler.hp, battler.stats.hp), types: battler.types))
            }
            field.append(Array(repeating: nil, count: max(1, spec.active)))
        }
    }

    // MARK: The clock

    mutating func run() -> BattleOutcome {
        enterStartingLineups()
        checkVictory()
        while winner == nil {
            guard let next = nextTime(), next <= BattleRules.timeLimit else {
                now = max(now, BattleRules.timeLimit)
                winner = winnerOnHP()
                break
            }
            now = next
            step()
            checkVictory()
        }
        let won = winner ?? 1
        log(.end(winner: won))
        var hpLeft: [String: Int] = [:]
        for battler in battlers { hpLeft[battler.spec.id] = max(0, battler.hp) }
        return BattleOutcome(setup: setup, winner: won, duration: now, events: events, hpLeft: hpLeft,
                             berriesLeft: berries)
    }

    private func nextTime() -> Int? {
        var times: [Int] = pendingEntries.map(\.time) + wishes.map(\.time)
        if weather != nil { times.append(weatherUntil) }
        if terrain != nil { times.append(terrainUntil) }
        if active.contains(where: { battlers[$0].status != nil || battlers[$0].trappedBy != nil
            || battlers[$0].seededBy != nil || residualAbility(battlers[$0]) }) || weather == .sand {
            times.append(nextResidual)
        }
        if active.contains(where: { battlers[$0].status == .freeze }) { times.append(nextThaw) }
        for index in active {
            let b = battlers[index]
            if b.status == .sleep { times.append(b.wakeAt) }
            if let yawn = b.yawnAt { times.append(yawn) }
            if b.castMove != nil { times.append(b.castEnds) }
        }
        return times.filter { $0 >= now }.min()
    }

    private mutating func step() {
        if weather != nil, weatherUntil <= now {
            weather = nil
            log(.weather(nil))
        }
        if terrain != nil, terrainUntil <= now {
            terrain = nil
            log(.terrain(nil))
        }
        for entry in pendingEntries.filter({ $0.time <= now }).sorted(by: { ($0.side, $0.slot) < ($1.side, $1.slot) }) {
            pendingEntries.removeAll { $0.side == entry.side && $0.slot == entry.slot }
            sendIn(side: entry.side, slot: entry.slot)
        }
        for wish in wishes.filter({ $0.time <= now }) {
            wishes.removeAll { $0.time == wish.time && $0.side == wish.side && $0.slot == wish.slot }
            if let index = field[wish.side][wish.slot] { heal(index, wish.amount, .wish) }
        }
        for index in active {
            if battlers[index].status == .sleep, battlers[index].wakeAt <= now {
                cure(index)
                startCast(index)
            }
            if let yawn = battlers[index].yawnAt, yawn <= now {
                battlers[index].yawnAt = nil
                if battlers[index].status == nil { inflict(.sleep, on: index, by: nil) }
            }
        }
        if nextThaw <= now {
            nextThaw += BattleRules.thawTick
            for index in active where battlers[index].status == .freeze && random.below(5) == 0 {
                cure(index)
                startCast(index)
            }
        }
        if nextResidual <= now {
            nextResidual += BattleRules.residualTick
            residualTick()
        }
        let casting = active.filter { battlers[$0].castMove != nil && battlers[$0].castEnds <= now }
            .sorted { (battlers[$0].castEnds, battlers[$0].side, battlers[$0].slot ?? 0)
                < (battlers[$1].castEnds, battlers[$1].side, battlers[$1].slot ?? 0) }
        for index in casting where battlers[index].castMove != nil && !battlers[index].isFainted && winner == nil {
            completeCast(index)
            checkVictory()
        }
    }

    // MARK: Entering the field

    /// The battlers on the field, side 0 first, slot by slot.
    private var active: [Int] {
        field.flatMap { $0.compactMap { $0 } }.filter { !battlers[$0].isFainted }
    }

    private func foes(of index: Int) -> [Int] {
        let side = 1 - battlers[index].side
        return field[side].compactMap { $0 }.filter { !battlers[$0].isFainted }
    }

    private func allies(of index: Int) -> [Int] {
        field[battlers[index].side].compactMap { $0 }.filter { !battlers[$0].isFainted }
    }

    private func bench(_ side: Int) -> [Int] {
        battlers.indices.filter { battlers[$0].side == side && battlers[$0].slot == nil && !battlers[$0].isFainted }
    }

    private mutating func enterStartingLineups() {
        // The foes stand in their order; the player's side sends its best against each of them (R2, Q13).
        for side in field.indices.reversed() {
            for slot in field[side].indices {
                guard let pick = bestEntrant(side: side, slot: slot, ordered: side == 1) else { continue }
                place(pick, side: side, slot: slot)
            }
        }
        for index in active.sorted(by: { (-effectiveSpeed($0), $0) < (-effectiveSpeed($1), $1) }) {
            entryAbility(index)
        }
        for index in active { startCast(index) }
    }

    private mutating func sendIn(side: Int, slot: Int) {
        guard field[side][slot] == nil || battlers[field[side][slot]!].isFainted,
              let pick = bestEntrant(side: side, slot: slot, ordered: side == 1) else { return }
        place(pick, side: side, slot: slot)
        entryAbility(pick)
        startCast(pick)
    }

    private mutating func place(_ index: Int, side: Int, slot: Int) {
        field[side][slot] = index
        battlers[index].slot = slot
        log(.enter(side: side, slot: slot, battler: battlers[index].spec.id))
    }

    /// The bench's best against the foe in front of `slot`, or the next in order for a side that keeps its order.
    private func bestEntrant(side: Int, slot: Int, ordered: Bool) -> Int? {
        let candidates = bench(side)
        if ordered { return candidates.first }
        let opposite = field[1 - side]
        let foe = (slot < opposite.count ? opposite[slot] : nil).flatMap { battlers[$0].isFainted ? nil : $0 }
            ?? opposite.compactMap { $0 }.first { !battlers[$0].isFainted }
            ?? battlers.indices.first { battlers[$0].side == 1 - side && !battlers[$0].isFainted }
        guard let foe else { return candidates.first }
        return candidates.max { a, b in
            let sa = BattleMatchup.score(battlers[a].spec, against: battlers[foe].spec)
            let sb = BattleMatchup.score(battlers[b].spec, against: battlers[foe].spec)
            return sa != sb ? sa < sb : a > b
        }
    }

    private mutating func entryAbility(_ index: Int) {
        let b = battlers[index]
        switch b.ability {
        case "intimidate":
            log(.ability(battler: b.spec.id, ability: b.ability))
            for foe in foes(of: index) {
                if ["clear-body", "white-smoke", "full-metal-body", "hyper-cutter", "inner-focus", "oblivious",
                    "own-tempo", "scrappy"].contains(battlers[foe].ability) {
                    log(.ability(battler: battlers[foe].spec.id, ability: battlers[foe].ability))
                    continue
                }
                changeStage(foe, .attack, by: -1, fromFoe: true)
            }
        case "drizzle": setWeather(.rain, by: index)
        case "drought", "orichalcum-pulse": setWeather(.sun, by: index)
        case "sand-stream": setWeather(.sand, by: index)
        case "snow-warning": setWeather(.snow, by: index)
        case "electric-surge", "hadron-engine": setTerrain(.electric, by: index)
        case "grassy-surge": setTerrain(.grassy, by: index)
        case "misty-surge": setTerrain(.misty, by: index)
        case "psychic-surge": setTerrain(.psychic, by: index)
        case "download":
            let foes = foes(of: index)
            guard !foes.isEmpty else { return }
            let defense = foes.reduce(0) { $0 + battlers[$1].spec.stats.defense }
            let special = foes.reduce(0) { $0 + battlers[$1].spec.stats.specialDefense }
            log(.ability(battler: b.spec.id, ability: b.ability))
            changeStage(index, defense < special ? .attack : .specialAttack, by: 1, fromFoe: false)
        case "slow-start":
            battlers[index].slowStartUntil = now + 5 * BattleRules.residualTick
            log(.ability(battler: b.spec.id, ability: b.ability))
        default:
            break
        }
    }

    private mutating func setWeather(_ kind: BattleWeather, by index: Int?) {
        if let index { log(.ability(battler: battlers[index].spec.id, ability: battlers[index].ability)) }
        weather = kind
        weatherUntil = now + BattleRules.fieldDuration
        log(.weather(kind))
    }

    private mutating func setTerrain(_ kind: BattleTerrain, by index: Int?) {
        if let index { log(.ability(battler: battlers[index].spec.id, ability: battlers[index].ability)) }
        terrain = kind
        terrainUntil = now + BattleRules.fieldDuration
        log(.terrain(kind))
    }

    // MARK: Casting

    /// The next move of the loop starts, skipping at no cost those that would do nothing (R13); a Pokémon asleep or
    /// frozen starts nothing until it is free.
    private mutating func startCast(_ index: Int) {
        guard !battlers[index].isFainted, battlers[index].slot != nil, winner == nil else { return }
        guard battlers[index].status != .sleep, battlers[index].status != .freeze else {
            battlers[index].castMove = nil
            return
        }
        let loop = battlers[index].spec.moves
        var chosen: String?
        if battlers[index].loafing {
            chosen = "_loaf"
        } else {
            for offset in 0..<max(1, loop.count) where !loop.isEmpty {
                let slug = loop[(battlers[index].moveIndex + offset) % loop.count]
                if isUseful(slug, by: index) {
                    battlers[index].moveIndex = (battlers[index].moveIndex + offset) % loop.count
                    chosen = slug
                    break
                }
            }
        }
        let slug = chosen ?? "struggle"
        let move = MoveTable.move(slug)
        let target = move.flatMap { pickTarget(for: $0, by: index) }
        let base = move?.castBase ?? 1200
        var duration = Double(base) * 300 / (100 + Double(effectiveSpeed(index))) / Double(BattleRules.speedUp)
        if slug == "solar-beam" || slug == "solar-blade", weather == .sun {
            duration -= 2000 * 300 / (100 + Double(effectiveSpeed(index))) / Double(BattleRules.speedUp)
        }
        battlers[index].castMove = slug
        battlers[index].castTarget = target
        battlers[index].castEnds = now + max(100, Int(duration.rounded()))
        log(.cast(battler: battlers[index].spec.id, move: slug, target: target.map { battlers[$0].spec.id },
                  ends: battlers[index].castEnds))
    }

    private mutating func completeCast(_ index: Int) {
        guard let slug = battlers[index].castMove else { return }
        battlers[index].castMove = nil
        // Destiny Bond holds through the cast that follows it, to that cast's end.
        battlers[index].destinyBond = false
        if slug == "_loaf" {
            log(.fail(battler: battlers[index].spec.id, move: slug, reason: .truant))
            advance(index, after: slug)
            return
        }
        if battlers[index].status == .paralysis, random.below(4) == 0 {
            log(.fail(battler: battlers[index].spec.id, move: slug, reason: .paralysis))
            advance(index, after: slug)
            return
        }
        if battlers[index].confusedUntil > now {
            if random.below(3) == 0 {
                let damage = confusionDamage(index)
                log(.fail(battler: battlers[index].spec.id, move: slug, reason: .confusion))
                hurt(index, damage, .confusion)
                if !battlers[index].isFainted { advance(index, after: slug) }
                return
            }
        } else if battlers[index].confusedUntil > 0 {
            battlers[index].confusedUntil = 0
            log(.cure(battler: battlers[index].spec.id, ailment: .confusion))
        }
        if let move = MoveTable.move(slug) { use(move, by: index) }
        if !battlers[index].isFainted, battlers[index].slot != nil { advance(index, after: slug) }
    }

    /// The loop moves on, Truant resting every other cast, and the next cast starts.
    private mutating func advance(_ index: Int, after slug: String) {
        if !battlers[index].loafing, slug != "struggle" { battlers[index].moveIndex += 1 }
        battlers[index].loafing = battlers[index].ability == "truant" && slug != "_loaf"
        startCast(index)
    }

    // MARK: Moves

    /// Whether a move would do anything now: damaging moves while a foe stands, status moves whose effect still lands.
    private func isUseful(_ slug: String, by index: Int) -> Bool {
        guard let move = MoveTable.move(slug) else { return false }
        let b = battlers[index]
        let foes = foes(of: index)
        if move.isDamaging {
            if foes.isEmpty { return false }
            if slug == "dream-eater" { return foes.contains { battlers[$0].status == .sleep } }
            if ["explosion", "self-destruct", "misty-explosion", "final-gambit"].contains(slug) {
                return allies(of: index).count + bench(b.side).count > 1 || foes.count == 1
            }
            return true
        }
        switch slug {
        case "protect", "detect", "kings-shield", "spiky-shield", "baneful-bunker", "obstruct", "silk-trap",
             "burning-bulwark":
            return !foes.isEmpty
        case "destiny-bond": return !foes.isEmpty
        case "wish": return b.hp < b.maxHP && !wishes.contains { $0.side == b.side && $0.slot == b.slot }
        case "rest": return b.hp < b.maxHP && b.ability != "insomnia" && b.ability != "vital-spirit"
        case "belly-drum": return b.hp * 2 > b.maxHP && b.stage(.attack) < 6
        case "nightmare": return false
        case "sunny-day": return weather != .sun
        case "rain-dance": return weather != .rain
        case "sandstorm": return weather != .sand
        case "hail", "snowscape", "chilly-reception": return weather != .snow
        case "electric-terrain": return terrain != .electric
        case "grassy-terrain": return terrain != .grassy
        case "misty-terrain": return terrain != .misty
        case "psychic-terrain": return terrain != .psychic
        default: break
        }
        switch Self.statusKind(move) {
        case .heal:
            if move.targetsOwnSide && move.target == "user" { return b.hp < b.maxHP }
            return allies(of: index).contains { battlers[$0].hp < battlers[$0].maxHP }
        case .netGoodStats:
            if move.targetsOwnSide {
                return move.statChanges.contains { change in
                    let raised = b.ability == "contrary" ? -change.change : change.change
                    return raised > 0 ? b.stage(change.stat) < 6 : b.stage(change.stat) > -6
                }
            }
            return foes.contains { foe in move.statChanges.contains { battlers[foe].stage($0.stat) > -6 } }
        case .ailment, .swagger:
            guard let ailment = move.ailment else { return false }
            return foes.contains { canInflict(ailment, on: $0, move: move) }
        default:
            return false
        }
    }

    private func pickTarget(for move: BattleMove, by index: Int) -> Int? {
        if move.targetsOwnSide { return nil }
        let foes = foes(of: index)
        if move.hitsAllOpponents { return foes.first }
        if move.category == .heal { return nil }
        guard let slot = battlers[index].slot else { return foes.first }
        let opposite = field[1 - battlers[index].side]
        if slot < opposite.count, let facing = opposite[slot], !battlers[facing].isFainted { return facing }
        return foes.first
    }

    private mutating func use(_ move: BattleMove, by index: Int) {
        let id = battlers[index].spec.id
        // Field and self moves first: they need no foe in front.
        if let weatherKind = Self.weatherMoves[move.slug] {
            setWeather(weatherKind, by: nil)
            return
        }
        if let terrainKind = Self.terrainMoves[move.slug] {
            setTerrain(terrainKind, by: nil)
            return
        }
        switch move.slug {
        case "protect", "detect", "kings-shield", "spiky-shield", "baneful-bunker", "obstruct", "silk-trap",
             "burning-bulwark":
            battlers[index].protectedUntil = now + 1500
            return
        case "destiny-bond":
            battlers[index].destinyBond = true
            return
        case "wish":
            if let slot = battlers[index].slot {
                wishes.append((now + 2000, battlers[index].side, slot, battlers[index].maxHP / 2))
            }
            return
        case "rest":
            heal(index, battlers[index].maxHP, .move)
            battlers[index].status = nil
            battlers[index].status = .sleep
            battlers[index].wakeAt = now + 6000
            log(.status(battler: id, ailment: .sleep))
            return
        case "belly-drum":
            hurt(index, battlers[index].maxHP / 2, .belly)
            if !battlers[index].isFainted { changeStage(index, .attack, by: 12, fromFoe: false) }
            return
        default:
            break
        }
        if !move.isDamaging {
            useStatus(move, by: index)
            return
        }
        let targets: [Int]
        if move.hitsAllOpponents {
            targets = foes(of: index)
        } else if let target = battlers[index].castTarget, !battlers[target].isFainted, battlers[target].slot != nil {
            targets = [target]
        } else if let target = pickTarget(for: move, by: index) {
            targets = [target]
        } else {
            log(.fail(battler: id, move: move.slug, reason: .noTarget))
            return
        }
        let spread = targets.count > 1
        var dealtTotal = 0
        for target in targets where !battlers[target].isFainted && !battlers[index].isFainted {
            dealtTotal += strike(move, by: index, on: target, spread: spread)
        }
        if ["explosion", "self-destruct", "misty-explosion"].contains(move.slug) {
            hurt(index, battlers[index].hp, .recoil)
            return
        }
        guard !battlers[index].isFainted, dealtTotal > 0 else { return }
        if move.drain > 0 {
            let amount = max(1, dealtTotal * move.drain / 100)
            heal(index, amount, .drain)
        } else if move.drain < 0, battlers[index].ability != "rock-head", battlers[index].ability != "magic-guard" {
            hurt(index, max(1, dealtTotal * -move.drain / 100), .recoil)
        }
        if move.category == .damageRaise, !battlers[index].isFainted,
           random.chance(serene(index, move.statChance == 0 ? 100 : move.statChance)) {
            for change in move.statChanges { changeStage(index, change.stat, by: change.change, fromFoe: false) }
        }
    }

    /// One target's share of a damaging move: accuracy, immunity, hits, secondary effects. Returns the damage dealt.
    private mutating func strike(_ move: BattleMove, by index: Int, on target: Int, spread: Bool) -> Int {
        let attackerID = battlers[index].spec.id
        let targetID = battlers[target].spec.id
        if battlers[target].protectedUntil > now {
            log(.fail(battler: attackerID, move: move.slug, reason: .protected))
            return 0
        }
        if Self.ohkoMoves.contains(move.slug) {
            let a = battlers[index], d = battlers[target]
            if d.spec.isBoss || d.ability == "sturdy" || d.spec.level > a.spec.level
                || effectiveness(move, by: index, on: target) == 0 {
                log(.noEffect(attacker: attackerID, target: targetID, move: move.slug))
                return 0
            }
            guard random.below(100) < 30 + a.spec.level - d.spec.level else {
                log(.miss(attacker: attackerID, target: targetID, move: move.slug))
                return 0
            }
            let damage = battlers[target].hp
            dealDamage(damage, to: target, by: index, move: move, effectiveness: 1, critical: false)
            return damage
        }
        guard hits(move, by: index, on: target) else {
            log(.miss(attacker: attackerID, target: targetID, move: move.slug))
            return 0
        }
        if absorbs(move, by: index, target: target) { return 0 }
        let typeFactor = effectiveness(move, by: index, on: target)
        if typeFactor == 0 {
            log(.noEffect(attacker: attackerID, target: targetID, move: move.slug))
            return 0
        }
        var count = 1
        if move.maxHits > 1 {
            if battlers[index].ability == "skill-link" || move.minHits == move.maxHits {
                count = move.maxHits
            } else if move.minHits == 2, move.maxHits == 5 {
                count = [2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5][random.below(20)]
            } else {
                count = random.between(move.minHits, move.maxHits)
            }
        }
        var dealt = 0
        for _ in 0..<count where !battlers[target].isFainted {
            let critical = rollsCritical(move, by: index, on: target)
            let damage = damageFor(move, by: index, on: target, spread: spread, critical: critical, typeFactor: typeFactor)
            dealt += min(damage, battlers[target].hp)
            dealDamage(damage, to: target, by: index, move: move, effectiveness: typeFactor, critical: critical)
            if battlers[target].isFainted { break }
            contactEffects(move, attacker: index, target: target)
            if battlers[index].isFainted { return dealt }
        }
        if !battlers[target].isFainted { secondaryEffects(move, by: index, on: target) }
        return dealt
    }

    private mutating func useStatus(_ move: BattleMove, by index: Int) {
        let id = battlers[index].spec.id
        switch Self.statusKind(move) {
        case .heal:
            if move.target == "user" {
                heal(index, battlers[index].maxHP * healShare(move) / 100, .move)
            } else if move.target == "user-and-allies" || move.target == "all-allies" {
                for ally in allies(of: index) { heal(ally, battlers[ally].maxHP * move.healing / 100, .move) }
            } else if let ally = allies(of: index).filter({ $0 != index || allies(of: index).count == 1 })
                .min(by: { (battlers[$0].hp * 1000 / battlers[$0].maxHP, $0) < (battlers[$1].hp * 1000 / battlers[$1].maxHP, $1) }) {
                heal(ally, battlers[ally].maxHP * max(25, move.healing) / 100, .move)
            }
        case .netGoodStats:
            if move.targetsOwnSide {
                for change in move.statChanges { changeStage(index, change.stat, by: change.change, fromFoe: false) }
            } else {
                for target in statusTargets(move, by: index) {
                    guard hits(move, by: index, on: target) else {
                        log(.miss(attacker: id, target: battlers[target].spec.id, move: move.slug))
                        continue
                    }
                    for change in move.statChanges { changeStage(target, change.stat, by: change.change, fromFoe: true) }
                }
            }
        case .ailment, .swagger:
            guard let ailment = move.ailment else { return }
            for target in statusTargets(move, by: index) {
                if battlers[target].protectedUntil > now {
                    log(.fail(battler: id, move: move.slug, reason: .protected))
                    continue
                }
                if move.isPowder, battlers[target].types.contains(.grass) || battlers[target].ability == "overcoat" {
                    log(.noEffect(attacker: id, target: battlers[target].spec.id, move: move.slug))
                    continue
                }
                if move.type == .electric, ailment == .paralysis, battlers[target].types.contains(.ground) {
                    log(.noEffect(attacker: id, target: battlers[target].spec.id, move: move.slug))
                    continue
                }
                guard hits(move, by: index, on: target) else {
                    log(.miss(attacker: id, target: battlers[target].spec.id, move: move.slug))
                    continue
                }
                if move.category == .swagger {
                    for change in move.statChanges { changeStage(target, change.stat, by: change.change, fromFoe: true) }
                }
                inflict(ailment, on: target, by: index, move: move)
            }
        default:
            log(.fail(battler: id, move: move.slug, reason: .failed))
        }
    }

    private func statusTargets(_ move: BattleMove, by index: Int) -> [Int] {
        if move.hitsAllOpponents { return foes(of: index) }
        if let target = battlers[index].castTarget, !battlers[target].isFainted, battlers[target].slot != nil {
            return [target]
        }
        return pickTarget(for: move, by: index).map { [$0] } ?? []
    }

    /// Moonlight, Synthesis and Morning Sun heal two thirds in the sun and a quarter in other weather.
    private func healShare(_ move: BattleMove) -> Int {
        guard ["moonlight", "synthesis", "morning-sun"].contains(move.slug) else { return move.healing }
        switch weather {
        case .sun: return 67
        case nil: return 50
        default: return 25
        }
    }

    // MARK: Accuracy, criticals, type

    private mutating func hits(_ move: BattleMove, by index: Int, on target: Int) -> Bool {
        if move.accuracy == 0 { return true }
        if battlers[index].ability == "no-guard" || battlers[target].ability == "no-guard" { return true }
        if (move.slug == "thunder" || move.slug == "hurricane"), weather == .rain { return true }
        if move.slug == "blizzard", weather == .snow { return true }
        var accuracy = Double(move.accuracy)
        if (move.slug == "thunder" || move.slug == "hurricane"), weather == .sun { accuracy = 50 }
        let stage = max(-6, min(6, battlers[index].stage(.accuracy) - battlers[target].stage(.evasion)))
        accuracy *= stage >= 0 ? Double(3 + stage) / 3 : 3 / Double(3 - stage)
        if battlers[index].ability == "compound-eyes" { accuracy *= 1.3 }
        if battlers[index].ability == "hustle", move.moveClass == .physical { accuracy *= 0.8 }
        return Double(random.below(100)) < accuracy
    }

    private mutating func rollsCritical(_ move: BattleMove, by index: Int, on target: Int) -> Bool {
        if ["battle-armor", "shell-armor"].contains(battlers[target].ability) { return false }
        var stage = move.critStage
        if battlers[index].ability == "super-luck" { stage += 1 }
        switch stage {
        case ...0: return random.below(24) == 0
        case 1: return random.below(8) == 0
        case 2: return random.below(2) == 0
        default: return true
        }
    }

    /// The move's type once abilities have changed it.
    private func moveType(_ move: BattleMove, by index: Int) -> PokemonType {
        if move.slug == "weather-ball" {
            switch weather {
            case .sun: return .fire
            case .rain: return .water
            case .sand: return .rock
            case .snow: return .ice
            case nil: return .normal
            }
        }
        if move.type == .normal {
            switch battlers[index].ability {
            case "aerilate": return .flying
            case "pixilate": return .fairy
            case "refrigerate": return .ice
            case "galvanize": return .electric
            default: break
            }
        }
        if battlers[index].ability == "normalize" { return .normal }
        return move.type
    }

    private func effectiveness(_ move: BattleMove, by index: Int, on target: Int) -> Double {
        let type = moveType(move, by: index)
        let d = battlers[target]
        let breaksMold = ["mold-breaker", "teravolt", "turboblaze"].contains(battlers[index].ability)
        if type == .ground, d.ability == "levitate", !breaksMold { return 0 }
        var factor = d.types.reduce(1.0) { result, defending in
            var single = PokemonTypeData.effectiveness(attacking: type, defending: defending)
            if single == 0, defending == .ghost, (type == .normal || type == .fighting),
               battlers[index].ability == "scrappy" || battlers[index].ability == "minds-eye" {
                single = 1
            }
            if move.slug == "freeze-dry", defending == .water { single = 2 }
            return result * single
        }
        if d.ability == "wonder-guard", factor <= 1, !breaksMold { factor = 0 }
        return factor
    }

    /// Abilities that take a move whole: it heals or powers them instead of hurting. Logs and returns true when one
    /// does.
    private mutating func absorbs(_ move: BattleMove, by index: Int, target: Int) -> Bool {
        if ["mold-breaker", "teravolt", "turboblaze"].contains(battlers[index].ability) { return false }
        let type = moveType(move, by: index)
        let d = battlers[target]
        let id = d.spec.id
        func trigger() { log(.ability(battler: id, ability: d.ability)) }
        switch (d.ability, type) {
        case ("flash-fire", .fire):
            trigger()
            battlers[target].flashFire = true
            return true
        case ("well-baked-body", .fire):
            trigger()
            changeStage(target, .defense, by: 2, fromFoe: false)
            return true
        case ("water-absorb", .water), ("dry-skin", .water), ("volt-absorb", .electric), ("earth-eater", .ground):
            trigger()
            heal(target, d.maxHP / 4, .ability)
            return true
        case ("storm-drain", .water), ("lightning-rod", .electric):
            trigger()
            changeStage(target, .specialAttack, by: 1, fromFoe: false)
            return true
        case ("motor-drive", .electric):
            trigger()
            changeStage(target, .speed, by: 1, fromFoe: false)
            return true
        case ("sap-sipper", .grass):
            trigger()
            changeStage(target, .attack, by: 1, fromFoe: false)
            return true
        default:
            break
        }
        if d.ability == "soundproof", move.isSound || d.ability == "bulletproof" && move.isBallistic {
            trigger()
            return true
        }
        return false
    }

    // MARK: Damage

    private func stageMultiplier(_ stage: Int) -> Double {
        stage >= 0 ? Double(2 + stage) / 2 : 2 / Double(2 - stage)
    }

    private func isGrounded(_ index: Int) -> Bool {
        !battlers[index].types.contains(.flying) && battlers[index].ability != "levitate"
    }

    private func effectiveSpeed(_ index: Int) -> Int {
        let b = battlers[index]
        var speed = Double(b.spec.stats.speed) * stageMultiplier(b.stage(.speed))
        if b.status == .paralysis, b.ability != "quick-feet" { speed *= 0.5 }
        if b.status != nil, b.ability == "quick-feet" { speed *= 1.5 }
        switch (b.ability, weather) {
        case ("swift-swim", .rain?), ("chlorophyll", .sun?), ("sand-rush", .sand?), ("slush-rush", .snow?):
            speed *= 2
        default:
            break
        }
        if b.ability == "surge-surfer", terrain == .electric { speed *= 2 }
        if b.slowStartUntil > now { speed *= 0.5 }
        return max(1, Int(speed))
    }

    private func power(_ move: BattleMove, by index: Int, on target: Int) -> Double {
        let a = battlers[index], d = battlers[target]
        var power = Double(move.power)
        switch move.slug {
        case "gyro-ball":
            power = min(150, 25 * Double(effectiveSpeed(target)) / Double(effectiveSpeed(index)) + 1)
        case "electro-ball":
            let ratio = Double(effectiveSpeed(index)) / Double(max(1, effectiveSpeed(target)))
            power = ratio >= 4 ? 150 : ratio >= 3 ? 120 : ratio >= 2 ? 80 : ratio >= 1 ? 60 : 40
        case "eruption", "water-spout", "dragon-energy":
            power = max(1, 150 * Double(a.hp) / Double(a.maxHP))
        case "reversal", "flail":
            let share = Double(a.hp) / Double(a.maxHP)
            power = share >= 0.6875 ? 20 : share >= 0.354 ? 40 : share >= 0.208 ? 80 : share >= 0.104 ? 100 : share >= 0.042 ? 150 : 200
        case "facade": if a.status != nil { power *= 2 }
        case "hex", "infernal-parade", "bitter-malice": if d.status != nil { power *= 2 }
        case "venoshock", "barb-barrage": if d.status == .poison || d.status == .badPoison { power *= 2 }
        case "brine": if d.hp * 2 <= d.maxHP { power *= 2 }
        case "acrobatics": power *= 2
        case "stored-power", "power-trip":
            power = 20 + 20 * Double(a.stages.values.filter { $0 > 0 }.reduce(0, +))
        case "weather-ball": if weather != nil { power = 100 }
        case "solar-beam", "solar-blade": if weather == .rain || weather == .sand || weather == .snow { power /= 2 }
        case "low-kick", "grass-knot", "heavy-slam", "heat-crash": power = 80
        case "knock-off": power = 97
        case "punishment", "return", "frustration": power = 80
        default: break
        }
        let type = moveType(move, by: index)
        switch a.ability {
        case "technician": if move.power > 0, move.power <= 60 { power *= 1.5 }
        case "iron-fist": if move.isPunch { power *= 1.2 }
        case "strong-jaw": if move.isBite { power *= 1.5 }
        case "mega-launcher": if move.isPulse { power *= 1.5 }
        case "tough-claws": if move.isContact { power *= 1.3 }
        case "sharpness": if move.isSlicing { power *= 1.5 }
        case "reckless": if move.drain < 0 { power *= 1.2 }
        case "sheer-force": if move.hasSecondaryEffect { power *= 1.3 }
        case "aerilate", "pixilate", "refrigerate", "galvanize": if move.type == .normal { power *= 1.2 }
        case "sand-force": if weather == .sand, [.rock, .ground, .steel].contains(type) { power *= 1.3 }
        case "steelworker": if type == .steel { power *= 1.5 }
        case "transistor": if type == .electric { power *= 1.3 }
        case "dragons-maw": if type == .dragon { power *= 1.5 }
        case "rocky-payload": if type == .rock { power *= 1.5 }
        case "punk-rock": if move.isSound { power *= 1.3 }
        default: break
        }
        if a.hp * 3 <= a.maxHP {
            switch (a.ability, type) {
            case ("blaze", .fire), ("torrent", .water), ("overgrow", .grass), ("swarm", .bug): power *= 1.5
            default: break
            }
        }
        if a.flashFire, type == .fire { power *= 1.5 }
        if let terrain, isGrounded(index) {
            switch (terrain, type) {
            case (.electric, .electric), (.grassy, .grass), (.psychic, .psychic): power *= 1.3
            default: break
            }
        }
        if terrain == .misty, type == .dragon, isGrounded(target) { power *= 0.5 }
        return power
    }

    private mutating func damageFor(_ move: BattleMove, by index: Int, on target: Int, spread: Bool, critical: Bool,
                                    typeFactor: Double) -> Int {
        let a = battlers[index], d = battlers[target]
        if let fixed = fixedDamage(move, by: index, on: target) { return fixed }
        let physical = move.moveClass == .physical
        let attackStat: BattleStat = move.slug == "body-press" ? .defense : physical ? .attack : .specialAttack
        let defenseStat: BattleStat = physical || ["psyshock", "psystrike", "secret-sword"].contains(move.slug)
            ? .defense : .specialDefense
        let source = move.slug == "foul-play" ? d : a
        var attackStage = source.stage(attackStat)
        var defenseStage = d.stage(defenseStat)
        if critical {
            attackStage = max(0, attackStage)
            defenseStage = min(0, defenseStage)
        }
        if a.ability == "unaware" { defenseStage = 0 }
        if d.ability == "unaware" { attackStage = 0 }
        var attack = Double(source.spec.stats.value(attackStat)) * stageMultiplier(attackStage)
        var defense = Double(d.spec.stats.value(defenseStat)) * stageMultiplier(defenseStage)
        switch a.ability {
        case "huge-power", "pure-power": if attackStat == .attack { attack *= 2 }
        case "guts": if a.status != nil, physical { attack *= 1.5 }
        case "hustle", "gorilla-tactics": if physical { attack *= 1.5 }
        case "solar-power": if weather == .sun, !physical { attack *= 1.5 }
        case "flare-boost": if a.status == .burn, !physical { attack *= 1.5 }
        case "toxic-boost": if (a.status == .poison || a.status == .badPoison), physical { attack *= 1.5 }
        default: break
        }
        if a.slowStartUntil > now, physical { attack *= 0.5 }
        switch d.ability {
        case "marvel-scale": if d.status != nil, physical { defense *= 1.5 }
        case "fur-coat": if physical { defense *= 2 }
        default: break
        }
        if weather == .sand, d.types.contains(.rock), defenseStat == .specialDefense { defense *= 1.5 }
        if weather == .snow, d.types.contains(.ice), defenseStat == .defense { defense *= 1.5 }
        let level = Double(a.spec.level)
        var damage = floor(floor(floor(2 * level / 5 + 2) * power(move, by: index, on: target) * attack / max(1, defense)) / 50) + 2
        // Each modifier rounds as the games do, half down, the random roll and the type rounding down.
        func modify(_ factor: Double) { damage = Self.pokeRound(damage * factor) }
        if spread { modify(BattleRules.spreadFactor) }
        let type = moveType(move, by: index)
        switch (weather, type) {
        case (.sun?, .fire), (.rain?, .water): modify(1.5)
        case (.sun?, .water), (.rain?, .fire): modify(0.5)
        default: break
        }
        if critical { modify(a.ability == "sniper" ? 2.25 : 1.5) }
        damage = floor(damage * Double(85 + random.below(16)) / 100)
        if a.types.contains(type) || ["protean", "libero"].contains(a.ability) {
            modify(a.ability == "adaptability" ? 2 : 1.5)
        }
        damage = floor(damage * typeFactor)
        if a.status == .burn, physical, a.ability != "guts", move.slug != "facade" { modify(0.5) }
        let breaksMold = ["mold-breaker", "teravolt", "turboblaze"].contains(a.ability)
        if !breaksMold {
            switch d.ability {
            case "filter", "solid-rock", "prism-armor": if typeFactor > 1 { modify(0.75) }
            case "multiscale", "shadow-shield": if d.hp == d.maxHP { modify(0.5) }
            case "thick-fat": if type == .fire || type == .ice { modify(0.5) }
            case "heatproof", "water-bubble": if type == .fire { modify(0.5) }
            case "ice-scales": if !physical { modify(0.5) }
            case "fluffy":
                if move.isContact { modify(0.5) }
                if type == .fire { modify(2) }
            case "purifying-salt": if type == .ghost { modify(0.5) }
            default: break
            }
        }
        if a.ability == "tinted-lens", typeFactor < 1 { modify(2) }
        if a.ability == "water-bubble", type == .water { modify(2) }
        return max(1, Int(damage))
    }

    /// The games' rounding: half rounds down.
    static func pokeRound(_ value: Double) -> Double {
        value - floor(value) > 0.5 ? ceil(value) : floor(value)
    }

    private func fixedDamage(_ move: BattleMove, by index: Int, on target: Int) -> Int? {
        let a = battlers[index], d = battlers[target]
        switch move.slug {
        case "seismic-toss", "night-shade": return a.spec.level
        case "dragon-rage": return 40
        case "sonic-boom": return 20
        case "psywave": return max(1, a.spec.level * (50 + (a.hp % 101)) / 100)
        case "super-fang", "natures-madness", "ruination":
            // A boss loses at most an eighth of its HP to these, or they would halve any boss twice.
            let half = max(1, d.hp / 2)
            return d.spec.isBoss ? min(half, d.maxHP / 8) : half
        case "final-gambit": return a.hp
        default: return nil
        }
    }

    private func confusionDamage(_ index: Int) -> Int {
        let b = battlers[index]
        let level = Double(b.spec.level)
        let attack = Double(b.spec.stats.attack) * stageMultiplier(b.stage(.attack))
        let defense = Double(b.spec.stats.defense) * stageMultiplier(b.stage(.defense))
        return max(1, Int(floor(floor(floor(2 * level / 5 + 2) * 40 * attack / max(1, defense)) / 50) + 2))
    }

    private mutating func dealDamage(_ damage: Int, to target: Int, by index: Int, move: BattleMove,
                                     effectiveness: Double, critical: Bool) {
        var amount = min(damage, battlers[target].hp)
        // Sturdy and a Focus Sash would leave 1 HP at full health: Sturdy only, items aside.
        if battlers[target].ability == "sturdy", battlers[target].hp == battlers[target].maxHP, amount >= battlers[target].hp,
           !["mold-breaker", "teravolt", "turboblaze"].contains(battlers[index].ability) {
            amount = battlers[target].hp - 1
            log(.ability(battler: battlers[target].spec.id, ability: "sturdy"))
        }
        battlers[target].hp -= amount
        log(.hit(attacker: battlers[index].spec.id, target: battlers[target].spec.id, move: move.slug, damage: amount,
                 hp: battlers[target].hp, effectiveness: effectiveness, critical: critical))
        if battlers[target].isFainted {
            faint(target, by: index)
        } else {
            afterHit(target, by: index, move: move)
            eatBerryIfLow(target)
        }
    }

    private mutating func afterHit(_ target: Int, by index: Int, move: BattleMove) {
        let type = moveType(move, by: index)
        switch battlers[target].ability {
        case "stamina": changeStage(target, .defense, by: 1, fromFoe: false)
        case "justified": if type == .dark { changeStage(target, .attack, by: 1, fromFoe: false) }
        case "weak-armor":
            if move.moveClass == .physical {
                changeStage(target, .defense, by: -1, fromFoe: false)
                changeStage(target, .speed, by: 2, fromFoe: false)
            }
        case "rattled": if [.bug, .dark, .ghost].contains(type) { changeStage(target, .speed, by: 1, fromFoe: false) }
        case "water-compaction": if type == .water { changeStage(target, .defense, by: 2, fromFoe: false) }
        case "steam-engine": if type == .water || type == .fire { changeStage(target, .speed, by: 6, fromFoe: false) }
        default: break
        }
    }

    private mutating func contactEffects(_ move: BattleMove, attacker index: Int, target: Int) {
        guard move.isContact, !battlers[index].isFainted else { return }
        let ability = battlers[target].ability
        switch ability {
        case "rough-skin", "iron-barbs":
            guard battlers[index].ability != "magic-guard" else { return }
            log(.ability(battler: battlers[target].spec.id, ability: ability))
            hurt(index, max(1, battlers[index].maxHP / 8), .ability)
        case "static": if random.below(10) < 3 { inflict(.paralysis, on: index, by: target) }
        case "flame-body": if random.below(10) < 3 { inflict(.burn, on: index, by: target) }
        case "poison-point": if random.below(10) < 3 { inflict(.poison, on: index, by: target) }
        case "effect-spore":
            if random.below(10) < 3 {
                inflict([.poison, .paralysis, .sleep][random.below(3)], on: index, by: target)
            }
        default: break
        }
    }

    private mutating func secondaryEffects(_ move: BattleMove, by index: Int, on target: Int) {
        if battlers[index].ability == "sheer-force", move.hasSecondaryEffect { return }
        if battlers[target].ability == "shield-dust" { return }
        if let ailment = move.ailment, move.category == .damageAilment || move.ailmentChance > 0 {
            let chance = move.ailmentChance > 0 ? move.ailmentChance : move.effectChance
            if random.chance(serene(index, chance)) { inflict(ailment, on: target, by: index, move: move) }
        }
        if move.flinchChance > 0, random.chance(serene(index, move.flinchChance)),
           battlers[target].ability != "inner-focus", let slug = battlers[target].castMove {
            let base = MoveTable.move(slug)?.castBase ?? 1200
            let duration = Double(base) * 300 / (100 + Double(effectiveSpeed(target))) / Double(BattleRules.speedUp)
            battlers[target].castEnds = now + max(100, Int(duration.rounded()))
            log(.flinch(battler: battlers[target].spec.id))
            if battlers[target].ability == "steadfast" { changeStage(target, .speed, by: 1, fromFoe: false) }
        }
        if move.category == .damageLower, random.chance(serene(index, move.statChance == 0 ? 100 : move.statChance)) {
            for change in move.statChanges { changeStage(target, change.stat, by: change.change, fromFoe: true) }
        }
    }

    private func serene(_ index: Int, _ chance: Int) -> Int {
        battlers[index].ability == "serene-grace" ? chance * 2 : chance
    }

    // MARK: Status

    private func canInflict(_ ailment: BattleAilment, on target: Int, move: BattleMove? = nil) -> Bool {
        let d = battlers[target]
        if terrain == .misty, isGrounded(target), ailment != .leechSeed, ailment != .trap { return false }
        switch ailment {
        case .confusion: return d.confusedUntil <= now && d.ability != "own-tempo"
        case .leechSeed: return d.seededBy == nil && !d.types.contains(.grass)
        case .yawn: return d.status == nil && d.yawnAt == nil && !["insomnia", "vital-spirit"].contains(d.ability)
        case .trap: return d.trappedBy == nil
        default: break
        }
        guard d.status == nil else { return false }
        if d.ability == "comatose" || d.ability == "purifying-salt" { return false }
        switch ailment {
        case .burn: return !d.types.contains(.fire) && !["water-veil", "water-bubble", "thermal-exchange"].contains(d.ability)
        case .poison, .badPoison:
            return !d.types.contains(.poison) && !d.types.contains(.steel) && !["immunity", "pastel-veil"].contains(d.ability)
        case .paralysis: return !d.types.contains(.electric) && d.ability != "limber"
        case .sleep: return !["insomnia", "vital-spirit", "sweet-veil"].contains(d.ability) && terrain != .electric
        case .freeze: return !d.types.contains(.ice) && d.ability != "magma-armor" && weather != .sun
        default: return true
        }
    }

    private mutating func inflict(_ ailment: BattleAilment, on target: Int, by source: Int?, move: BattleMove? = nil) {
        var ailment = ailment
        if move?.slug == "toxic" { ailment = .badPoison }
        guard canInflict(ailment, on: target, move: move) else { return }
        let id = battlers[target].spec.id
        switch ailment {
        case .confusion:
            battlers[target].confusedUntil = now + random.between(3000, 8000)
        case .leechSeed:
            battlers[target].seededBy = source
        case .yawn:
            battlers[target].yawnAt = now + BattleRules.residualTick
        case .trap:
            let ticks = move.map { max(4, $0.minTurns) } ?? 4
            battlers[target].trapUntil = now + ticks * BattleRules.residualTick
            battlers[target].trappedBy = source
        case .sleep:
            battlers[target].status = .sleep
            battlers[target].wakeAt = now + random.between(3000, 8000)
            battlers[target].castMove = nil
        case .freeze:
            battlers[target].status = .freeze
            battlers[target].castMove = nil
        case .badPoison:
            battlers[target].status = .badPoison
            battlers[target].toxicCount = 0
        default:
            battlers[target].status = ailment
        }
        log(.status(battler: id, ailment: ailment))
    }

    private mutating func cure(_ index: Int) {
        guard let status = battlers[index].status else { return }
        battlers[index].status = nil
        log(.cure(battler: battlers[index].spec.id, ailment: status))
    }

    private func residualAbility(_ b: Battler) -> Bool {
        ["speed-boost", "rain-dish", "ice-body", "dry-skin", "solar-power", "poison-heal"].contains(b.ability)
            || terrain == .grassy
    }

    private mutating func residualTick() {
        for index in active where !battlers[index].isFainted {
            let b = battlers[index]
            let guarded = b.ability == "magic-guard"
            switch b.status {
            case .burn?:
                if !guarded { hurt(index, max(1, b.maxHP / 16), .burn) }
            case .poison?, .badPoison?:
                if b.ability == "poison-heal" {
                    heal(index, max(1, b.maxHP / 8), .ability)
                } else if !guarded {
                    var amount = max(1, b.maxHP / 8)
                    if b.status == .badPoison {
                        battlers[index].toxicCount += 1
                        amount = max(1, b.maxHP * battlers[index].toxicCount / 16)
                    }
                    hurt(index, amount, .poison)
                }
            default: break
            }
            guard !battlers[index].isFainted else { continue }
            if weather == .sand, !guarded, !b.types.contains(.rock), !b.types.contains(.ground), !b.types.contains(.steel),
               !["sand-veil", "sand-rush", "sand-force", "overcoat"].contains(b.ability) {
                hurt(index, max(1, b.maxHP / 16), .weather)
            }
            switch (b.ability, weather) {
            case ("rain-dish", .rain?), ("ice-body", .snow?): heal(index, max(1, b.maxHP / 16), .weather)
            case ("dry-skin", .rain?): heal(index, max(1, b.maxHP / 8), .weather)
            case ("dry-skin", .sun?), ("solar-power", .sun?): if !guarded { hurt(index, max(1, b.maxHP / 8), .sun) }
            default: break
            }
            if terrain == .grassy, isGrounded(index), !battlers[index].isFainted { heal(index, max(1, b.maxHP / 16), .terrain) }
            if let trapper = battlers[index].trappedBy, !battlers[index].isFainted {
                if battlers[index].trapUntil <= now || battlers[trapper].isFainted || battlers[trapper].slot == nil {
                    battlers[index].trappedBy = nil
                } else if !guarded {
                    hurt(index, max(1, b.maxHP / 8), .trap)
                }
            }
            if let seeder = battlers[index].seededBy, !battlers[index].isFainted {
                if !guarded {
                    let amount = min(battlers[index].hp, max(1, b.maxHP / 8))
                    hurt(index, amount, .leechSeed)
                    if !battlers[seeder].isFainted, battlers[seeder].slot != nil { heal(seeder, amount, .leechSeed) }
                }
            }
            if b.ability == "speed-boost", !battlers[index].isFainted {
                log(.ability(battler: b.spec.id, ability: b.ability))
                changeStage(index, .speed, by: 1, fromFoe: false)
            }
        }
    }

    // MARK: HP

    private mutating func hurt(_ index: Int, _ amount: Int, _ cause: BattleHurtCause) {
        guard !battlers[index].isFainted, amount > 0 else { return }
        let taken = min(amount, battlers[index].hp)
        battlers[index].hp -= taken
        log(.hurt(battler: battlers[index].spec.id, amount: taken, hp: battlers[index].hp, cause: cause))
        if battlers[index].isFainted { faint(index, by: nil) } else { eatBerryIfLow(index) }
    }

    private mutating func heal(_ index: Int, _ amount: Int, _ cause: BattleHealCause) {
        guard !battlers[index].isFainted, amount > 0, battlers[index].hp < battlers[index].maxHP else { return }
        let gained = min(amount, battlers[index].maxHP - battlers[index].hp)
        battlers[index].hp += gained
        log(.heal(battler: battlers[index].spec.id, amount: gained, hp: battlers[index].hp, cause: cause))
    }

    /// A side's berry, eaten once per Pokémon when its HP fall under half: a Sitrus under a quarter, else an Oran first.
    private mutating func eatBerryIfLow(_ index: Int) {
        let b = battlers[index]
        guard !b.ateBerry, !b.isFainted, b.hp * 2 < b.maxHP else { return }
        let side = b.side
        let pick: BattleBerry?
        if b.hp * 4 <= b.maxHP, (berries[side][.sitrus] ?? 0) > 0 {
            pick = .sitrus
        } else if (berries[side][.oran] ?? 0) > 0 {
            pick = .oran
        } else if (berries[side][.sitrus] ?? 0) > 0 {
            pick = .sitrus
        } else {
            pick = nil
        }
        guard let pick else { return }
        berries[side][pick, default: 0] -= 1
        battlers[index].ateBerry = true
        log(.berry(battler: b.spec.id, berry: pick))
        heal(index, max(1, Int(Double(b.maxHP) * pick.share)), .berry)
    }

    private mutating func faint(_ index: Int, by attacker: Int?) {
        let id = battlers[index].spec.id
        battlers[index].castMove = nil
        log(.faint(battler: id))
        if let attacker, attacker != index, battlers[index].destinyBond, !battlers[attacker].isFainted {
            let taken = battlers[attacker].hp
            battlers[attacker].hp = 0
            log(.hurt(battler: battlers[attacker].spec.id, amount: taken, hp: 0, cause: .destinyBond))
            faint(attacker, by: nil)
        }
        if let attacker, !battlers[attacker].isFainted {
            switch battlers[attacker].ability {
            case "moxie", "chilling-neigh":
                log(.ability(battler: battlers[attacker].spec.id, ability: battlers[attacker].ability))
                changeStage(attacker, .attack, by: 1, fromFoe: false)
            case "grim-neigh":
                log(.ability(battler: battlers[attacker].spec.id, ability: battlers[attacker].ability))
                changeStage(attacker, .specialAttack, by: 1, fromFoe: false)
            case "beast-boost":
                let stats: [BattleStat] = [.attack, .defense, .specialAttack, .specialDefense, .speed]
                let best = stats.max { battlers[attacker].spec.stats.value($0) < battlers[attacker].spec.stats.value($1) } ?? .attack
                log(.ability(battler: battlers[attacker].spec.id, ability: battlers[attacker].ability))
                changeStage(attacker, best, by: 1, fromFoe: false)
            default: break
            }
        }
        for other in battlers.indices where battlers[other].seededBy == index || battlers[other].trappedBy == index {
            if battlers[other].trappedBy == index { battlers[other].trappedBy = nil }
        }
        guard let slot = battlers[index].slot else { return }
        let side = battlers[index].side
        if !bench(side).isEmpty, !pendingEntries.contains(where: { $0.side == side && $0.slot == slot }) {
            pendingEntries.append((now + BattleRules.benchDelay, side, slot))
        }
    }

    // MARK: Stats

    private mutating func changeStage(_ index: Int, _ stat: BattleStat, by amount: Int, fromFoe: Bool) {
        guard !battlers[index].isFainted else { return }
        let ability = battlers[index].ability
        var amount = amount
        if ability == "contrary" { amount = -amount }
        if ability == "simple" { amount *= 2 }
        if fromFoe, amount < 0 {
            if ["clear-body", "white-smoke", "full-metal-body"].contains(ability)
                || ability == "hyper-cutter" && stat == .attack || ability == "keen-eye" && stat == .accuracy
                || ability == "big-pecks" && stat == .defense {
                log(.ability(battler: battlers[index].spec.id, ability: ability))
                return
            }
        }
        let current = battlers[index].stage(stat)
        let next = max(-6, min(6, current + amount))
        guard next != current else { return }
        battlers[index].stages[stat] = next
        log(.stat(battler: battlers[index].spec.id, stat: stat, change: next - current))
        if fromFoe, next < current {
            switch ability {
            case "defiant":
                log(.ability(battler: battlers[index].spec.id, ability: ability))
                changeStage(index, .attack, by: 2, fromFoe: false)
            case "competitive":
                log(.ability(battler: battlers[index].spec.id, ability: ability))
                changeStage(index, .specialAttack, by: 2, fromFoe: false)
            default: break
            }
        }
    }

    // MARK: The end

    private mutating func checkVictory() {
        guard winner == nil else { return }
        let standing = (0..<2).map { side in battlers.contains { $0.side == side && !$0.isFainted } }
        if !standing[0] {
            winner = 1
        } else if !standing[1] {
            winner = 0
        }
    }

    /// At the time limit, the side with the larger share of its HP left wins; the foes on a tie.
    private func winnerOnHP() -> Int {
        let shares = (0..<2).map { side -> Double in
            let mine = battlers.filter { $0.side == side }
            let total = mine.reduce(0) { $0 + $1.maxHP }
            return total > 0 ? Double(mine.reduce(0) { $0 + max(0, $1.hp) }) / Double(total) : 0
        }
        return shares[0] > shares[1] ? 0 : 1
    }

    private mutating func log(_ event: BattleEvent) {
        events.append(TimedBattleEvent(time: now, event: event))
    }

    // MARK: Tables

    static let weatherMoves: [String: BattleWeather] = [
        "sunny-day": .sun, "rain-dance": .rain, "sandstorm": .sand, "hail": .snow, "snowscape": .snow,
        "chilly-reception": .snow,
    ]
    static let terrainMoves: [String: BattleTerrain] = [
        "electric-terrain": .electric, "grassy-terrain": .grassy, "misty-terrain": .misty, "psychic-terrain": .psychic,
    ]
    static let ohkoMoves: Set<String> = ["fissure", "guillotine", "horn-drill", "sheer-cold"]

    /// What a status move does, as the engine reads it: a move PokéAPI files as unique but that only changes stats
    /// (Shell Smash) counts as a stat move.
    static func statusKind(_ move: BattleMove) -> MoveMetaCategory {
        if move.category == .unique, !move.statChanges.isEmpty { return .netGoodStats }
        return move.category
    }

    /// The moves the engine plays, the others doing nothing here: the Pokémon sheet says so (`BattleMove.hasEffect`).
    static let handledStatusMoves = Set(["protect", "detect", "kings-shield", "spiky-shield", "baneful-bunker",
        "obstruct", "silk-trap", "burning-bulwark", "destiny-bond", "wish", "rest", "belly-drum"])
        .union(weatherMoves.keys).union(terrainMoves.keys)
}
