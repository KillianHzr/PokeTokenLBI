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

    /// The stack a battle runs on away from the main thread: a main thread's and more. A battle's deepest call (a
    /// knock-out inside a hit inside a cast) took more than a secondary thread's 512 KB in a debug build, and the replay
    /// run with `Task.detached` crashed on `___chkstk_darwin` (2026-11-04).
    static let stackSize = 16 << 20

    /// `work` (a battle, or the expeditions an estimate plays) on a thread of its own with `stackSize`, never on a
    /// task's thread: what the screens wait for off the main thread goes through here.
    static func offMain<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            let thread = Thread { continuation.resume(returning: work()) }
            thread.stackSize = stackSize
            thread.qualityOfService = .userInitiated
            thread.start()
        }
    }
}

/// One battle being played. Every list is walked in a fixed order, so the same seed always gives the same battle.
struct BattleSimulation {
    struct Battler {
        /// Transform rewrites its stats, ability and loop.
        var spec: BattlerSpec
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
        /// The last physical and special hits it took from a foe, a multi-hit move summed: what Counter, Mirror Coat,
        /// Metal Burst and Comeuppance send back.
        var lastPhysicalHit: ReceivedHit?
        var lastSpecialHit: ReceivedHit?
        /// What Bide stores during its cast, and the foe that hit last.
        var bideTaken = 0
        var bideAttacker: Int?
        /// The damage the reactive move being used sends back.
        var answering: Int?
        /// The move it used last, a called move rather than its caller: what Mirror Move, Mimic and Instruct read.
        var lastMove: String?
        var transformed = false
        /// Me First's 1.5x on the move it takes.
        var powerBoost = 1.0
        /// The protection standing (`protectedUntil`), and how many protections succeeded in a row.
        var protection: String?
        var protectStreak = 0
        var enduringUntil = 0
        var substituteHP = 0
        var magicCoatUntil = 0
        var snatchUntil = 0
        /// Casts completed since it entered: Mat Block only works on the first.
        var castsSinceEntry = 0
        /// Restraints, to when they hold: Taunt (status moves), Encore (its move only), Disable (that move), Heal
        /// Block, Embargo (berries), Telekinesis and Magnet Rise (off the ground).
        var tauntedUntil = 0
        var encoreUntil = 0
        var encoreMove: String?
        var disabledUntil = 0
        var disabledMove: String?
        var healBlockedUntil = 0
        var embargoUntil = 0
        var telekinesisUntil = 0
        var magnetRiseUntil = 0
        /// Torment: never the same move twice in a row. Grudge's: moves a fainting Grudge user took for good.
        var tormented = false
        var lostMoves: Set<String> = []
        var imprisoning = false
        var grudge = false
        var perishAt: Int?
        var nightmare = false
        var cursed = false
        var ingrained = false
        var aquaRing = false
        /// Foresight and Odor Sleuth (Ghost hit by Normal and Fighting), Miracle Eye (Dark by Psychic): evasion ignored.
        var identified = false
        var miracleEye = false
        var tarred = false
        var noRetreat = false
        var octolockedBy: Int?
        /// Lock-On and Mind Reader: the next move at this target never misses.
        var lockOn: (target: Int, until: Int)?
        /// Electrify: its next move is Electric. Helping Hand: its next move has 1.5x the power.
        var electrified = false
        var helped = false
        /// Follow Me, Rage Powder, Spotlight: the foes' single-target moves come at it meanwhile.
        var centerUntil = 0
        var ragePowder = false
        /// What it entered the battle as: leaving the field gives it back.
        var originalSpec: BattlerSpec?
        /// The berry it ate last (Belch, Recycle), and the one its Fling or Natural Gift is using.
        var consumedBerry: BattleBerry?
        var throwing: BattleBerry?
        /// Fly, Dig, Dive, Bounce, Phantom Force, Shadow Force, Sky Drop: out of reach while it casts it.
        var semiInvulnerable: String?
        /// Outrage and its kin, Rollout, Ice Ball, Uproar: the move it is locked into, the casts left and done.
        var lockedMove: String?
        var lockedLeft = 0
        var lockedDone = 0
        /// Fury Cutter and Echoed Voice: how many landed in a row before this one. Defense Curl doubles Rollout.
        var streak = 0
        var lastLanded = false
        var defenseCurl = false
        /// Charge, Wind Power or Electromorphosis: its next Electric move hits twice as hard.
        var charged = false
        /// The species and form it weighs as: its own, or its target's after Transform.
        var weighsAs: (speciesID: Int, form: PokemonForm?)?
        /// Autotomize's uses: 100 kg lighter each.
        var autotomized = 0
        /// Minimize used: Stomp, Body Slam, Heavy Slam and the others hit it twice as hard, and never miss.
        var minimized = false
        /// The foe it strikes with Pursuit as that foe leaves: twice the power, never a miss.
        var pursuing: Int?
        /// When its cast started, when it last acted, last took damage, last had a stat lowered, and when each foe
        /// last hit it: what Payback, Avalanche, Assurance, Focus Punch, Bolt Beak and Lash Out read.
        var castStartedAt = 0
        var lastActionAt = -1
        var lastDamagedAt = -1
        var loweredAt = -1
        var hitBy: [Int: Int] = [:]
        /// The moves it used since it entered (Last Resort), its Stockpile count, whether Smack Down grounded it.
        var usedSinceEntry: Set<String> = []
        var stockpile = 0
        var smackedDown = false
        /// Magnitude's, Present's or Beat Up's power for the hit being dealt.
        var rolledPower: Double?
        /// Roost: its Flying type is set aside until its next cast ends.
        var roosting = false
        /// Glaive Rush: until its next cast ends, hits on it never miss and deal double.
        var exposed = false
        /// Salt Cure on it; Syrup Bomb's turns left; how many hits it took (Rage Fist); when a stat of it last rose.
        var salted = false
        var syrupLeft = 0
        var timesHit = 0
        var raisedAt = -1
        /// Attract or Cute Charm: in love with this battler, it fails half its casts while that one stands.
        var infatuatedBy: Int?
        /// Focus Energy (+2) and Dragon Cheer (+1, +2 for a Dragon) to its critical-hit stage; Laser Focus: its next
        /// move a critical hit; Powder: its next Fire move bursts.
        var critBoost = 0
        var laserFocus = false
        var powdered = false

        var maxHP: Int { spec.stats.hp }
        var isFainted: Bool { hp <= 0 }
        var ability: String { spec.ability ?? "" }
        func stage(_ stat: BattleStat) -> Int { stages[stat] ?? 0 }
    }

    struct ReceivedHit {
        let time: Int
        var amount: Int
        let attacker: Int
        let move: String
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
    /// The last move anyone used: Copycat's.
    private var lastMoveUsed: String?
    /// Future Sight and Doom Desire on their way: when, the slot they land on, who sent them.
    private var futureAttacks: [(time: Int, side: Int, slot: Int, attacker: Int, move: String)] = []
    private var resolvingFuture = false
    /// Healing Wish and Lunar Dance: the next Pokémon to step into these slots comes in whole and cured.
    private var healingWishes: Set<[Int]> = []
    /// Each side's Wide Guard, Quick Guard, Mat Block and Crafty Shield, to when they hold.
    private var sideGuards: [[String: Int]] = [[:], [:]]
    /// Each side's screens, Safeguard, Mist, Tailwind and Lucky Chant, to when they hold.
    private var sideConditions: [[String: Int]] = [[:], [:]]
    /// Each side's entry hazards and their layers: what the Pokémon sent in on that side step on.
    private var hazards: [[String: Int]] = [[:], [:]]
    /// Trick Room, Gravity, Magic Room, Wonder Room, Mud Sport, Water Sport and Ion Deluge, to when they hold.
    private var fieldConditions: [String: Int] = [:]

    init(_ setup: BattleSetup) {
        self.setup = setup
        random = BattleRandom(seed: setup.seed)
        berries = setup.sides.map(\.berries)
        for (side, spec) in setup.sides.enumerated() {
            for battler in spec.battlers {
                battlers.append(Battler(spec: battler, side: side, hp: min(battler.hp, battler.stats.hp), types: battler.types,
                                        originalSpec: battler))
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
        var times: [Int] = pendingEntries.map(\.time) + wishes.map(\.time) + futureAttacks.map(\.time)
        if weather != nil { times.append(weatherUntil) }
        if terrain != nil { times.append(terrainUntil) }
        times += sideConditions.flatMap(\.values) + fieldConditions.values
        if active.contains(where: { battlers[$0].status != nil || battlers[$0].trappedBy != nil
            || battlers[$0].seededBy != nil || residualAbility(battlers[$0]) || battlers[$0].cursed
            || battlers[$0].ingrained || battlers[$0].aquaRing || battlers[$0].octolockedBy != nil || battlers[$0].salted
            || battlers[$0].syrupLeft > 0 }) || weather == .sand {
            times.append(nextResidual)
        }
        if active.contains(where: { battlers[$0].status == .freeze }) { times.append(nextThaw) }
        for index in active {
            let b = battlers[index]
            if b.status == .sleep { times.append(b.wakeAt) }
            if let yawn = b.yawnAt { times.append(yawn) }
            if let perish = b.perishAt { times.append(perish) }
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
        for side in sideConditions.indices {
            for (condition, until) in sideConditions[side].sorted(by: { $0.key < $1.key }) where until <= now {
                sideConditions[side][condition] = nil
                log(.sideCondition(side: side, condition: condition, active: false))
            }
        }
        for (condition, until) in fieldConditions.sorted(by: { $0.key < $1.key }) where until <= now {
            fieldConditions[condition] = nil
            log(.fieldCondition(condition: condition, active: false))
        }
        for entry in pendingEntries.filter({ $0.time <= now }).sorted(by: { ($0.side, $0.slot) < ($1.side, $1.slot) }) {
            pendingEntries.removeAll { $0.side == entry.side && $0.slot == entry.slot }
            sendIn(side: entry.side, slot: entry.slot)
        }
        for attack in futureAttacks.filter({ $0.time <= now }) {
            futureAttacks.removeAll { $0.time == attack.time && $0.side == attack.side && $0.slot == attack.slot }
            guard let target = field[attack.side][attack.slot], !battlers[target].isFainted,
                  let move = MoveTable.move(attack.move) else { continue }
            // It lands through Protect, from a user still in the battle or not.
            resolvingFuture = true
            _ = strike(move, by: attack.attacker, on: target, spread: false)
            resolvingFuture = false
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
            if let perish = battlers[index].perishAt, perish <= now {
                battlers[index].perishAt = nil
                hurt(index, battlers[index].hp, .perishSong)
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
        // A cast pushed back (Flinch, Quash) or restarted (Pursuit) during this step waits for its own end.
        for index in casting where battlers[index].castMove != nil && battlers[index].castEnds <= now
            && !battlers[index].isFainted && winner == nil {
            completeCast(index)
            checkVictory()
        }
        // Cured of sleep or freeze by a move (Heal Bell, Purify), a Pokémon left without a cast starts one: no other step
        // would, and it stood idle for the rest of the battle.
        for index in active where battlers[index].castMove == nil && battlers[index].status != .sleep
            && battlers[index].status != .freeze && winner == nil {
            startCast(index)
        }
        // Put to sleep by this step, a Pokémon that knows Sleep Talk or Snore starts one.
        for index in active where battlers[index].status == .sleep && battlers[index].castMove == nil
            && battlers[index].spec.moves.contains(where: Self.sleepMoves.contains) {
            startCast(index)
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
        if healingWishes.remove([side, slot]) != nil {
            heal(pick, battlers[pick].maxHP, .move)
            cure(pick)
            log(.volatile(battler: battlers[pick].spec.id, effect: "healing-wish"))
        }
        stepOnHazards(pick)
        guard !battlers[pick].isFainted else { return }
        entryAbility(pick)
        startCast(pick)
    }

    /// The hazards of its side hurt or slow a Pokémon sent in: Spikes (1/8, 1/6, 1/4 by layer) and Sticky Web on the
    /// ground, Toxic Spikes poison it there (a Poison type on the ground clears them), Stealth Rock by its Rock
    /// weakness. Magic Guard keeps the damage off.
    private mutating func stepOnHazards(_ index: Int) {
        let side = battlers[index].side
        let guarded = battlers[index].ability == "magic-guard"
        if let rocks = hazards[side]["stealth-rock"], rocks > 0, !guarded {
            let factor = battlers[index].types.reduce(1.0) { $0 * PokemonTypeData.effectiveness(attacking: .rock, defending: $1) }
            hurt(index, max(1, Int(Double(battlers[index].maxHP) * factor / 8)), .hazard)
        }
        guard !battlers[index].isFainted, isGrounded(index) else { return }
        if let spikes = hazards[side]["spikes"], spikes > 0, !guarded {
            hurt(index, max(1, battlers[index].maxHP / [8, 6, 4][min(spikes, 3) - 1]), .hazard)
        }
        guard !battlers[index].isFainted else { return }
        if let toxic = hazards[side]["toxic-spikes"], toxic > 0 {
            if battlers[index].types.contains(.poison) {
                hazards[side]["toxic-spikes"] = nil
                log(.hazard(side: side, hazard: "toxic-spikes", layers: 0))
            } else if !sideHas(side, "safeguard") {
                inflict(toxic > 1 ? .badPoison : .poison, on: index, by: nil)
            }
        }
        if hazards[side]["sticky-web"] ?? 0 > 0 { changeStage(index, .speed, by: -1, fromFoe: true) }
    }

    private func sideHas(_ side: Int, _ condition: String) -> Bool { (sideConditions[side][condition] ?? 0) > now }
    private func fieldHas(_ condition: String) -> Bool { (fieldConditions[condition] ?? 0) > now }

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
        // Wind Rider arriving under its side's Tailwind raises its Attack.
        if b.ability == "wind-rider", sideHas(b.side, "tailwind") { feelsTailwind(index) }
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
        case "imposter":
            guard let slot = b.slot else { return }
            let opposite = field[1 - b.side]
            let facing = slot < opposite.count ? opposite[slot] : nil
            guard let foe = facing.flatMap({ battlers[$0].isFainted ? nil : $0 }) ?? foes(of: index).first,
                  !battlers[foe].transformed else { return }
            log(.ability(battler: b.spec.id, ability: b.ability))
            transform(index, into: foe)
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
        let asleep = battlers[index].status == .sleep
        guard battlers[index].status != .freeze,
              !asleep || battlers[index].spec.moves.contains(where: Self.sleepMoves.contains) else {
            battlers[index].castMove = nil
            return
        }
        let loop = battlers[index].spec.moves
        var chosen: String?
        // A lock whose move it may no longer use (Disable, Imprison, Grudge) ends, and the loop goes on: it was Struggle
        // for good.
        if let locked = battlers[index].lockedMove, battlers[index].lockedLeft > 0, !canUse(locked, by: index) {
            battlers[index].lockedMove = nil
            battlers[index].lockedLeft = 0
        }
        if battlers[index].loafing {
            chosen = "_loaf"
        } else if !asleep, let locked = battlers[index].lockedMove, battlers[index].lockedLeft > 0 {
            // Outrage, Rollout, Uproar: the same move again until the lock is over.
            chosen = locked
        } else if !asleep, battlers[index].encoreUntil > now, let encored = battlers[index].encoreMove {
            // Encore: its move again, useful or not; Struggle when it may not.
            chosen = canUse(encored, by: index) ? encored : nil
        } else {
            for offset in 0..<max(1, loop.count) where !loop.isEmpty {
                let slug = loop[(battlers[index].moveIndex + offset) % loop.count]
                if isUseful(slug, by: index), canUse(slug, by: index) {
                    battlers[index].moveIndex = (battlers[index].moveIndex + offset) % loop.count
                    chosen = slug
                    break
                }
            }
        }
        if asleep, chosen == nil {
            battlers[index].castMove = nil
            return
        }
        let slug = chosen ?? "struggle"
        let move = MoveTable.move(slug)
        let target = move.flatMap { pickTarget(for: $0, by: index) }
        if slug == "bide" {
            battlers[index].bideTaken = 0
            battlers[index].bideAttacker = nil
        }
        battlers[index].castMove = slug
        battlers[index].castTarget = target
        battlers[index].castStartedAt = now
        battlers[index].castEnds = now + castDuration(slug, by: index)
        battlers[index].semiInvulnerable = Self.semiInvulnerableMoves.contains(slug) ? slug : nil
        // Skull Bash, Meteor Beam and Electro Shot raise a stat as they start to charge.
        switch slug {
        case "skull-bash": changeStage(index, .defense, by: 1, fromFoe: false)
        case "meteor-beam", "electro-shot": changeStage(index, .specialAttack, by: 1, fromFoe: false)
        default: break
        }
        log(.cast(battler: battlers[index].spec.id, move: slug, target: target.map { battlers[$0].spec.id },
                  ends: battlers[index].castEnds))
    }

    /// How long a cast of `slug` lasts from now: its base by the caster's speed, a third (R1). Bide waits two turns
    /// whatever its speed; Solar Beam in the sun skips its charge.
    /// The speed a cast's length reads: Trick Room turns speeds around, the slower cast quicker.
    private func castSpeed(_ index: Int) -> Int {
        fieldHas("trick-room") ? max(10, 400 - effectiveSpeed(index)) : effectiveSpeed(index)
    }

    private func castDuration(_ slug: String, by index: Int) -> Int {
        if slug == "bide" { return 2 * BattleRules.turn }
        let scale = 300 / (100 + Double(castSpeed(index))) / Double(BattleRules.speedUp)
        var duration = Double(MoveTable.move(slug)?.castBase ?? 1200) * scale
        if slug == "solar-beam" || slug == "solar-blade", weather == .sun { duration -= 2000 * scale }
        if slug == "electro-shot", weather == .rain { duration -= 2000 * scale }
        return max(100, Int(duration.rounded()))
    }

    private mutating func completeCast(_ index: Int) {
        guard let slug = battlers[index].castMove else { return }
        battlers[index].castMove = nil
        battlers[index].semiInvulnerable = nil
        battlers[index].exposed = false
        // Destiny Bond holds through the cast that follows it, to that cast's end.
        battlers[index].destinyBond = false
        if slug == "_loaf" {
            log(.fail(battler: battlers[index].spec.id, move: slug, reason: .truant))
            advance(index, after: slug)
            return
        }
        if let lover = battlers[index].infatuatedBy {
            if battlers[lover].isFainted || battlers[lover].slot == nil {
                battlers[index].infatuatedBy = nil
            } else if random.below(2) == 0 {
                log(.fail(battler: battlers[index].spec.id, move: slug, reason: .infatuation))
                advance(index, after: slug)
                return
            }
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
        // Grudge holds through the cast that follows it.
        battlers[index].grudge = false
        if slug != "struggle", !canUse(slug, by: index) {
            log(.fail(battler: battlers[index].spec.id, move: slug, reason: .restrained))
            advance(index, after: slug)
            return
        }
        if let move = MoveTable.move(slug) { use(move, by: index) }
        // Gone by its own move (U-turn, Baton Pass): its copy on the bench starts afresh, Fake Out ready.
        guard battlers[index].slot != nil else { return }
        battlers[index].lastActionAt = now
        battlers[index].usedSinceEntry.insert(slug)
        if Self.lockingMoves[slug] != nil, !battlers[index].isFainted { lockStep(index, slug) }
        battlers[index].electrified = false
        battlers[index].helped = false
        if battlers[index].roosting, slug != "roost" { endRoost(index) }
        battlers[index].castsSinceEntry += 1
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
        // Asleep, only Sleep Talk and Snore; awake, never them.
        if b.status == .sleep {
            switch slug {
            case "snore": return !foes.isEmpty
            case "sleep-talk": return !sleepTalkOptions(index).isEmpty
            default: return false
            }
        }
        if Self.sleepMoves.contains(slug) { return false }
        if fieldHas("gravity"), move.flags.contains("gravity") { return false }
        if move.isDamaging {
            if foes.isEmpty { return false }
            if slug == "dream-eater" { return foes.contains { battlers[$0].status == .sleep } }
            if slug == "belch" { return b.consumedBerry != nil }
            if slug == "double-shock" { return b.types.contains(.electric) }
            if slug == "upper-hand" {
                return target(of: move, by: index).flatMap { battlers[$0].castMove.flatMap(MoveTable.move) }.map { $0.priority > 0 } ?? false
            }
            if slug == "fake-out" || slug == "first-impression" { return b.castsSinceEntry == 0 }
            if slug == "spit-up" { return b.stockpile > 0 }
            if slug == "last-resort" { return lastResortReady(index) }
            if slug == "sucker-punch" || slug == "thunderclap" {
                return target(of: move, by: index).flatMap { battlers[$0].castMove.flatMap(MoveTable.move) }?.isDamaging == true
            }
            if slug == "natural-gift" || slug == "fling" { return slug == "natural-gift" && heldBerry(index) != nil }
            if slug == "future-sight" || slug == "doom-desire" {
                // One foreseen attack on a slot at a time.
                guard let foe = facingFoe(index), let slot = battlers[foe].slot else { return false }
                return !futureAttacks.contains { $0.side == battlers[foe].side && $0.slot == slot }
            }
            if ["explosion", "self-destruct", "misty-explosion", "final-gambit"].contains(slug) {
                return allies(of: index).count + bench(b.side).count > 1 || foes.count == 1
            }
            return true
        }
        switch slug {
        case "protect", "detect", "kings-shield", "spiky-shield", "baneful-bunker", "obstruct", "silk-trap",
             "burning-bulwark":
            return !foes.isEmpty
        case "destiny-bond", "endure": return !foes.isEmpty
        case "mat-block": return !foes.isEmpty && b.castsSinceEntry == 0
        case "wide-guard": return foes.contains { foeKnows($0) { $0.isDamaging && $0.hitsAllOpponents } }
        case "quick-guard": return foes.contains { foeKnows($0) { $0.priority > 0 } }
        case "crafty-shield": return foes.contains { foeKnows($0) { !$0.isDamaging && !$0.targetsOwnSide } }
        case "magic-coat": return foes.contains { foeKnows($0) { $0.flags.contains("reflectable") } }
        case "snatch": return foes.contains { foeKnows($0) { $0.flags.contains("snatch") } }
        case "substitute": return b.substituteHP == 0 && b.hp > b.maxHP / 4 && b.maxHP / 4 > 0
        case "reflect": return !sideHas(b.side, slug) && foes.contains { foeKnows($0) { $0.moveClass == .physical } }
        case "light-screen": return !sideHas(b.side, slug) && foes.contains { foeKnows($0) { $0.moveClass == .special } }
        case "aurora-veil": return !sideHas(b.side, slug) && weather == .snow && !foes.isEmpty
        case "safeguard": return !sideHas(b.side, slug) && foes.contains { foeKnows($0) { $0.ailment != nil } }
        case "mist":
            return !sideHas(b.side, slug) && foes.contains { foeKnows($0) { $0.statChanges.contains { $0.change < 0 } } }
        case "tailwind", "lucky-chant": return !sideHas(b.side, slug) && !foes.isEmpty
        case "spikes", "toxic-spikes", "stealth-rock", "sticky-web":
            let most = ["spikes": 3, "toxic-spikes": 2][slug] ?? 1
            return (hazards[1 - b.side][slug] ?? 0) < most && !bench(1 - b.side).isEmpty
        case "trick-room":
            // Only for a side slower than the foes, and never to end it.
            guard !fieldHas(slug), !foes.isEmpty else { return false }
            let mine = allies(of: index).map(effectiveSpeed), theirs = foes.map(effectiveSpeed)
            return mine.reduce(0, +) * theirs.count < theirs.reduce(0, +) * mine.count
        case "gravity":
            return !fieldHas(slug) && b.spec.moves.contains { MoveTable.move($0).map { $0.type == .ground && $0.isDamaging } ?? false }
                && foes.contains { !isGrounded($0) }
        case "magic-room": return !fieldHas(slug) && (berries[1 - b.side].values.reduce(0, +)) > 0
        case "wonder-room": return !fieldHas(slug) && !foes.isEmpty
        case "mud-sport": return !fieldHas(slug) && foes.contains { foeKnows($0) { $0.isDamaging && $0.type == .electric } }
        case "water-sport": return !fieldHas(slug) && foes.contains { foeKnows($0) { $0.isDamaging && $0.type == .fire } }
        case "ion-deluge": return !fieldHas(slug) && foes.contains { foeKnows($0) { $0.isDamaging && $0.type == .normal } }
        case "haze":
            return foes.contains { battlers[$0].stages.values.contains { $0 > 0 } }
                || allies(of: index).contains { battlers[$0].stages.values.contains { $0 < 0 } }
        case "court-change":
            return !hazards[b.side].isEmpty || ["reflect", "light-screen", "aurora-veil", "tailwind"].contains { sideHas(1 - b.side, $0) }
        case "fairy-lock", "spite", "block", "mean-look", "spider-web": return !foes.isEmpty
        case "taunt":
            return target(of: move, by: index).map {
                battlers[$0].tauntedUntil <= now && !["oblivious", "aroma-veil"].contains(battlers[$0].ability)
                    && foeKnows($0) { !$0.isDamaging }
            } ?? false
        case "encore":
            return target(of: move, by: index).map { encoreable($0) } ?? false
        case "disable":
            return target(of: move, by: index).map { t in
                battlers[t].disabledUntil <= now && battlers[t].lastMove.map { battlers[t].spec.moves.contains($0) } ?? false
            } ?? false
        case "torment": return target(of: move, by: index).map { !battlers[$0].tormented } ?? false
        case "imprison":
            return !b.imprisoning && foes.contains { foe in battlers[foe].spec.moves.contains { b.spec.moves.contains($0) } }
        case "heal-block":
            return foes.contains { battlers[$0].healBlockedUntil <= now && foeKnows($0) { $0.flags.contains("heal") } }
        case "embargo":
            return berries[1 - b.side].values.reduce(0, +) > 0
                && target(of: move, by: index).map { battlers[$0].embargoUntil <= now } ?? false
        case "perish-song":
            // Everyone on the field but a boss falls in three turns, its user too: only with more Pokémon left.
            let mine = battlers.filter { $0.side == b.side && !$0.isFainted }.count
            let theirs = battlers.filter { $0.side != b.side && !$0.isFainted }.count
            return b.perishAt == nil && mine > theirs && foes.contains { perishes($0) }
        case "nightmare":
            return target(of: move, by: index).map { battlers[$0].status == .sleep && !battlers[$0].nightmare } ?? false
        case "ingrain": return !b.ingrained
        case "aqua-ring": return !b.aquaRing
        case "foresight", "odor-sleuth":
            return target(of: move, by: index).map { t in
                !battlers[t].identified && (battlers[t].types.contains(.ghost) && b.spec.moves.contains { slug in
                    MoveTable.move(slug).map { $0.isDamaging && ($0.type == .normal || $0.type == .fighting) } ?? false
                } || battlers[t].stage(.evasion) > 0)
            } ?? false
        case "miracle-eye":
            return target(of: move, by: index).map { t in
                !battlers[t].miracleEye && (battlers[t].types.contains(.dark) && b.spec.moves.contains { slug in
                    MoveTable.move(slug).map { $0.isDamaging && $0.type == .psychic } ?? false
                } || battlers[t].stage(.evasion) > 0)
            } ?? false
        case "telekinesis":
            return !fieldHas("gravity") && target(of: move, by: index).map { battlers[$0].telekinesisUntil <= now } ?? false
        case "magnet-rise":
            return !fieldHas("gravity") && !b.ingrained && b.magnetRiseUntil <= now
                && foes.contains { foeKnows($0) { $0.isDamaging && $0.type == .ground } }
        case "curse":
            if b.types.contains(.ghost) {
                return b.hp * 2 > b.maxHP && target(of: move, by: index).map { !battlers[$0].cursed } ?? false
            }
            return b.stage(.attack) < 6 || b.stage(.defense) < 6
        case "grudge": return !b.grudge && !foes.isEmpty
        case "lock-on", "mind-reader":
            return b.lockOn == nil && b.spec.moves.contains { MoveTable.move($0).map { $0.accuracy > 0 && $0.accuracy < 100 } ?? false }
        case "octolock": return target(of: move, by: index).map { battlers[$0].octolockedBy == nil } ?? false
        case "tar-shot": return target(of: move, by: index).map { !battlers[$0].tarred || battlers[$0].stage(.speed) > -6 } ?? false
        case "no-retreat": return !b.noRetreat
        case "stockpile": return b.stockpile < 3
        case "splash", "celebrate", "hold-hands", "happy-hour": return !foes.isEmpty
        case "attract": return target(of: move, by: index).map { falls($0, for: index) } ?? false
        case "captivate": return foes.contains { opposite($0, index) && battlers[$0].stage(.specialAttack) > -6 }
        case "focus-energy": return b.critBoost < 2
        case "laser-focus": return !b.laserFocus && b.spec.moves.contains { MoveTable.move($0)?.isDamaging == true }
        case "dragon-cheer": return allies(of: index).contains { $0 != index && battlers[$0].critBoost == 0 }
        case "shelter": return b.stage(.defense) < 6
        case "victory-dance": return b.stage(.attack) < 6 || b.stage(.speed) < 6
        case "take-heart": return b.status != nil || b.stage(.specialAttack) < 6
        case "powder":
            return target(of: move, by: index).map { t in
                !battlers[t].powdered && !battlers[t].types.contains(.grass) && foeKnows(t) { $0.type == .fire && $0.isDamaging }
            } ?? false
        case "psycho-shift":
            return b.status.map { status in target(of: move, by: index).map { canInflict(status, on: $0) } ?? false } ?? false
        case "doodle":
            return target(of: move, by: index).map { battlers[$0].ability != b.ability && !battlers[$0].ability.isEmpty } ?? false
        case "memento": return b.hp * 4 < b.maxHP && !bench(b.side).isEmpty && !foes.isEmpty
        case "healing-wish", "lunar-dance":
            return b.hp * 4 < b.maxHP && bench(b.side).contains { battlers[$0].hp * 2 < battlers[$0].maxHP || battlers[$0].status != nil }
        case "strength-sap": return b.hp < b.maxHP && target(of: move, by: index).map { battlers[$0].stage(.attack) > -6 } ?? false
        case "purify": return b.hp < b.maxHP && target(of: move, by: index).map { battlers[$0].status != nil } ?? false
        case "jungle-healing", "lunar-blessing":
            return allies(of: index).contains { battlers[$0].hp < battlers[$0].maxHP || battlers[$0].status != nil }
        case "heal-bell", "aromatherapy":
            return battlers.contains { $0.side == b.side && !$0.isFainted && $0.status != nil }
        case "refresh": return [.burn, .poison, .badPoison, .paralysis].contains(b.status)
        case "revival-blessing": return battlers.contains { $0.side == b.side && $0.isFainted }
        case "swallow": return b.stockpile > 0 && b.hp < b.maxHP
        case "trick", "switcheroo":
            return heldBerry(index) == nil && target(of: move, by: index).map { heldBerry($0) != nil } ?? false
        case "bestow", "fling": return false
        case "recycle": return b.consumedBerry != nil && heldBerry(index) == nil
        case "stuff-cheeks": return heldBerry(index) != nil && b.stage(.defense) < 6
        case "teatime": return active.contains { heldBerry($0) != nil && battlers[$0].side == b.side }
        case "corrosive-gas": return foes.contains { heldBerry($0) != nil }
        case "baton-pass":
            return !staysOnField(index) && !bench(b.side).isEmpty && (b.stages.values.reduce(0, +) > 0 || b.substituteHP > 0)
        case "shed-tail":
            return !staysOnField(index) && !bench(b.side).isEmpty && b.hp * 2 > b.maxHP + 1 && b.substituteHP == 0
        case "teleport":
            guard !staysOnField(index) else { return false }
            // Only for a bench member that fares better against the foe in front.
            guard let foe = facingFoe(index) else { return false }
            let mine = BattleMatchup.score(b.spec, against: battlers[foe].spec)
            return bench(b.side).contains { BattleMatchup.score(battlers[$0].spec, against: battlers[foe].spec) > mine }
        case "roar", "whirlwind":
            return target(of: move, by: index).map { t in
                !staysOnField(t) && !bench(battlers[t].side).isEmpty
                    && (battlers[t].stages.values.reduce(0, +) > 0 || battlers[t].substituteHP > 0)
            } ?? false
        case "ally-switch", "follow-me", "rage-powder", "helping-hand": return allies(of: index).count > 1 && !foes.isEmpty
        case "spotlight": return foes.count > 1
        case "after-you": return allies(of: index).contains { $0 != index && battlers[$0].castMove != nil }
        case "quash": return target(of: move, by: index).map { battlers[$0].castMove != nil } ?? false
        case "power-swap", "guard-swap", "heart-swap", "psych-up":
            let stats: [BattleStat] = switch slug {
            case "power-swap": [.attack, .specialAttack]
            case "guard-swap": [.defense, .specialDefense]
            default: BattleStat.allCases
            }
            func sum(_ i: Int) -> Int { stats.reduce(0) { $0 + battlers[i].stage($1) } }
            return target(of: move, by: index).map { sum($0) > sum(index) } ?? false
        case "speed-swap":
            return target(of: move, by: index).map { battlers[$0].spec.stats.speed > b.spec.stats.speed } ?? false
        case "power-split":
            return target(of: move, by: index).map {
                battlers[$0].spec.stats.attack + battlers[$0].spec.stats.specialAttack > b.spec.stats.attack + b.spec.stats.specialAttack
            } ?? false
        case "guard-split":
            return target(of: move, by: index).map {
                battlers[$0].spec.stats.defense + battlers[$0].spec.stats.specialDefense
                    > b.spec.stats.defense + b.spec.stats.specialDefense
            } ?? false
        case "topsy-turvy": return target(of: move, by: index).map { battlers[$0].stages.values.reduce(0, +) > 0 } ?? false
        case "power-trick": return b.spec.stats.defense > b.spec.stats.attack
        case "power-shift":
            return b.spec.stats.defense + b.spec.stats.specialDefense > b.spec.stats.attack + b.spec.stats.specialAttack
        case "acupressure": return BattleStat.allCases.contains { b.stage($0) < 6 }
        case "soak": return target(of: move, by: index).map { battlers[$0].types != [.water] } ?? false
        case "magic-powder": return target(of: move, by: index).map { battlers[$0].types != [.psychic] } ?? false
        case "forests-curse": return target(of: move, by: index).map { !battlers[$0].types.contains(.grass) } ?? false
        case "trick-or-treat": return target(of: move, by: index).map { !battlers[$0].types.contains(.ghost) } ?? false
        case "reflect-type": return target(of: move, by: index).map { battlers[$0].types != b.types } ?? false
        case "conversion":
            return b.spec.moves.first.flatMap(MoveTable.move).map { b.types != [$0.type] } ?? false
        case "conversion-2": return target(of: move, by: index).map { battlers[$0].lastMove != nil } ?? false
        case "camouflage": return !foes.isEmpty && b.types != [camouflageType]
        case "electrify":
            return target(of: move, by: index).map { t in
                !battlers[t].electrified && battlers[t].castMove.flatMap(MoveTable.move).map { $0.isDamaging && $0.type != .electric } ?? false
            } ?? false
        case "simple-beam": return target(of: move, by: index).map { !["simple", "truant"].contains(battlers[$0].ability) } ?? false
        case "worry-seed": return target(of: move, by: index).map { !["insomnia", "truant"].contains(battlers[$0].ability) } ?? false
        case "entrainment", "role-play", "skill-swap":
            return target(of: move, by: index).map { battlers[$0].ability != b.ability && !battlers[$0].ability.isEmpty } ?? false
        case "gastro-acid": return target(of: move, by: index).map { !battlers[$0].ability.isEmpty } ?? false
        case "defog":
            return !hazards[b.side].isEmpty || ["reflect", "light-screen", "aurora-veil"].contains { sideHas(1 - b.side, $0) }
                || foes.contains { battlers[$0].stage(.evasion) > -6 }
        case "tidy-up":
            return !hazards[b.side].isEmpty || b.stage(.attack) < 6 || b.stage(.speed) < 6
        case "pain-split": return pickTarget(for: move, by: index).map { battlers[$0].hp > b.hp } ?? false
        case "transform":
            return !b.transformed && pickTarget(for: move, by: index).map { !battlers[$0].transformed } ?? false
        case "mimic", "sketch":
            guard let learned = pickTarget(for: move, by: index).flatMap({ battlers[$0].lastMove }) else { return false }
            return Self.canBeCalled(learned) && !b.spec.moves.contains(learned)
        case "copycat": return lastMoveUsed.map(Self.canBeCalled) ?? false
        case "mirror-move": return pickTarget(for: move, by: index).flatMap { mirrored(by: $0) } != nil
        case "me-first": return pickTarget(for: move, by: index).flatMap { meFirstMove(of: $0) } != nil
        case "metronome", "nature-power": return !foes.isEmpty
        case "assist": return !foes.isEmpty && !assistOptions(index).isEmpty
        case "instruct": return instructTarget(index) != nil
        case "wish": return b.hp < b.maxHP && !wishes.contains { $0.side == b.side && $0.slot == b.slot }
        case "rest": return b.hp < b.maxHP && b.ability != "insomnia" && b.ability != "vital-spirit"
        case "belly-drum": return b.hp * 2 > b.maxHP && b.stage(.attack) < 6 && b.maxHP > 1
        // Worth it while it is not charged, its Special Defense raised or not.
        case "charge": return !b.charged || b.stage(.specialDefense) < 6
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
            // Nothing lands behind a substitute: the move is skipped.
            return foes.contains { foe in
                !isScreened(foe, from: move, by: index) && !sideHas(battlers[foe].side, "mist")
                    && move.statChanges.contains { battlers[foe].stage($0.stat) > -6 }
            }
        case .ailment, .swagger:
            guard let ailment = move.ailment else { return false }
            return foes.contains {
                canInflict(ailment, on: $0, move: move) && !isScreened($0, from: move, by: index) && !safeguarded($0, from: index)
            }
        default:
            return false
        }
    }

    /// Whether the restraints on the battler let it use `slug` now: Taunt keeps status moves off, Disable and Grudge
    /// one move, Torment the last one, Imprison those its user knows, Heal Block the healing ones, Encore all but one.
    private func canUse(_ slug: String, by index: Int) -> Bool {
        let b = battlers[index]
        guard let move = MoveTable.move(slug) else { return false }
        if b.encoreUntil > now, let encored = b.encoreMove, slug != encored { return false }
        if b.tauntedUntil > now, !move.isDamaging { return false }
        if b.disabledUntil > now, slug == b.disabledMove { return false }
        if b.lostMoves.contains(slug) { return false }
        if b.tormented, slug == b.lastMove { return false }
        // Gigaton Hammer and Blood Moon never twice in a row.
        if slug == b.lastMove, slug == "gigaton-hammer" || slug == "blood-moon" { return false }
        if b.healBlockedUntil > now, move.flags.contains("heal") || Self.statusKind(move) == .heal { return false }
        return !foes(of: index).contains { battlers[$0].imprisoning && battlers[$0].spec.moves.contains(slug) }
    }

    /// Camouflage's type: the terrain's, Normal without one.
    private var camouflageType: PokemonType {
        switch terrain {
        case .electric?: .electric
        case .grassy?: .grass
        case .misty?: .fairy
        case .psychic?: .psychic
        case nil: .normal
        }
    }

    /// The foe standing in front, or the first one standing.
    private func facingFoe(_ index: Int) -> Int? {
        guard let slot = battlers[index].slot else { return foes(of: index).first }
        let opposite = field[1 - battlers[index].side]
        if slot < opposite.count, let facing = opposite[slot], !battlers[facing].isFainted { return facing }
        return foes(of: index).first
    }

    /// The foe a move cast now would aim at.
    private func target(of move: BattleMove, by index: Int) -> Int? { pickTarget(for: move, by: index) }

    /// Whether Encore can hold the target: a last move still in its loop that is not itself a copier or Encore.
    private func encoreable(_ target: Int) -> Bool {
        let t = battlers[target]
        guard t.encoreUntil <= now, let last = t.lastMove, t.spec.moves.contains(last) else { return false }
        return !["encore", "transform", "mimic", "sketch", "struggle", "mirror-move", "sleep-talk", "assist",
                 "metronome", "copycat", "me-first", "instruct"].contains(last)
    }

    /// Whether Perish Song takes this Pokémon: never a boss (the owner, 2026-11-03), nor a Soundproof one.
    private func perishes(_ index: Int) -> Bool {
        !battlers[index].spec.isBoss && battlers[index].ability != "soundproof" && battlers[index].perishAt == nil
    }

    /// Whether a foe's loop holds a move that `matches`: what a guard waits for.
    private func foeKnows(_ foe: Int, _ matches: (BattleMove) -> Bool) -> Bool {
        battlers[foe].spec.moves.contains { MoveTable.move($0).map(matches) ?? false }
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
        if Self.callers.contains(move.slug) {
            call(move, by: index)
            return
        }
        let previousMove = battlers[index].lastMove
        battlers[index].lastMove = move.slug
        lastMoveUsed = move.slug
        // Powdered, a Pokémon whose Fire move goes off takes a quarter of its HP instead.
        if battlers[index].powdered, moveType(move, by: index) == .fire {
            battlers[index].powdered = false
            log(.fail(battler: id, move: move.slug, reason: .failed))
            hurt(index, max(1, battlers[index].maxHP / 4), .ability)
            return
        }
        // A foe waiting with Snatch takes a move its user aims at itself.
        if move.flags.contains("snatch"), move.targetsOwnSide,
           let thief = foes(of: index).first(where: { battlers[$0].snatchUntil > now }) {
            battlers[thief].snatchUntil = 0
            log(.reflect(battler: battlers[thief].spec.id, move: move.slug))
            use(move, by: thief)
            return
        }
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
             "burning-bulwark", "endure", "wide-guard", "quick-guard", "mat-block":
            // One in a row after another protection succeeds a third as often, then a ninth...
            let streak = Self.protectionMoves.contains(previousMove ?? "") ? battlers[index].protectStreak + 1 : 0
            guard random.below(Int(pow(3, Double(min(streak, 6))))) == 0 else {
                battlers[index].protectStreak = 0
                log(.fail(battler: id, move: move.slug, reason: .failed))
                return
            }
            battlers[index].protectStreak = streak
            switch move.slug {
            case "endure": battlers[index].enduringUntil = now + 1500
            case "wide-guard", "quick-guard", "mat-block": sideGuards[battlers[index].side][move.slug] = now + 1500
            default:
                battlers[index].protectedUntil = now + 1500
                battlers[index].protection = move.slug
            }
            return
        case "crafty-shield":
            sideGuards[battlers[index].side][move.slug] = now + 1500
            return
        case "magic-coat":
            battlers[index].magicCoatUntil = now + 1500
            return
        case "snatch":
            battlers[index].snatchUntil = now + 1500
            return
        case "substitute":
            // A quarter of nothing (Shedinja) makes no substitute.
            guard battlers[index].substituteHP == 0, battlers[index].hp > battlers[index].maxHP / 4, battlers[index].maxHP / 4 > 0 else {
                log(.fail(battler: id, move: move.slug, reason: .failed))
                return
            }
            hurt(index, battlers[index].maxHP / 4, .substitute)
            battlers[index].substituteHP = battlers[index].maxHP / 4
            log(.substitute(battler: id, hp: battlers[index].substituteHP))
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
            battlers[index].castMove = nil
            log(.status(battler: id, ailment: .sleep))
            return
        case "belly-drum":
            // Showdown's rule: half of 1 HP is nothing to pay.
            guard battlers[index].maxHP > 1 else { return failed(move, by: index) }
            hurt(index, battlers[index].maxHP / 2, .belly)
            if !battlers[index].isFainted { changeStage(index, .attack, by: 12, fromFoe: false) }
            return
        case "pain-split":
            painSplit(move, by: index)
            return
        case "transform":
            guard let target = statusTargets(move, by: index).first, !battlers[target].transformed,
                  !battlers[index].transformed else {
                log(.fail(battler: id, move: move.slug, reason: .failed))
                return
            }
            transform(index, into: target)
            // The copied loop starts from its first move once this cast's end moves the index on.
            battlers[index].moveIndex = -1
            return
        case "mimic", "sketch":
            // The target's last move takes this one's place in the loop for the rest of the battle.
            guard let target = statusTargets(move, by: index).first, let learned = battlers[target].lastMove,
                  Self.canBeCalled(learned), !battlers[index].spec.moves.contains(learned),
                  let slot = battlers[index].spec.moves.firstIndex(of: move.slug) else {
                log(.fail(battler: id, move: move.slug, reason: .failed))
                return
            }
            battlers[index].spec.moves[slot] = learned
            log(.learn(battler: id, move: learned))
            return
        case "taunt", "encore", "disable", "torment", "embargo", "nightmare", "foresight", "odor-sleuth", "miracle-eye",
             "telekinesis", "octolock", "lock-on", "mind-reader", "tar-shot", "spite", "block", "mean-look", "spider-web",
             "curse", "heal-block":
            restrain(move, by: index)
            return
        case "imprison", "ingrain", "aqua-ring", "magnet-rise", "grudge":
            let effects: [String: WritableKeyPath<Battler, Bool>] = ["imprison": \.imprisoning, "ingrain": \.ingrained,
                                                                      "aqua-ring": \.aquaRing, "grudge": \.grudge]
            if move.slug == "magnet-rise" {
                guard !fieldHas("gravity"), !battlers[index].ingrained else { return failed(move, by: index) }
                battlers[index].magnetRiseUntil = now + 5 * BattleRules.turn
            } else if let path = effects[move.slug] {
                guard !battlers[index][keyPath: path] else { return failed(move, by: index) }
                battlers[index][keyPath: path] = true
            }
            log(.volatile(battler: id, effect: move.slug))
            return
        case "power-swap", "guard-swap", "heart-swap", "speed-swap", "power-split", "guard-split", "psych-up",
             "topsy-turvy", "soak", "magic-powder", "conversion-2", "reflect-type", "forests-curse", "trick-or-treat",
             "electrify", "simple-beam", "worry-seed", "entrainment", "role-play", "skill-swap", "gastro-acid":
            swap(move, by: index)
            return
        case "power-trick", "power-shift", "acupressure", "conversion", "camouflage":
            selfSwap(move, by: index)
            return
        case "trick", "switcheroo", "bestow":
            // One of the two holds a berry: it changes hands.
            guard let aim = statusTargets(move, by: index).first,
                  let (target, source) = statusLands(move, by: index, on: aim) else { return }
            let mine = heldBerry(source), theirs = heldBerry(target)
            if move.slug != "bestow", let berry = theirs, mine == nil, battlers[target].ability != "sticky-hold" {
                _ = takeBerry(target, by: source)
                giveBerry(berry, to: source)
            } else if let berry = mine, theirs == nil {
                _ = takeBerry(source, by: target)
                giveBerry(berry, to: target)
            } else {
                failed(move, by: index)
            }
            return
        case "recycle":
            guard let berry = battlers[index].consumedBerry, heldBerry(index) == nil else { return failed(move, by: index) }
            battlers[index].consumedBerry = nil
            giveBerry(berry, to: index)
            return
        case "stuff-cheeks":
            guard let berry = takeBerry(index, by: index) else { return failed(move, by: index) }
            eat(berry, by: index)
            changeStage(index, .defense, by: 2, fromFoe: false)
            return
        case "teatime":
            for other in active { if let berry = takeBerry(other, by: other) { eat(berry, by: other) } }
            return
        case "corrosive-gas":
            for other in active where other != index { _ = takeBerry(other, by: nil) }
            return
        case "baton-pass", "teleport":
            if !switchOut(index, baton: move.slug == "baton-pass") { failed(move, by: index) }
            return
        case "shed-tail":
            // Half its HP for a substitute a quarter strong, left to the Pokémon that comes in.
            let cost = (battlers[index].maxHP + 1) / 2
            guard battlers[index].hp > cost, !bench(battlers[index].side).isEmpty, !staysOnField(index) else {
                return failed(move, by: index)
            }
            hurt(index, cost, .substitute)
            if !battlers[index].isFainted { _ = switchOut(index, substitute: battlers[index].maxHP / 4) }
            return
        case "parting-shot":
            let lands = statusTargets(move, by: index).first.map {
                !isProtected($0, from: move) && !isScreened($0, from: move, by: index) && !reflects($0, move, by: index)
            } ?? false
            useStatus(move, by: index)
            if lands, !battlers[index].isFainted { _ = switchOut(index) }
            return
        case "roar", "whirlwind":
            guard let target = statusTargets(move, by: index).first,
                  let (victim, _) = statusLands(move, by: index, on: target) else { return }
            if !forceOut(victim) { failed(move, by: index) }
            return
        case "ally-switch":
            guard let slot = battlers[index].slot,
                  let partner = allies(of: index).first(where: { $0 != index }), let other = battlers[partner].slot else {
                return failed(move, by: index)
            }
            let side = battlers[index].side
            field[side][slot] = partner
            field[side][other] = index
            battlers[index].slot = other
            battlers[partner].slot = slot
            log(.volatile(battler: id, effect: move.slug))
            return
        case "follow-me", "rage-powder":
            battlers[index].centerUntil = now + 1500
            battlers[index].ragePowder = move.slug == "rage-powder"
            log(.volatile(battler: id, effect: move.slug))
            return
        case "spotlight", "after-you", "quash", "helping-hand":
            // Helping Hand and After You go to the ally beside, After You to one that is casting.
            let aimed: Int? = switch move.slug {
            case "helping-hand": allies(of: index).first { $0 != index }
            case "after-you": allies(of: index).first { $0 != index && battlers[$0].castMove != nil }
            default: statusTargets(move, by: index).first
            }
            guard let target = aimed else { return failed(move, by: index, .noTarget) }
            switch move.slug {
            case "spotlight":
                battlers[target].centerUntil = now + 1500
                battlers[target].ragePowder = false
            case "after-you":
                // It acts at once: its cast ends now.
                guard battlers[target].castMove != nil else { return failed(move, by: index) }
                battlers[target].castEnds = now
            case "quash":
                // It acts last: its cast starts again.
                guard let slug = battlers[target].castMove else { return failed(move, by: index) }
                battlers[target].castEnds = now + castDuration(slug, by: target)
            default:
                battlers[target].helped = true
            }
            log(.volatile(battler: battlers[target].spec.id, effect: move.slug))
            return
        case "perish-song":
            for other in active where perishes(other) {
                battlers[other].perishAt = now + 3 * BattleRules.turn
                log(.volatile(battler: battlers[other].spec.id, effect: move.slug))
            }
            return
        case "memento":
            // The foe's attacks fall by two, and the user faints.
            guard let aim = statusTargets(move, by: index).first,
                  let (target, _) = statusLands(move, by: index, on: aim) else { return }
            changeStage(target, .attack, by: -2, fromFoe: true)
            changeStage(target, .specialAttack, by: -2, fromFoe: true)
            hurt(index, battlers[index].hp, .recoil)
            return
        case "healing-wish", "lunar-dance":
            // The user faints; the next to step into its place comes in whole and cured.
            guard let slot = battlers[index].slot, !bench(battlers[index].side).isEmpty else { return failed(move, by: index) }
            healingWishes.insert([battlers[index].side, slot])
            hurt(index, battlers[index].hp, .recoil)
            return
        case "strength-sap":
            // It heals by the target's Attack, which then falls by one.
            guard let aim = statusTargets(move, by: index).first,
                  let (target, _) = statusLands(move, by: index, on: aim), battlers[target].stage(.attack) > -6 else {
                return failed(move, by: index)
            }
            let attack = Double(battlers[target].spec.stats.attack) * stageMultiplier(battlers[target].stage(.attack))
            changeStage(target, .attack, by: -1, fromFoe: true)
            heal(index, Int(attack), .move)
            return
        case "purify":
            guard let aim = statusTargets(move, by: index).first,
                  let (target, _) = statusLands(move, by: index, on: aim), battlers[target].status != nil else {
                return failed(move, by: index)
            }
            cure(target)
            heal(index, battlers[index].maxHP / 2, .move)
            return
        case "jungle-healing", "lunar-blessing":
            for ally in allies(of: index) {
                heal(ally, battlers[ally].maxHP / 4, .move)
                cure(ally)
            }
            return
        case "heal-bell", "aromatherapy":
            // Every status of the side goes, the bench's too.
            for member in battlers.indices where battlers[member].side == battlers[index].side && !battlers[member].isFainted {
                cure(member)
            }
            return
        case "refresh":
            guard [.burn, .poison, .badPoison, .paralysis].contains(battlers[index].status) else { return failed(move, by: index) }
            cure(index)
            return
        case "roost":
            heal(index, battlers[index].maxHP / 2, .move)
            if battlers[index].types.contains(.flying) {
                battlers[index].roosting = true
                battlers[index].types = battlers[index].types.count == 1 ? [.normal] : battlers[index].types.filter { $0 != .flying }
                log(.retype(battler: id, types: battlers[index].types))
            }
            return
        case "revival-blessing":
            // A fainted Pokémon of the side comes back to its bench at half its HP.
            guard let fallen = battlers.indices.first(where: { battlers[$0].side == battlers[index].side && battlers[$0].isFainted })
            else { return failed(move, by: index) }
            let old = battlers[fallen]
            let spec = old.originalSpec ?? old.spec
            var revived = Battler(spec: spec, side: old.side, hp: max(1, spec.stats.hp / 2), types: spec.types,
                                  originalSpec: old.originalSpec)
            revived.lostMoves = old.lostMoves
            battlers[fallen] = revived
            // A place left to a fallen Pokémon, with no bench then, takes the next one in: its own, or another's.
            for slot in field[old.side].indices {
                guard let occupant = field[old.side][slot], occupant == fallen || battlers[occupant].isFainted else { continue }
                field[old.side][slot] = nil
                if !pendingEntries.contains(where: { $0.side == old.side && $0.slot == slot }) {
                    pendingEntries.append((now + BattleRules.benchDelay, old.side, slot))
                }
            }
            log(.heal(battler: revived.spec.id, amount: revived.hp, hp: revived.hp, cause: .move))
            return
        case "attract":
            guard let aim = statusTargets(move, by: index).first,
                  let (target, source) = statusLands(move, by: index, on: aim) else { return }
            guard falls(target, for: source) else { return failed(move, by: index) }
            battlers[target].infatuatedBy = source
            log(.volatile(battler: battlers[target].spec.id, effect: move.slug))
            return
        case "splash", "celebrate", "hold-hands", "happy-hour":
            // Nothing happens, as in the games.
            return failed(move, by: index, .nothing)
        case "focus-energy":
            guard battlers[index].critBoost < 2 else { return failed(move, by: index) }
            battlers[index].critBoost = 2
            log(.volatile(battler: id, effect: move.slug))
            return
        case "laser-focus":
            battlers[index].laserFocus = true
            log(.volatile(battler: id, effect: move.slug))
            return
        case "dragon-cheer":
            for ally in allies(of: index) where ally != index && battlers[ally].critBoost == 0 {
                battlers[ally].critBoost = battlers[ally].types.contains(.dragon) ? 2 : 1
                log(.volatile(battler: battlers[ally].spec.id, effect: move.slug))
            }
            return
        case "shelter":
            changeStage(index, .defense, by: 2, fromFoe: false)
            return
        case "victory-dance":
            for stat in [BattleStat.attack, .defense, .speed] { changeStage(index, stat, by: 1, fromFoe: false) }
            return
        case "take-heart":
            cure(index)
            changeStage(index, .specialAttack, by: 1, fromFoe: false)
            changeStage(index, .specialDefense, by: 1, fromFoe: false)
            return
        case "powder", "psycho-shift", "doodle":
            guard let aim = statusTargets(move, by: index).first,
                  let (target, source) = statusLands(move, by: index, on: aim) else { return }
            switch move.slug {
            case "powder":
                guard !battlers[target].types.contains(.grass), battlers[target].ability != "overcoat" else {
                    return failed(move, by: index)
                }
                battlers[target].powdered = true
                log(.volatile(battler: battlers[target].spec.id, effect: move.slug))
            case "psycho-shift":
                // Its own status moves onto the target.
                guard let status = battlers[source].status, canInflict(status, on: target) else { return failed(move, by: index) }
                cure(source)
                inflict(status, on: target, by: source)
            default:
                for ally in allies(of: source) { setAbility(ally, battlers[target].ability) }
            }
            return
        case "stockpile":
            guard battlers[index].stockpile < 3 else { return failed(move, by: index) }
            battlers[index].stockpile += 1
            changeStage(index, .defense, by: 1, fromFoe: false)
            changeStage(index, .specialDefense, by: 1, fromFoe: false)
            log(.volatile(battler: id, effect: move.slug))
            return
        case "swallow":
            // A quarter, half or all of the HP back by the Stockpile, which is then spent.
            let stored = battlers[index].stockpile
            guard stored > 0 else { return failed(move, by: index) }
            heal(index, battlers[index].maxHP * [0, 1, 2, 4][stored] / 4, .move)
            releaseStockpile(index)
            return
        case "no-retreat":
            guard !battlers[index].noRetreat else { return failed(move, by: index) }
            battlers[index].noRetreat = true
            useStatus(move, by: index)
            return
        case "instruct":
            // The ally uses its last move again at once, its own cast going on.
            guard let ally = instructTarget(index), let slug = battlers[ally].lastMove, let repeated = MoveTable.move(slug)
            else {
                log(.fail(battler: id, move: move.slug, reason: .failed))
                return
            }
            log(.call(battler: battlers[ally].spec.id, move: slug))
            use(repeated, by: ally)
            return
        default:
            break
        }
        if fieldHas("gravity"), move.flags.contains("gravity") {
            log(.fail(battler: id, move: move.slug, reason: .failed))
            return
        }
        if fieldMove(move, by: index) { return }
        if move.slug == "defense-curl" { battlers[index].defenseCurl = true }
        if move.slug == "charge" { battlers[index].charged = true }
        if move.slug == "minimize" { battlers[index].minimized = true }
        if move.slug == "autotomize" { battlers[index].autotomized += 1 }
        if !move.isDamaging {
            useStatus(move, by: index)
            return
        }
        // A charge goes with the Electric move it doubles, whatever that move does.
        let spendsCharge = battlers[index].charged && moveType(move, by: index) == .electric
        defer { if spendsCharge { battlers[index].charged = false } }
        let targets: [Int]
        if Self.reactiveMoves[move.slug] != nil {
            // Counter and its kin answer the foe that hit last, whoever stands in front; nothing taken, nothing sent.
            guard let answer = reactiveStrike(move, by: index) else {
                log(.fail(battler: id, move: move.slug, reason: .failed))
                return
            }
            // A hit is answered once, whether the answer lands or not; Bide answers every hit it stored.
            if answer.physical != false { battlers[index].lastPhysicalHit = nil }
            if answer.physical != true { battlers[index].lastSpecialHit = nil }
            if answer.physical == nil { battlers[index].bideTaken = 0 }
            battlers[index].answering = answer.damage
            targets = [answer.target]
        } else if move.hitsAllOpponents {
            targets = foes(of: index)
        } else if let target = battlers[index].castTarget, !battlers[target].isFainted, battlers[target].slot != nil {
            targets = [redirected(target, move, by: index)]
        } else if let target = pickTarget(for: move, by: index) {
            targets = [redirected(target, move, by: index)]
        } else {
            log(.fail(battler: id, move: move.slug, reason: .noTarget))
            return
        }
        if move.slug == "fling" || move.slug == "natural-gift" {
            // They use the berry held, gone even if they miss; nothing to use, nothing happens.
            guard !fieldHas("magic-room"), battlers[index].embargoUntil <= now,
                  let berry = takeBerry(index, by: nil) else {
                log(.fail(battler: id, move: move.slug, reason: .failed))
                return
            }
            battlers[index].throwing = berry
        }
        defer { battlers[index].throwing = nil }
        if move.slug == "future-sight" || move.slug == "doom-desire" {
            // Foreseen: it lands two turns later on whoever then stands in the target's place.
            guard let target = targets.first, let slot = battlers[target].slot else { return }
            futureAttacks.append((now + 2 * BattleRules.turn, battlers[target].side, slot, index, move.slug))
            log(.volatile(battler: battlers[target].spec.id, effect: move.slug))
            return
        }
        switch move.slug {
        case "fake-out", "first-impression":
            // Only as the first move after entering.
            if battlers[index].castsSinceEntry > 0 { return failed(move, by: index) }
        case "sucker-punch", "thunderclap":
            // Only against a foe about to attack.
            if let target = targets.first, battlers[target].castMove.flatMap(MoveTable.move)?.isDamaging != true {
                return failed(move, by: index)
            }
        case "focus-punch":
            // Hit while it gathered its focus, it loses it.
            if battlers[index].lastDamagedAt >= battlers[index].castStartedAt {
                return failed(move, by: index)
            }
        case "last-resort":
            if !lastResortReady(index) { return failed(move, by: index) }
        case "double-shock":
            if !battlers[index].types.contains(.electric) { return failed(move, by: index) }
        case "upper-hand":
            // Only against a foe casting a priority move.
            if let target = targets.first, (battlers[target].castMove.flatMap(MoveTable.move)?.priority ?? 0) <= 0 {
                return failed(move, by: index)
            }
        case "fickle-beam":
            battlers[index].rolledPower = random.chance(30) ? 160 : 80
        case "spit-up":
            if battlers[index].stockpile == 0 { return failed(move, by: index) }
        case "magnitude":
            // Magnitude 4 to 10: 5, 10, 20, 30, 20, 10, 5 in 100.
            let roll = random.below(100)
            let steps: [(Int, Double)] = [(5, 10), (15, 30), (35, 50), (65, 70), (85, 90), (95, 110), (100, 150)]
            battlers[index].rolledPower = steps.first { roll < $0.0 }?.1 ?? 70
        case "present":
            // 40, 80 or 120 power, or a quarter of the target's HP healed (40, 30, 10, 20 in 100).
            let roll = random.below(100)
            if roll >= 80 {
                if let target = targets.first { heal(target, battlers[target].maxHP / 4, .move) }
                return
            }
            battlers[index].rolledPower = roll < 40 ? 40 : roll < 70 ? 80 : 120
        case "beat-up":
            // One hit for each Pokémon of the side standing without a status, by its base Attack.
            guard let target = targets.first else { return }
            let side = battlers[index].side
            for member in battlers.indices where battlers[member].side == side && !battlers[member].isFainted
                && battlers[member].status == nil && !battlers[target].isFainted {
                let base = SpeciesBattleTable.data(speciesID: battlers[member].spec.speciesID)?.baseStats[1] ?? 50
                battlers[index].rolledPower = 5 + Double(base) / 10
                _ = strike(move, by: index, on: target, spread: false)
            }
            battlers[index].rolledPower = nil
            return
        default:
            break
        }
        defer { battlers[index].rolledPower = nil }
        // Fury Cutter and Echoed Voice grow with each one that landed just before.
        battlers[index].streak = previousMove == move.slug && battlers[index].lastLanded ? battlers[index].streak + 1 : 0
        if move.slug == "endeavor", let target = targets.first, battlers[target].hp <= battlers[index].hp {
            log(.fail(battler: id, move: move.slug, reason: .failed))
            return
        }
        let spread = targets.count > 1
        var dealtTotal = 0
        for target in targets where !battlers[target].isFainted && !battlers[index].isFainted {
            let dealt = strike(move, by: index, on: target, spread: spread)
            dealtTotal += dealt
            if dealt > 0 { berryAfterHit(move, by: index, on: target) }
        }
        battlers[index].answering = nil
        battlers[index].lastLanded = dealtTotal > 0
        // Chloroblast, Steel Beam and Mind Blown cost half the HP, landed or not; a Jump Kick that does not land costs
        // its user half its HP.
        if ["chloroblast", "steel-beam", "mind-blown"].contains(move.slug), battlers[index].ability != "magic-guard" {
            hurt(index, (battlers[index].maxHP + 1) / 2, .recoil)
        }
        if Self.crashMoves.contains(move.slug), dealtTotal == 0, battlers[index].ability != "magic-guard" {
            hurt(index, battlers[index].maxHP / 2, .recoil)
        }
        if move.slug == "glaive-rush", !battlers[index].isFainted { battlers[index].exposed = true }
        if ["explosion", "self-destruct", "misty-explosion"].contains(move.slug)
            || move.slug == "final-gambit" && dealtTotal > 0 {
            hurt(index, battlers[index].hp, .recoil)
            return
        }
        guard !battlers[index].isFainted, dealtTotal > 0 else { return }
        defer {
            // U-turn, Volt Switch and Flip Turn take their user out after the hit; Dragon Tail and Circle Throw the
            // target, if it stands and nothing screened it.
            if ["u-turn", "volt-switch", "flip-turn"].contains(move.slug), !battlers[index].isFainted { _ = switchOut(index) }
            if ["dragon-tail", "circle-throw"].contains(move.slug), let target = targets.first, !battlers[target].isFainted,
               battlers[target].slot != nil {
                _ = forceOut(target)
            }
        }
        if move.slug == "rapid-spin" || move.slug == "mortal-spin" { spinAway(index) }
        if move.slug == "spit-up" { releaseStockpile(index) }
        recentMoveAfterHit(move, by: index, targets: targets)
        if move.slug == "smack-down" || move.slug == "thousand-arrows" {
            for target in targets where !battlers[target].isFainted && !isGrounded(target) {
                battlers[target].smackedDown = true
                battlers[target].magnetRiseUntil = 0
                battlers[target].telekinesisUntil = 0
                log(.volatile(battler: battlers[target].spec.id, effect: "smack-down"))
            }
        }
        if move.slug == "mortal-spin" {
            for target in targets where !battlers[target].isFainted { inflict(.poison, on: target, by: index, move: move) }
        }
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
        if Self.protectionBreakers.contains(move.slug) { liftProtections(target) }
        if isProtected(target, from: move) {
            log(.fail(battler: attackerID, move: move.slug, reason: .protected))
            if move.isContact, battlers[target].protectedUntil > now { punishContact(index, on: target) }
            return 0
        }
        let screened = isScreened(target, from: move, by: index)
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
            if screened {
                let taken = battlers[target].substituteHP
                battlers[target].substituteHP = 0
                log(.substitute(battler: targetID, hp: 0))
                return taken
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
        if Self.screenBreakers.contains(move.slug) {
            for screen in ["reflect", "light-screen", "aurora-veil"] { endSideCondition(battlers[target].side, screen) }
        }
        var count = 1
        // Beat Up's hits are its side's members, one strike each (PokéAPI gives it six).
        if move.maxHits > 1, move.slug != "beat-up" {
            if battlers[index].ability == "skill-link" || move.minHits == move.maxHits {
                count = move.maxHits
            } else if move.minHits == 2, move.maxHits == 5 {
                count = [2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5][random.below(20)]
            } else {
                count = random.between(move.minHits, move.maxHits)
            }
        }
        var dealt = 0
        for hit in 0..<count where !battlers[target].isFainted {
            // Triple Kick, Triple Axel and Population Bomb roll each hit after the first, stopping on a miss; the
            // Triples grow with each.
            if hit > 0, Self.eachHitRolled.contains(move.slug), !hits(move, by: index, on: target) { break }
            if move.slug == "triple-kick" || move.slug == "triple-axel" { battlers[index].rolledPower = Double(move.power * (hit + 1)) }
            let critical = rollsCritical(move, by: index, on: target)
            let damage = damageFor(move, by: index, on: target, spread: spread, critical: critical, typeFactor: typeFactor)
            // The substitute takes the hits while it stands; the hits after it breaks reach the Pokémon.
            if screened, battlers[target].substituteHP > 0 {
                let taken = min(damage, battlers[target].substituteHP)
                battlers[target].substituteHP -= taken
                dealt += taken
                log(.substitute(battler: targetID, hp: battlers[target].substituteHP))
                continue
            }
            dealt += min(damage, battlers[target].hp)
            dealDamage(damage, to: target, by: index, move: move, effectiveness: typeFactor, critical: critical)
            if battlers[target].isFainted { break }
            contactEffects(move, attacker: index, target: target)
            if battlers[index].isFainted { return dealt }
        }
        if !battlers[target].isFainted, !screened { secondaryEffects(move, by: index, on: target) }
        return dealt
    }

    /// Whether a protection stops `move` against `target`: its own (Protect and kin; King's Shield, Obstruct, Silk
    /// Trap and Burning Bulwark only against damage), or its side's guard for the moves it guards against.
    private func isProtected(_ target: Int, from move: BattleMove) -> Bool {
        guard move.isBlockedByProtect, !Self.protectionBreakers.contains(move.slug), !resolvingFuture,
              move.slug != "hyper-drill", move.slug != "mighty-cleave" else { return false }
        let t = battlers[target]
        if t.protectedUntil > now, move.isDamaging || !Self.damageOnlyShields.contains(t.protection ?? "") { return true }
        let guards = sideGuards[t.side]
        func holds(_ guardMove: String) -> Bool { (guards[guardMove] ?? 0) > now }
        return holds("wide-guard") && move.hitsAllOpponents || holds("quick-guard") && move.priority > 0
            || holds("mat-block") && move.isDamaging || holds("crafty-shield") && !move.isDamaging
    }

    /// Feint, Shadow Force, Phantom Force and Hyperspace Hole go through protections and lift them.
    private mutating func liftProtections(_ target: Int) {
        battlers[target].protectedUntil = 0
        battlers[target].protection = nil
        for guardMove in ["wide-guard", "quick-guard", "mat-block", "crafty-shield"] {
            sideGuards[battlers[target].side][guardMove] = nil
        }
    }

    /// A contact move stopped by a shield: King's Shield lowers the attacker's Attack, Spiky Shield hurts it, Baneful
    /// Bunker poisons it, Obstruct lowers its Defense, Silk Trap its Speed, Burning Bulwark burns it.
    private mutating func punishContact(_ index: Int, on target: Int) {
        switch battlers[target].protection {
        case "kings-shield": changeStage(index, .attack, by: -1, fromFoe: true)
        case "spiky-shield":
            if battlers[index].ability != "magic-guard" { hurt(index, max(1, battlers[index].maxHP / 8), .protection) }
        case "baneful-bunker": inflict(.poison, on: index, by: target)
        case "obstruct": changeStage(index, .defense, by: -2, fromFoe: true)
        case "silk-trap": changeStage(index, .speed, by: -1, fromFoe: true)
        case "burning-bulwark": inflict(.burn, on: index, by: target)
        default: break
        }
    }

    /// Whether `target`'s substitute takes `move`: sound moves, those that ignore it and an Infiltrator go through.
    private func isScreened(_ target: Int, from move: BattleMove, by index: Int) -> Bool {
        battlers[target].substituteHP > 0 && !move.bypassesSubstitute && battlers[index].ability != "infiltrator"
            && battlers[target].side != battlers[index].side
    }

    /// Magic Coat (for its time) and Magic Bounce send a reflectable status move back, unless a Mold Breaker uses it.
    private func reflects(_ target: Int, _ move: BattleMove, by index: Int) -> Bool {
        guard move.flags.contains("reflectable"), battlers[target].side != battlers[index].side else { return false }
        let bounce = battlers[target].ability == "magic-bounce"
            && !["mold-breaker", "teravolt", "turboblaze"].contains(battlers[index].ability)
        return battlers[target].magicCoatUntil > now || bounce
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
                heal(ally, battlers[ally].maxHP * max(25, healShare(move)) / 100, .move)
            }
        case .netGoodStats:
            if move.targetsOwnSide {
                for change in move.statChanges { changeStage(index, change.stat, by: change.change, fromFoe: false) }
            } else {
                for target in statusTargets(move, by: index) {
                    guard let (victim, source) = statusLands(move, by: index, on: target) else { continue }
                    // Captivate only charms the opposite gender.
                    if move.slug == "captivate", !opposite(victim, source) {
                        log(.noEffect(attacker: battlers[source].spec.id, target: battlers[victim].spec.id, move: move.slug))
                        continue
                    }
                    guard hits(move, by: source, on: victim) else {
                        log(.miss(attacker: battlers[source].spec.id, target: battlers[victim].spec.id, move: move.slug))
                        continue
                    }
                    for change in move.statChanges { changeStage(victim, change.stat, by: change.change, fromFoe: true) }
                }
            }
        case .ailment, .swagger:
            guard let ailment = move.ailment else { return }
            for target in statusTargets(move, by: index) {
                guard let (target, source) = statusLands(move, by: index, on: target) else { continue }
                let sourceID = battlers[source].spec.id
                if move.isPowder, battlers[target].types.contains(.grass) || battlers[target].ability == "overcoat" {
                    log(.noEffect(attacker: sourceID, target: battlers[target].spec.id, move: move.slug))
                    continue
                }
                if move.type == .electric, ailment == .paralysis, battlers[target].types.contains(.ground) {
                    log(.noEffect(attacker: sourceID, target: battlers[target].spec.id, move: move.slug))
                    continue
                }
                guard hits(move, by: source, on: target) else {
                    log(.miss(attacker: sourceID, target: battlers[target].spec.id, move: move.slug))
                    continue
                }
                if move.category == .swagger {
                    for change in move.statChanges { changeStage(target, change.stat, by: change.change, fromFoe: true) }
                }
                inflict(ailment, on: target, by: source, move: move)
            }
        default:
            log(.fail(battler: id, move: move.slug, reason: .failed))
        }
    }

    /// Where a status move aimed at `target` lands, and from whom: nowhere behind a protection or a substitute,
    /// back on its user off a Magic Coat.
    private mutating func statusLands(_ move: BattleMove, by index: Int, on target: Int) -> (victim: Int, source: Int)? {
        let id = battlers[index].spec.id
        if isProtected(target, from: move) {
            log(.fail(battler: id, move: move.slug, reason: .protected))
            return nil
        }
        if reflects(target, move, by: index) {
            log(.reflect(battler: battlers[target].spec.id, move: move.slug))
            return (index, target)
        }
        if isScreened(target, from: move, by: index) {
            log(.fail(battler: id, move: move.slug, reason: .substitute))
            return nil
        }
        // Wind Rider takes a wind move aimed at it, Whirlwind too, and raises its Attack.
        if battlers[target].ability == "wind-rider", move.isWind, battlers[target].side != battlers[index].side,
           !["mold-breaker", "teravolt", "turboblaze"].contains(battlers[index].ability) {
            log(.ability(battler: battlers[target].spec.id, ability: "wind-rider"))
            changeStage(target, .attack, by: 1, fromFoe: false)
            return nil
        }
        return (target, index)
    }

    private func statusTargets(_ move: BattleMove, by index: Int) -> [Int] {
        if move.hitsAllOpponents { return foes(of: index) }
        if let target = battlers[index].castTarget, !battlers[target].isFainted, battlers[target].slot != nil {
            return [redirected(target, move, by: index)]
        }
        return pickTarget(for: move, by: index).map { [redirected($0, move, by: index)] } ?? []
    }

    /// A single-target move at a foe goes to the foe drawing attention: Follow Me, Rage Powder (not for a Grass type
    /// or an Overcoat), Spotlight. Stalwart and Propeller Tail aim where they meant to.
    private func redirected(_ target: Int, _ move: BattleMove, by index: Int) -> Int {
        guard battlers[target].side != battlers[index].side, !move.hitsAllOpponents, !move.targetsOwnSide,
              !["stalwart", "propeller-tail"].contains(battlers[index].ability) else { return target }
        let immuneToPowder = battlers[index].types.contains(.grass) || battlers[index].ability == "overcoat"
        return allies(of: target).first {
            battlers[$0].centerUntil > now && !(battlers[$0].ragePowder && immuneToPowder)
        } ?? target
    }

    /// Pain Split shares the user's and the target's HP evenly; a boss loses at most an eighth of its HP to it, the user
    /// still gets the average.
    private mutating func painSplit(_ move: BattleMove, by index: Int) {
        let id = battlers[index].spec.id
        guard let target = statusTargets(move, by: index).first else {
            log(.fail(battler: id, move: move.slug, reason: .noTarget))
            return
        }
        if isProtected(target, from: move) {
            log(.fail(battler: id, move: move.slug, reason: .protected))
            return
        }
        if isScreened(target, from: move, by: index) {
            log(.fail(battler: id, move: move.slug, reason: .substitute))
            return
        }
        let mine = battlers[index].hp, theirs = battlers[target].hp
        let average = (mine + theirs) / 2
        var loss = theirs - average
        if battlers[target].spec.isBoss { loss = min(loss, battlers[target].maxHP / 8) }
        if loss > 0 { hurt(target, loss, .painSplit) } else { heal(target, -loss, .painSplit) }
        if average > mine { heal(index, average - mine, .painSplit) } else { hurt(index, mine - average, .painSplit) }
    }

    // MARK: Restraints

    private mutating func failed(_ move: BattleMove, by index: Int, _ reason: BattleFailReason = .failed) {
        log(.fail(battler: battlers[index].spec.id, move: move.slug, reason: reason))
    }

    /// The moves that hold one foe: Taunt and Encore (three turns), Disable (four), Heal Block and Embargo (five),
    /// Torment, Nightmare, Foresight, Miracle Eye, Telekinesis (three), Octolock, Lock-On, Tar Shot, Curse. Spite takes
    /// PP and Block, Mean Look and Spider Web keep a Pokémon in: nothing of the kind here.
    private mutating func restrain(_ move: BattleMove, by index: Int) {
        let turn = BattleRules.turn
        if ["spite", "block", "mean-look", "spider-web"].contains(move.slug) { return failed(move, by: index, .nothing) }
        if move.slug == "curse", !battlers[index].types.contains(.ghost) {
            // Not a Ghost: Speed down, Attack and Defense up.
            changeStage(index, .speed, by: -1, fromFoe: false)
            changeStage(index, .attack, by: 1, fromFoe: false)
            changeStage(index, .defense, by: 1, fromFoe: false)
            return
        }
        let aimed = move.slug == "heal-block" ? foes(of: index) : statusTargets(move, by: index)
        guard !aimed.isEmpty else { return failed(move, by: index, .noTarget) }
        for aim in aimed {
            guard let (target, source) = statusLands(move, by: index, on: aim) else { continue }
            guard move.accuracy == 0 || hits(move, by: source, on: target) else {
                log(.miss(attacker: battlers[source].spec.id, target: battlers[target].spec.id, move: move.slug))
                continue
            }
            var t = battlers[target]
            switch move.slug {
            case "taunt":
                guard !["oblivious", "aroma-veil"].contains(t.ability), t.tauntedUntil <= now else { return failed(move, by: index) }
                t.tauntedUntil = now + 3 * turn
            case "encore":
                guard encoreable(target) else { return failed(move, by: index) }
                t.encoreUntil = now + 3 * turn
                t.encoreMove = t.lastMove
            case "disable":
                guard let last = t.lastMove, t.spec.moves.contains(last), t.disabledUntil <= now else {
                    return failed(move, by: index)
                }
                t.disabledUntil = now + 4 * turn
                t.disabledMove = last
            case "torment": t.tormented = true
            case "heal-block": t.healBlockedUntil = now + 5 * turn
            case "embargo": t.embargoUntil = now + 5 * turn
            case "nightmare":
                guard t.status == .sleep, !t.nightmare else { return failed(move, by: index) }
                t.nightmare = true
            case "foresight", "odor-sleuth": t.identified = true
            case "miracle-eye": t.miracleEye = true
            case "telekinesis":
                guard !fieldHas("gravity") else { return failed(move, by: index) }
                t.telekinesisUntil = now + 3 * turn
            case "octolock":
                guard t.octolockedBy == nil else { return failed(move, by: index) }
                t.octolockedBy = source
            case "lock-on", "mind-reader":
                battlers[source].lockOn = (target, now + 2 * turn)
                log(.volatile(battler: battlers[source].spec.id, effect: move.slug))
                continue
            case "tar-shot":
                t.tarred = true
                battlers[target] = t
                changeStage(target, .speed, by: -1, fromFoe: true)
                log(.volatile(battler: t.spec.id, effect: move.slug))
                continue
            case "curse":
                // A Ghost pays half its HP to curse the target: a quarter of its HP each turn, a sixteenth for a boss.
                guard !t.cursed else { return failed(move, by: index) }
                hurt(source, max(1, battlers[source].maxHP / 2), .curse)
                t = battlers[target]
                t.cursed = true
            default:
                break
            }
            battlers[target] = t
            log(.volatile(battler: t.spec.id, effect: move.slug))
        }
    }

    /// The move a Pokémon hides with, while it hides: Fly, Dig and the others keep it out of reach for their charge,
    /// the two seconds (by its speed) before it strikes; the rest of the cast it is in sight, or a loop of Dig alone
    /// would never be hit.
    private func hiddenMove(_ index: Int) -> String? {
        guard let hidden = battlers[index].semiInvulnerable, battlers[index].castMove == hidden else { return nil }
        let charge = 2000 * 300 / (100 + Double(castSpeed(index))) / Double(BattleRules.speedUp)
        return Double(now) >= Double(battlers[index].castEnds) - charge ? hidden : nil
    }

    /// Whether `target` can fall in love with `source`: opposite genders, neither genderless, not Oblivious nor under
    /// an Aroma Veil, not already in love.
    private func falls(_ target: Int, for source: Int) -> Bool {
        guard battlers[target].infatuatedBy == nil, !["oblivious", "aroma-veil"].contains(battlers[target].ability) else {
            return false
        }
        return opposite(target, source)
    }

    private func opposite(_ a: Int, _ b: Int) -> Bool {
        let first = battlers[a].spec.resolvedGender, second = battlers[b].spec.resolvedGender
        return first == .male && second == .female || first == .female && second == .male
    }

    /// After Roost, its Flying type comes back.
    private mutating func endRoost(_ index: Int) {
        battlers[index].roosting = false
        let original = battlers[index].originalSpec?.types ?? battlers[index].spec.types
        guard original.contains(.flying) else { return }
        battlers[index].types = original
        log(.retype(battler: battlers[index].spec.id, types: original))
    }

    /// What the newest moves do once they hit: Stone Axe and Ceaseless Edge lay Stealth Rock and Spikes, Ice Spinner
    /// ends the terrain, Salt Cure and Syrup Bomb hold the target, Psychic Noise blocks its healing for two turns,
    /// Alluring Voice confuses a target whose stats rose, Double Shock spends its user's Electric type.
    private mutating func recentMoveAfterHit(_ move: BattleMove, by index: Int, targets: [Int]) {
        let side = 1 - battlers[index].side
        switch move.slug {
        case "stone-axe", "ceaseless-edge":
            let hazard = move.slug == "stone-axe" ? "stealth-rock" : "spikes"
            let layers = hazards[side][hazard] ?? 0
            if layers < (hazard == "spikes" ? 3 : 1) {
                hazards[side][hazard] = layers + 1
                log(.hazard(side: side, hazard: hazard, layers: layers + 1))
            }
        case "ice-spinner":
            if terrain != nil {
                terrain = nil
                log(.terrain(nil))
            }
        case "double-shock":
            retype(index, battlers[index].types.count == 1 ? [.normal] : battlers[index].types.filter { $0 != .electric })
        default:
            break
        }
        for target in targets where !battlers[target].isFainted {
            switch move.slug {
            case "salt-cure":
                if !battlers[target].salted {
                    battlers[target].salted = true
                    log(.volatile(battler: battlers[target].spec.id, effect: move.slug))
                }
            case "syrup-bomb":
                battlers[target].syrupLeft = 3
                log(.volatile(battler: battlers[target].spec.id, effect: move.slug))
            case "psychic-noise":
                battlers[target].healBlockedUntil = max(battlers[target].healBlockedUntil, now + 2 * BattleRules.turn)
                log(.volatile(battler: battlers[target].spec.id, effect: "heal-block"))
            case "alluring-voice":
                if battlers[target].raisedAt >= battlers[index].castStartedAt { inflict(.confusion, on: target, by: index, move: move) }
            default:
                break
            }
        }
    }

    /// Spit Up and Swallow spend the Stockpile, and the Defenses it raised fall back.
    private mutating func releaseStockpile(_ index: Int) {
        let stored = battlers[index].stockpile
        battlers[index].stockpile = 0
        changeStage(index, .defense, by: -stored, fromFoe: false)
        changeStage(index, .specialDefense, by: -stored, fromFoe: false)
    }

    /// Last Resort: once every other move of the loop was used since it entered.
    private func lastResortReady(_ index: Int) -> Bool {
        let others = Set(battlers[index].spec.moves).subtracting(["last-resort"])
        return !others.isEmpty && others.isSubset(of: battlers[index].usedSinceEntry)
    }

    // MARK: Locked moves

    /// Outrage, Thrash, Petal Dance, Raging Fury: two or three casts, then confusion. Rollout and Ice Ball: five,
    /// ending on a miss. Uproar: three, waking the sleepers as it starts.
    private mutating func lockStep(_ index: Int, _ slug: String) {
        if battlers[index].lockedMove == slug, battlers[index].lockedLeft > 0 {
            battlers[index].lockedLeft -= 1
            battlers[index].lockedDone += 1
        } else {
            let casts = Self.lockingMoves[slug] == 0 ? random.between(2, 3) : Self.lockingMoves[slug] ?? 1
            battlers[index].lockedMove = slug
            battlers[index].lockedLeft = casts - 1
            battlers[index].lockedDone = 1
            if slug == "uproar" {
                for other in active where battlers[other].status == .sleep {
                    cure(other)
                    startCast(other)
                }
            }
        }
        let rolling = slug == "rollout" || slug == "ice-ball"
        if battlers[index].lockedLeft == 0 || rolling && !battlers[index].lastLanded {
            battlers[index].lockedMove = nil
            battlers[index].lockedLeft = 0
            battlers[index].lockedDone = 0
            if Self.lockingMoves[slug] == 0 { inflict(.confusion, on: index, by: nil) }
        }
    }

    // MARK: Switching

    /// The user leaves for the best of its bench, which steps in at once; Baton Pass hands over its stages, substitute,
    /// confusion, Leech Seed, Ingrain, Aqua Ring, Curse, Perish Song and Magnet Rise. False without a bench.
    private mutating func switchOut(_ index: Int, baton: Bool = false, substitute: Int? = nil) -> Bool {
        let side = battlers[index].side
        guard !staysOnField(index) else { return false }
        guard let slot = battlers[index].slot, let next = bestEntrant(side: side, slot: slot, ordered: side == 1) else {
            return false
        }
        // Pursuit: a foe casting it strikes now, twice as hard and surely, before this one leaves (as Showdown has it, a
        // switching move included; a forced switch does not call it).
        for foe in foes(of: index) where battlers[foe].castMove == "pursuit" {
            battlers[foe].castTarget = index
            battlers[foe].pursuing = index
            completeCast(foe)
            battlers[foe].pursuing = nil
            if battlers[index].isFainted { return false }
        }
        let passed = battlers[index]
        leaveField(index)
        place(next, side: side, slot: slot)
        if baton {
            for (stat, stage) in passed.stages.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where stage != 0 {
                log(.stat(battler: battlers[next].spec.id, stat: stat, change: stage))
            }
            battlers[next].stages = passed.stages
            battlers[next].substituteHP = passed.substituteHP
            battlers[next].confusedUntil = passed.confusedUntil
            battlers[next].seededBy = passed.seededBy
            battlers[next].ingrained = passed.ingrained
            battlers[next].aquaRing = passed.aquaRing
            battlers[next].cursed = passed.cursed
            battlers[next].perishAt = passed.perishAt
            battlers[next].magnetRiseUntil = passed.magnetRiseUntil
        }
        if let substitute {
            battlers[next].substituteHP = substitute
            log(.substitute(battler: battlers[next].spec.id, hp: substitute))
        }
        enterAfterSwitch(next)
        return true
    }

    /// Roar, Whirlwind, Dragon Tail, Circle Throw: the target leaves for one of its bench at random. Not when its side
    /// has no bench, nor when it is rooted or holds on with Suction Cups.
    private mutating func forceOut(_ target: Int) -> Bool {
        let side = battlers[target].side
        guard !staysOnField(target) else { return false }
        let others = bench(side)
        guard let slot = battlers[target].slot, !others.isEmpty, !battlers[target].ingrained,
              battlers[target].ability != "suction-cups" else { return false }
        let next = others[random.below(others.count)]
        leaveField(target)
        place(next, side: side, slot: slot)
        enterAfterSwitch(next)
        return true
    }

    /// The foes never leave the field but knocked out (the owner, 2026-11-03: "les ennemis ne peuvent JAMAIS fuir"):
    /// no Roar nor Dragon Tail sends them out, no U-turn, Teleport or Baton Pass of theirs takes them out.
    private func staysOnField(_ index: Int) -> Bool { battlers[index].side == 1 }

    private mutating func enterAfterSwitch(_ index: Int) {
        stepOnHazards(index)
        guard !battlers[index].isFainted else { return }
        entryAbility(index)
        startCast(index)
    }

    /// Leaving the field by a move, a Pokémon keeps its HP, status and the moves Grudge took; the rest of what the
    /// battle did to it goes, and what it held on others ends.
    private mutating func leaveField(_ index: Int) {
        guard let slot = battlers[index].slot else { return }
        let side = battlers[index].side
        let old = battlers[index]
        let spec = old.originalSpec ?? old.spec
        var fresh = Battler(spec: spec, side: side, hp: old.hp, types: spec.types, originalSpec: old.originalSpec)
        fresh.status = old.status
        fresh.wakeAt = old.wakeAt
        fresh.ateBerry = old.ateBerry
        fresh.lostMoves = old.lostMoves
        fresh.moveIndex = old.moveIndex
        battlers[index] = fresh
        field[side][slot] = nil
        log(.leave(battler: old.spec.id))
        for other in battlers.indices {
            if battlers[other].trappedBy == index { battlers[other].trappedBy = nil }
            if battlers[other].octolockedBy == index { battlers[other].octolockedBy = nil }
        }
    }

    // MARK: Swaps

    /// Moves that swap or copy stats, stages, types and abilities with the target, or set them.
    private mutating func swap(_ move: BattleMove, by index: Int) {
        guard let aim = statusTargets(move, by: index).first else { return failed(move, by: index, .noTarget) }
        guard let (target, source) = statusLands(move, by: index, on: aim) else { return }
        if move.isPowder, battlers[target].types.contains(.grass) || battlers[target].ability == "overcoat" {
            log(.noEffect(attacker: battlers[source].spec.id, target: battlers[target].spec.id, move: move.slug))
            return
        }
        guard move.accuracy == 0 || hits(move, by: source, on: target) else {
            log(.miss(attacker: battlers[source].spec.id, target: battlers[target].spec.id, move: move.slug))
            return
        }
        let s = source, t = target
        switch move.slug {
        case "power-swap": swapStages(s, t, [.attack, .specialAttack])
        case "guard-swap": swapStages(s, t, [.defense, .specialDefense])
        case "heart-swap": swapStages(s, t, BattleStat.allCases)
        case "speed-swap":
            let mine = battlers[s].spec.stats.speed
            battlers[s].spec.stats.speed = battlers[t].spec.stats.speed
            battlers[t].spec.stats.speed = mine
            log(.volatile(battler: battlers[t].spec.id, effect: move.slug))
        case "power-split", "guard-split":
            let paths: [WritableKeyPath<BattleStats, Int>] = move.slug == "power-split"
                ? [\.attack, \.specialAttack] : [\.defense, \.specialDefense]
            for path in paths {
                let shared = (battlers[s].spec.stats[keyPath: path] + battlers[t].spec.stats[keyPath: path]) / 2
                battlers[s].spec.stats[keyPath: path] = shared
                battlers[t].spec.stats[keyPath: path] = shared
            }
            log(.volatile(battler: battlers[t].spec.id, effect: move.slug))
        case "psych-up": setStages(s, to: battlers[t].stages)
        case "topsy-turvy": setStages(t, to: battlers[t].stages.mapValues { -$0 })
        case "soak": retype(t, [.water])
        case "magic-powder": retype(t, [.psychic])
        case "reflect-type": retype(s, battlers[t].types)
        case "forests-curse": retype(t, battlers[t].types.filter { $0 != .grass } + [.grass])
        case "trick-or-treat": retype(t, battlers[t].types.filter { $0 != .ghost } + [.ghost])
        case "conversion-2":
            // A type that resists the target's last move, at random.
            guard let last = battlers[t].lastMove.flatMap(MoveTable.move) else { return failed(move, by: index) }
            let resisting = PokemonType.allCases.filter { PokemonTypeData.effectiveness(attacking: last.type, defending: $0) < 1 }
            guard !resisting.isEmpty else { return failed(move, by: index) }
            retype(s, [resisting[random.below(resisting.count)]])
        case "electrify":
            battlers[t].electrified = true
            log(.volatile(battler: battlers[t].spec.id, effect: move.slug))
        case "simple-beam": setAbility(t, "simple")
        case "worry-seed": setAbility(t, "insomnia")
        case "entrainment": setAbility(t, battlers[s].ability)
        case "role-play": setAbility(s, battlers[t].ability)
        case "skill-swap":
            let mine = battlers[s].ability
            setAbility(s, battlers[t].ability)
            setAbility(t, mine)
        case "gastro-acid": setAbility(t, "")
        default: break
        }
    }

    /// Power Trick (Attack and Defense), Power Shift (both attacks and both defenses), Acupressure (+2 to a stat at
    /// random), Conversion (its first move's type), Camouflage (the terrain's type, Normal without one).
    private mutating func selfSwap(_ move: BattleMove, by index: Int) {
        var stats = battlers[index].spec.stats
        switch move.slug {
        case "power-trick":
            (stats.attack, stats.defense) = (stats.defense, stats.attack)
        case "power-shift":
            (stats.attack, stats.defense) = (stats.defense, stats.attack)
            (stats.specialAttack, stats.specialDefense) = (stats.specialDefense, stats.specialAttack)
        case "acupressure":
            let open = BattleStat.allCases.filter { battlers[index].stage($0) < 6 }
            guard !open.isEmpty else { return failed(move, by: index) }
            changeStage(index, open[random.below(open.count)], by: 2, fromFoe: false)
            return
        case "conversion":
            guard let first = battlers[index].spec.moves.first.flatMap(MoveTable.move) else { return failed(move, by: index) }
            retype(index, [first.type])
            return
        case "camouflage":
            retype(index, [camouflageType])
            return
        default:
            return
        }
        battlers[index].spec.stats = stats
        log(.volatile(battler: battlers[index].spec.id, effect: move.slug))
    }

    private mutating func swapStages(_ a: Int, _ b: Int, _ stats: [BattleStat]) {
        var mine = battlers[a].stages, theirs = battlers[b].stages
        for stat in stats { (mine[stat], theirs[stat]) = (theirs[stat], mine[stat]) }
        setStages(a, to: mine)
        setStages(b, to: theirs)
    }

    /// Sets a battler's stages, logging each change.
    private mutating func setStages(_ index: Int, to stages: [BattleStat: Int]) {
        for stat in BattleStat.allCases {
            let before = battlers[index].stage(stat), after = stages[stat] ?? 0
            if before != after { log(.stat(battler: battlers[index].spec.id, stat: stat, change: after - before)) }
        }
        battlers[index].stages = stages.filter { $0.value != 0 }
    }

    private mutating func retype(_ index: Int, _ types: [PokemonType]) {
        battlers[index].types = types
        log(.retype(battler: battlers[index].spec.id, types: types))
    }

    private mutating func setAbility(_ index: Int, _ ability: String) {
        battlers[index].spec.ability = ability.isEmpty ? nil : ability
        log(.abilityChange(battler: battlers[index].spec.id, ability: ability))
    }

    // MARK: Sides and field

    /// Screens, Safeguard, Mist, Tailwind, Lucky Chant, hazards, Trick Room and the rooms, the sports, Ion Deluge,
    /// Haze, Court Change; Defog and Tidy Up clear before their stat changes. True when the move is done.
    private mutating func fieldMove(_ move: BattleMove, by index: Int) -> Bool {
        let id = battlers[index].spec.id
        let side = battlers[index].side
        let turn = BattleRules.turn
        func failed() -> Bool {
            log(.fail(battler: id, move: move.slug, reason: .failed))
            return true
        }
        switch move.slug {
        case "reflect", "light-screen", "safeguard", "mist", "lucky-chant", "aurora-veil", "tailwind":
            if sideHas(side, move.slug) || move.slug == "aurora-veil" && weather != .snow { return failed() }
            startSideCondition(side, move.slug, turns: move.slug == "tailwind" ? 4 : 5)
            return true
        case "spikes", "toxic-spikes", "stealth-rock", "sticky-web":
            let most = ["spikes": 3, "toxic-spikes": 2][move.slug] ?? 1
            let layers = hazards[1 - side][move.slug] ?? 0
            guard layers < most else { return failed() }
            hazards[1 - side][move.slug] = layers + 1
            log(.hazard(side: 1 - side, hazard: move.slug, layers: layers + 1))
            return true
        case "trick-room", "magic-room", "wonder-room":
            // Used again while it holds, it ends.
            if fieldHas(move.slug) {
                fieldConditions[move.slug] = nil
                log(.fieldCondition(condition: move.slug, active: false))
            } else {
                fieldConditions[move.slug] = now + 5 * turn
                log(.fieldCondition(condition: move.slug, active: true))
            }
            return true
        case "gravity", "mud-sport", "water-sport", "ion-deluge":
            if fieldHas(move.slug) { return failed() }
            fieldConditions[move.slug] = now + (move.slug == "ion-deluge" ? 1 : 5) * turn
            log(.fieldCondition(condition: move.slug, active: true))
            return true
        case "haze":
            for other in active {
                for (stat, stage) in battlers[other].stages.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where stage != 0 {
                    log(.stat(battler: battlers[other].spec.id, stat: stat, change: -stage))
                }
                battlers[other].stages = [:]
            }
            return true
        case "court-change":
            sideConditions.swapAt(0, 1)
            hazards.swapAt(0, 1)
            sideGuards.swapAt(0, 1)
            for s in 0..<2 {
                for (hazard, layers) in hazards[s].sorted(by: { $0.key < $1.key }) {
                    log(.hazard(side: s, hazard: hazard, layers: layers))
                }
                for condition in sideConditions[s].keys.sorted() {
                    log(.sideCondition(side: s, condition: condition, active: true))
                }
            }
            return true
        case "fairy-lock":
            // It keeps Pokémon from leaving: none leaves the field here but knocked out.
            log(.fail(battler: id, move: move.slug, reason: .nothing))
            return true
        case "defog":
            for s in 0..<2 { clearHazards(s) }
            for condition in ["reflect", "light-screen", "aurora-veil", "safeguard", "mist"] {
                endSideCondition(1 - side, condition)
            }
            return false
        case "tidy-up":
            for s in 0..<2 { clearHazards(s) }
            for other in active where battlers[other].substituteHP > 0 {
                battlers[other].substituteHP = 0
                log(.substitute(battler: battlers[other].spec.id, hp: 0))
            }
            return false
        default:
            return false
        }
    }

    private mutating func startSideCondition(_ side: Int, _ condition: String, turns: Int) {
        sideConditions[side][condition] = now + turns * BattleRules.turn
        log(.sideCondition(side: side, condition: condition, active: true))
        // Tailwind on its side: Wind Rider raises its Attack, Wind Power charges.
        if condition == "tailwind" {
            for member in field[side].compactMap({ $0 }) where !battlers[member].isFainted { feelsTailwind(member) }
        }
    }

    private mutating func feelsTailwind(_ index: Int) {
        let b = battlers[index]
        switch b.ability {
        case "wind-rider":
            log(.ability(battler: b.spec.id, ability: b.ability))
            changeStage(index, .attack, by: 1, fromFoe: false)
        case "wind-power":
            guard !b.charged else { return }
            battlers[index].charged = true
            log(.ability(battler: b.spec.id, ability: b.ability))
        default: break
        }
    }

    private mutating func endSideCondition(_ side: Int, _ condition: String) {
        guard sideConditions[side][condition] != nil else { return }
        sideConditions[side][condition] = nil
        log(.sideCondition(side: side, condition: condition, active: false))
    }

    private mutating func clearHazards(_ side: Int) {
        for hazard in hazards[side].keys.sorted() { log(.hazard(side: side, hazard: hazard, layers: 0)) }
        hazards[side] = [:]
    }

    /// Rapid Spin and Mortal Spin free their user: its side's hazards, Leech Seed and a binding move.
    private mutating func spinAway(_ index: Int) {
        clearHazards(battlers[index].side)
        battlers[index].seededBy = nil
        battlers[index].trappedBy = nil
    }

    // MARK: Moves that use another

    /// Metronome, Assist, Sleep Talk, Copycat, Mirror Move, Me First and Nature Power use another move in their
    /// place; it aims anew, but Mirror Move's and Me First's at their target.
    private mutating func call(_ move: BattleMove, by index: Int) {
        let id = battlers[index].spec.id
        var boost = 1.0
        var slug: String?
        switch move.slug {
        case "metronome":
            slug = Self.metronomePool[random.below(Self.metronomePool.count)]
        case "assist":
            let options = assistOptions(index)
            slug = options.isEmpty ? nil : options[random.below(options.count)]
        case "sleep-talk":
            let options = battlers[index].status == .sleep ? sleepTalkOptions(index) : []
            slug = options.isEmpty ? nil : options[random.below(options.count)]
        case "copycat":
            slug = lastMoveUsed.flatMap { Self.canBeCalled($0) ? $0 : nil }
        case "mirror-move":
            slug = statusTargets(move, by: index).first.flatMap { mirrored(by: $0) }
        case "me-first":
            slug = statusTargets(move, by: index).first.flatMap { meFirstMove(of: $0) }
            boost = 1.5
        case "nature-power":
            slug = switch terrain {
            case .electric?: "thunderbolt"
            case .grassy?: "energy-ball"
            case .misty?: "moonblast"
            case .psychic?: "psychic"
            case nil: "tri-attack"
            }
        default:
            break
        }
        guard let slug, let called = MoveTable.move(slug) else {
            log(.fail(battler: id, move: move.slug, reason: .failed))
            return
        }
        log(.call(battler: id, move: slug))
        let aimed = battlers[index].castTarget
        if move.slug != "mirror-move", move.slug != "me-first" { battlers[index].castTarget = nil }
        battlers[index].powerBoost = boost
        use(called, by: index)
        battlers[index].powerBoost = 1
        battlers[index].castTarget = aimed
    }

    /// The target's last move, if Mirror Move may copy it.
    private func mirrored(by target: Int) -> String? {
        guard let slug = battlers[target].lastMove, Self.canBeCalled(slug),
              MoveTable.move(slug)?.flags.contains("mirror") == true else { return nil }
        return slug
    }

    /// The damaging move the target is casting, which Me First takes before it lands.
    private func meFirstMove(of target: Int) -> String? {
        guard let slug = battlers[target].castMove, Self.canBeCalled(slug), MoveTable.move(slug)?.isDamaging == true
        else { return nil }
        return slug
    }

    /// The moves of the side's other Pokémon, bench included, Assist may use.
    private func assistOptions(_ index: Int) -> [String] {
        let side = battlers[index].side
        let moves = battlers.indices.filter { $0 != index && battlers[$0].side == side && !battlers[$0].isFainted }
            .flatMap { battlers[$0].spec.moves }
        return Array(Set(moves.filter { Self.canBeCalled($0) && MoveTable.move($0)?.charges == false })).sorted()
    }

    /// The loop's other moves Sleep Talk may use: not a charging one, Snore yes.
    private func sleepTalkOptions(_ index: Int) -> [String] {
        battlers[index].spec.moves.filter { slug in
            slug != "sleep-talk" && (Self.canBeCalled(slug) || slug == "snore")
                && MoveTable.move(slug).map { !$0.charges && !$0.recharges } ?? false
        }
    }

    /// The ally Instruct makes repeat its last move: one standing beside the user with a move it may repeat.
    private func instructTarget(_ index: Int) -> Int? {
        allies(of: index).first { ally in
            guard ally != index, let slug = battlers[ally].lastMove, Self.canBeCalled(slug),
                  let move = MoveTable.move(slug) else { return false }
            return !move.charges && !move.recharges
        }
    }

    /// Transform (and Imposter): the target's stats but HP, its types, ability, loop and stat stages. A boss's raised
    /// stats stay its own: the copy takes its species' at its level.
    /// Low Kick and Grass Knot: 20 under 10 kg, then 40, 60, 80, 100, and 120 from 200 kg.
    static func weightPower(targetKilograms kg: Double) -> Double {
        kg >= 200 ? 120 : kg >= 100 ? 100 : kg >= 50 ? 80 : kg >= 25 ? 60 : kg >= 10 ? 40 : 20
    }

    /// Heavy Slam and Heat Crash, by how many times its user outweighs the target: 40, then 60 from twice, up to 120
    /// from five times.
    static func weightRatioPower(_ ratio: Double) -> Double {
        ratio >= 5 ? 120 : ratio >= 4 ? 100 : ratio >= 3 ? 80 : ratio >= 2 ? 60 : 40
    }

    /// In kilograms, as the games weigh it: its form's, or its target's after Transform; Heavy Metal doubles it, Light
    /// Metal halves it.
    private func weight(_ index: Int) -> Double {
        let b = battlers[index]
        let who = b.weighsAs ?? (b.spec.speciesID, b.spec.form)
        return Self.weight(kilograms: Double(SpeciesBattleTable.data(speciesID: who.speciesID, form: who.form)?.weight ?? 0) / 10,
                           autotomized: b.autotomized, ability: b.ability)
    }

    /// 100 kg lighter for each Autotomize, then Heavy Metal doubles and Light Metal halves; never under 0.1 kg.
    static func weight(kilograms: Double, autotomized: Int, ability: String) -> Double {
        var kg = max(0.1, kilograms - 100 * Double(autotomized))
        if ability == "heavy-metal" { kg *= 2 } else if ability == "light-metal" { kg /= 2 }
        return max(0.1, kg)
    }

    /// The moves that punish Minimize: twice the damage, never a miss.
    static let punishMinimize: Set<String> = ["stomp", "body-slam", "dragon-rush", "steamroller", "heat-crash",
                                              "heavy-slam", "flying-press", "malicious-moonsault", "double-iron-bash",
                                              "supercell-slam"]

    private mutating func transform(_ index: Int, into target: Int) {
        let t = battlers[target]
        battlers[index].weighsAs = t.weighsAs ?? (t.spec.speciesID, t.spec.form)
        var stats = t.spec.stats
        if t.spec.isBoss, let data = SpeciesBattleTable.data(speciesID: t.spec.speciesID, form: t.spec.form) {
            stats = BattleStats.computed(base: data.baseStats, ivs: Array(repeating: 31, count: 6), level: t.spec.level,
                                         nature: nil, speciesID: t.spec.speciesID)
        }
        stats.hp = battlers[index].maxHP
        battlers[index].spec.stats = stats
        battlers[index].spec.ability = t.spec.ability
        battlers[index].spec.moves = t.spec.moves
        battlers[index].types = t.types
        battlers[index].stages = t.stages
        battlers[index].transformed = true
        battlers[index].moveIndex = 0
        log(.transform(battler: battlers[index].spec.id, into: t.spec.id))
    }

    /// Moonlight, Synthesis and Morning Sun heal two thirds in the sun and a quarter in other weather.
    private func healShare(_ move: BattleMove) -> Int {
        if move.slug == "shore-up", weather == .sand { return 67 }
        if move.slug == "floral-healing", terrain == .grassy { return 67 }
        guard ["moonlight", "synthesis", "morning-sun"].contains(move.slug) else { return move.healing }
        switch weather {
        case .sun: return 67
        case nil: return 50
        default: return 25
        }
    }

    // MARK: Accuracy, criticals, type

    private mutating func hits(_ move: BattleMove, by index: Int, on target: Int) -> Bool {
        if move.accuracy == 0, hiddenMove(target) == nil { return true }
        if let lock = battlers[index].lockOn, lock.target == target, lock.until > now {
            battlers[index].lockOn = nil
            return true
        }
        if battlers[target].telekinesisUntil > now, !Self.ohkoMoves.contains(move.slug) { return true }
        if battlers[index].ability == "no-guard" || battlers[target].ability == "no-guard" { return true }
        if let hidden = hiddenMove(target), !(Self.reachesHidden[hidden] ?? []).contains(move.slug) { return false }
        if battlers[target].minimized, Self.punishMinimize.contains(move.slug) { return true }
        if move.slug == "pursuit", battlers[index].pursuing == target { return true }
        if (move.slug == "thunder" || move.slug == "hurricane"), weather == .rain { return true }
        if ["bleakwind-storm", "wildbolt-storm", "sandsear-storm"].contains(move.slug), weather == .rain { return true }
        if battlers[target].exposed { return true }
        if move.slug == "blizzard", weather == .snow { return true }
        var accuracy = Double(move.accuracy)
        if (move.slug == "thunder" || move.slug == "hurricane"), weather == .sun { accuracy = 50 }
        let evasion = battlers[target].identified || battlers[target].miracleEye ? min(0, battlers[target].stage(.evasion))
            : battlers[target].stage(.evasion)
        let stage = max(-6, min(6, battlers[index].stage(.accuracy) - evasion))
        accuracy *= stage >= 0 ? Double(3 + stage) / 3 : 3 / Double(3 - stage)
        if battlers[index].ability == "compound-eyes" { accuracy *= 1.3 }
        if battlers[index].ability == "hustle", move.moveClass == .physical { accuracy *= 0.8 }
        if fieldHas("gravity") { accuracy *= 5.0 / 3 }
        return Double(random.below(100)) < accuracy
    }

    private mutating func rollsCritical(_ move: BattleMove, by index: Int, on target: Int) -> Bool {
        if ["battle-armor", "shell-armor"].contains(battlers[target].ability) || sideHas(battlers[target].side, "lucky-chant") {
            return false
        }
        if battlers[index].laserFocus {
            battlers[index].laserFocus = false
            return true
        }
        var stage = move.critStage + battlers[index].critBoost
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
        // Revelation Dance reads the types it has now (Soak, Burn Up); the others their Pokémon's (`BattleMove.type(for:)`).
        let own = move.slug == "revelation-dance" ? (battlers[index].types.first ?? move.type)
            : move.type(for: battlers[index].spec)
        if move.slug == "weather-ball" {
            switch weather {
            case .sun: return .fire
            case .rain: return .water
            case .sand: return .rock
            case .snow: return .ice
            case nil: return .normal
            }
        }
        if own == .normal {
            switch battlers[index].ability {
            case "aerilate": return .flying
            case "pixilate": return .fairy
            case "refrigerate": return .ice
            case "galvanize": return .electric
            default: break
            }
        }
        if battlers[index].ability == "normalize", !BattleMove.typeKeptUnderNormalize.contains(move.slug) { return .normal }
        if own == .normal, fieldHas("ion-deluge") { return .electric }
        if battlers[index].electrified { return .electric }
        if move.slug == "natural-gift", let berry = battlers[index].throwing { return berry == .oran ? .poison : .psychic }
        if move.slug == "terrain-pulse", isGrounded(index) {
            switch terrain {
            case .electric?: return .electric
            case .grassy?: return .grass
            case .misty?: return .fairy
            case .psychic?: return .psychic
            case nil: break
            }
        }
        return own
    }

    private func effectiveness(_ move: BattleMove, by index: Int, on target: Int) -> Double {
        let type = moveType(move, by: index)
        let d = battlers[target]
        let breaksMold = ["mold-breaker", "teravolt", "turboblaze"].contains(battlers[index].ability)
        let grounded = fieldHas("gravity") || d.ingrained || d.smackedDown || move.slug == "thousand-arrows"
        if type == .ground, d.ability == "levitate", !breaksMold, !grounded { return 0 }
        if type == .ground, d.magnetRiseUntil > now || d.telekinesisUntil > now, !grounded { return 0 }
        var factor = d.types.reduce(1.0) { result, defending in
            var single = PokemonTypeData.effectiveness(attacking: type, defending: defending)
            if single == 0, type == .ground, defending == .flying, grounded { single = 1 }
            if single == 0, defending == .ghost, type == .normal || type == .fighting, d.identified { single = 1 }
            if single == 0, defending == .dark, type == .psychic, d.miracleEye { single = 1 }
            if single == 0, defending == .ghost, (type == .normal || type == .fighting),
               battlers[index].ability == "scrappy" || battlers[index].ability == "minds-eye" {
                single = 1
            }
            if move.slug == "freeze-dry", defending == .water { single = 2 }
            return result * single
        }
        if d.ability == "wonder-guard", factor <= 1, !breaksMold { factor = 0 }
        if d.tarred, type == .fire { factor *= 2 }
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
        if d.ability == "soundproof" && move.isSound || d.ability == "bulletproof" && move.isBallistic {
            trigger()
            return true
        }
        // Wind Rider takes a wind move and raises its Attack.
        if d.ability == "wind-rider", move.isWind {
            trigger()
            changeStage(target, .attack, by: 1, fromFoe: false)
            return true
        }
        return false
    }

    // MARK: Damage

    private func stageMultiplier(_ stage: Int) -> Double {
        stage >= 0 ? Double(2 + stage) / 2 : 2 / Double(2 - stage)
    }

    private func isGrounded(_ index: Int) -> Bool {
        let b = battlers[index]
        if fieldHas("gravity") || b.ingrained || b.smackedDown { return true }
        if b.magnetRiseUntil > now || b.telekinesisUntil > now { return false }
        return !b.types.contains(.flying) && b.ability != "levitate"
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
        if sideHas(b.side, "tailwind") { speed *= 2 }
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
        case "acrobatics": if heldBerry(index) == nil { power *= 2 }
        case "payback": if d.lastActionAt >= a.castStartedAt { power *= 2 }
        case "avalanche", "revenge": if (a.hitBy[target] ?? -1) >= a.castStartedAt { power *= 2 }
        case "assurance": if d.lastDamagedAt >= a.castStartedAt { power *= 2 }
        case "bolt-beak", "fishious-rend": if d.lastActionAt < a.castStartedAt { power *= 2 }
        case "lash-out": if a.loweredAt >= a.castStartedAt { power *= 2 }
        case "punishment": power = min(200, 60 + 20 * Double(d.stages.values.filter { $0 > 0 }.reduce(0, +)))
        case "return", "pika-papow", "veevee-volley": power = 102
        case "frustration": power = 1
        case "trump-card": power = 40
        case "spit-up": power = 100 * Double(a.stockpile)
        case "magnitude", "present", "beat-up": power = a.rolledPower ?? 0
        case "crush-grip", "wring-out": power = max(1, 120 * Double(d.hp) / Double(d.maxHP))
        case "hard-press": power = max(1, 100 * Double(d.hp) / Double(d.maxHP))
        case "round":
            if allies(of: index).contains(where: { $0 != index && battlers[$0].lastMove == "round"
                && battlers[$0].lastActionAt >= now - BattleRules.turn }) { power *= 2 }
        case "fusion-flare": if lastMoveUsed == "fusion-bolt" { power *= 2 }
        case "fusion-bolt": if lastMoveUsed == "fusion-flare" { power *= 2 }
        case "terrain-pulse": if terrain != nil, isGrounded(index) { power *= 2 }
        case "expanding-force": if terrain == .psychic, isGrounded(index) { power *= 1.5 }
        case "rising-voltage": if terrain == .electric, isGrounded(target) { power *= 2 }
        case "grav-apple": if fieldHas("gravity") { power *= 1.5 }
        case "misty-explosion": if terrain == .misty, isGrounded(index) { power *= 1.5 }
        case "last-respects":
            power = 50 + 50 * Double(battlers.filter { $0.side == a.side && $0.isFainted }.count)
        case "rage-fist": power = min(350, 50 + 50 * Double(a.timesHit))
        case "psyblade": if terrain == .electric { power *= 1.5 }
        case "collision-course", "electro-drift": if effectiveness(move, by: index, on: target) > 1 { power *= 5461.0 / 4096 }
        case "temper-flare": if a.lastMove != nil, !a.lastLanded { power *= 2 }
        case "fickle-beam", "triple-kick", "triple-axel": power = a.rolledPower ?? power
        case "stored-power", "power-trip":
            power = 20 + 20 * Double(a.stages.values.filter { $0 > 0 }.reduce(0, +))
        case "weather-ball": if weather != nil { power = 100 }
        case "solar-beam", "solar-blade": if weather == .rain || weather == .sand || weather == .snow { power /= 2 }
        case "low-kick", "grass-knot": power = Self.weightPower(targetKilograms: weight(target))
        case "heavy-slam", "heat-crash": power = Self.weightRatioPower(weight(index) / weight(target))
        case "knock-off": if heldBerry(target) != nil { power *= 1.5 }
        case "rollout", "ice-ball":
            // Doubled at each cast in a row, and again after Defense Curl; on a boss, never past 120 (the owner's rule:
            // a fifth Rollout at 480 would take a boss's share at once).
            let done = a.lockedMove == move.slug ? a.lockedDone : 0
            power *= pow(2, Double(done)) * (a.defenseCurl ? 2 : 1)
            if d.spec.isBoss { power = min(power, 120) }
        case "fury-cutter": power = min(160, power * pow(2, Double(a.streak)))
        case "echoed-voice": power = min(200, power * Double(1 + a.streak))
        case "natural-gift": power = a.throwing == nil ? 0 : 80
        case "fling": power = a.throwing == nil ? 0 : 10

        default: break
        }
        let type = moveType(move, by: index)
        if a.charged, type == .electric { power *= 2 }
        if d.minimized, Self.punishMinimize.contains(move.slug) { power *= 2 }
        if move.slug == "pursuit", a.pursuing == target { power *= 2 }
        switch a.ability {
        case "technician": if move.power > 0, move.power <= 60 { power *= 1.5 }
        case "iron-fist": if move.isPunch { power *= 1.2 }
        case "strong-jaw": if move.isBite { power *= 1.5 }
        case "mega-launcher": if move.isPulse { power *= 1.5 }
        case "tough-claws": if move.isContact { power *= 1.3 }
        case "sharpness": if move.isSlicing { power *= 1.5 }
        case "reckless": if move.drain < 0 { power *= 1.2 }
        case "sheer-force": if move.hasSecondaryEffect { power *= 1.3 }
        case "aerilate", "pixilate", "refrigerate", "galvanize": if move.type(for: a.spec) == .normal { power *= 1.2 }
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
        if type == .electric && fieldHas("mud-sport") || type == .fire && fieldHas("water-sport") { power /= 3 }
        // Earthquake on a digger, Surf on a diver, Gust and Twister on a flyer: twice as hard.
        if let hidden = hiddenMove(target), (Self.doublesOnHidden[hidden] ?? []).contains(move.slug) { power *= 2 }
        return power * a.powerBoost * (a.helped ? 1.5 : 1)
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
        // Wonder Room swaps the Defense and Special Defense a Pokémon has, not their stages.
        let defenseRead: BattleStat = fieldHas("wonder-room") ? (defenseStat == .defense ? .specialDefense : .defense) : defenseStat
        var defense = Double(d.spec.stats.value(defenseRead)) * stageMultiplier(defenseStage)
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
        case (.sun?, .water): modify(move.slug == "hydro-steam" ? 1.5 : 0.5)
        case (.rain?, .fire): modify(0.5)
        default: break
        }
        if critical { modify(a.ability == "sniper" ? 2.25 : 1.5) }
        // Reflect, Light Screen and Aurora Veil: half the damage, two thirds when more than one stands on the side.
        let screen = physical ? "reflect" : "light-screen"
        if !critical, a.ability != "infiltrator", sideHas(d.side, screen) || sideHas(d.side, "aurora-veil") {
            modify(allies(of: target).count > 1 ? 2732.0 / 4096 : 0.5)
        }
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
        if d.exposed { modify(2) }
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
        case "final-gambit":
            // A boss takes at most a quarter of its HP from the user's sacrifice.
            return d.spec.isBoss ? min(a.hp, d.maxHP / 4) : a.hp
        case "endeavor":
            // The target's HP fall to the user's (`use` fails it otherwise); a boss loses at most an eighth.
            let gap = max(1, d.hp - a.hp)
            return d.spec.isBoss ? min(gap, d.maxHP / 8) : gap
        default:
            return Self.reactiveMoves[move.slug] != nil ? a.answering ?? 1 : nil
        }
    }

    /// Counter and its kin: the foe that dealt the hit they answer, what they send back, and whether that hit was
    /// physical (nil for Bide's store). Counter (physical), Mirror Coat (special), Metal Burst and Comeuppance (either)
    /// answer a hit taken within the last turn and not answered yet; Bide what it stored during its two turns. A boss
    /// takes at most a quarter of its HP from one.
    private func reactiveStrike(_ move: BattleMove, by index: Int) -> (target: Int, damage: Int, physical: Bool?)? {
        guard let factor = Self.reactiveMoves[move.slug] else { return nil }
        let b = battlers[index]
        let answered: (attacker: Int, amount: Int, physical: Bool?)?
        if move.slug == "bide" {
            answered = b.bideAttacker.flatMap { b.bideTaken > 0 ? ($0, b.bideTaken, nil) : nil }
        } else {
            let hits: [(hit: ReceivedHit?, physical: Bool)] = switch move.slug {
            case "counter": [(b.lastPhysicalHit, true)]
            case "mirror-coat": [(b.lastSpecialHit, false)]
            default: [(b.lastPhysicalHit, true), (b.lastSpecialHit, false)]
            }
            answered = hits.compactMap { pair in pair.hit.map { ($0, pair.physical) } }
                .filter { now - $0.0.time <= BattleRules.turn }
                .max { $0.0.time < $1.0.time }.map { ($0.0.attacker, $0.0.amount, $0.1) }
        }
        guard let answered, !battlers[answered.attacker].isFainted, battlers[answered.attacker].slot != nil,
              battlers[answered.attacker].side != b.side else { return nil }
        let d = battlers[answered.attacker]
        let damage = max(1, Int(Double(answered.amount) * factor))
        return (answered.attacker, d.spec.isBoss ? min(damage, d.maxHP / 4) : damage, answered.physical)
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
        if battlers[target].enduringUntil > now, amount >= battlers[target].hp {
            amount = battlers[target].hp - 1
            log(.endured(battler: battlers[target].spec.id))
        }
        battlers[target].hp -= amount
        if amount > 0 { battlers[target].lastDamagedAt = now }
        if amount > 0, battlers[index].side != battlers[target].side { remember(amount, on: target, by: index, move: move) }
        log(.hit(attacker: battlers[index].spec.id, target: battlers[target].spec.id, move: move.slug, damage: amount,
                 hp: battlers[target].hp, effectiveness: effectiveness, critical: critical))
        if battlers[target].isFainted {
            faint(target, by: index)
        } else {
            afterHit(target, by: index, move: move)
            eatBerryIfLow(target)
        }
    }

    /// Keeps the hit for the moves that answer one: the hits of one multi-hit move add up.
    private mutating func remember(_ amount: Int, on target: Int, by index: Int, move: BattleMove) {
        battlers[target].hitBy[index] = now
        battlers[target].timesHit += 1
        if battlers[target].castMove == "bide" {
            battlers[target].bideTaken += amount
            battlers[target].bideAttacker = index
        }
        let physical = move.moveClass == .physical
        var hit = physical ? battlers[target].lastPhysicalHit : battlers[target].lastSpecialHit
        if let previous = hit, previous.time == now, previous.attacker == index, previous.move == move.slug {
            hit?.amount += amount
        } else {
            hit = ReceivedHit(time: now, amount: amount, attacker: index, move: move.slug)
        }
        if physical { battlers[target].lastPhysicalHit = hit } else { battlers[target].lastSpecialHit = hit }
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
        // Charged, for its next Electric move: by a wind move, or by any hit.
        case "wind-power", "electromorphosis":
            if battlers[target].ability == "electromorphosis" || move.isWind, !battlers[target].charged {
                battlers[target].charged = true
                log(.ability(battler: battlers[target].spec.id, ability: battlers[target].ability))
            }
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
        case "cute-charm":
            if falls(index, for: target), random.below(10) < 3 {
                battlers[index].infatuatedBy = target
                log(.ability(battler: battlers[target].spec.id, ability: ability))
                log(.volatile(battler: battlers[index].spec.id, effect: "attract"))
            }
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
            if random.chance(serene(index, chance)) {
                // Dire Claw: poison, paralysis or sleep, drawn.
                let drawn = move.slug == "dire-claw" ? [BattleAilment.poison, .paralysis, .sleep][random.below(3)] : ailment
                inflict(drawn, on: target, by: index, move: move)
            }
        }
        if move.flinchChance > 0, random.chance(serene(index, move.flinchChance)),
           battlers[target].ability != "inner-focus", let slug = battlers[target].castMove {
            battlers[target].castEnds = now + castDuration(slug, by: target)
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
        case .sleep:
            return !["insomnia", "vital-spirit", "sweet-veil"].contains(d.ability) && terrain != .electric && !uproarHeard
        case .freeze: return !d.types.contains(.ice) && d.ability != "magma-armor" && weather != .sun
        default: return true
        }
    }

    /// While a Pokémon on the field is locked into Uproar, nobody falls asleep.
    private var uproarHeard: Bool { active.contains { battlers[$0].lockedMove == "uproar" } }

    private mutating func inflict(_ ailment: BattleAilment, on target: Int, by source: Int?, move: BattleMove? = nil) {
        var ailment = ailment
        if move?.slug == "toxic" { ailment = .badPoison }
        guard canInflict(ailment, on: target, move: move), !safeguarded(target, from: source) else { return }
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
            battlers[target].semiInvulnerable = nil
        case .freeze:
            battlers[target].status = .freeze
            battlers[target].castMove = nil
            battlers[target].semiInvulnerable = nil
        case .badPoison:
            battlers[target].status = .badPoison
            battlers[target].toxicCount = 0
        default:
            battlers[target].status = ailment
        }
        log(.status(battler: id, ailment: ailment))
    }

    /// Safeguard keeps a side's statuses and confusion off, from the foes' moves (an Infiltrator's aside).
    private func safeguarded(_ target: Int, from source: Int?) -> Bool {
        guard let source, battlers[source].side != battlers[target].side, battlers[source].ability != "infiltrator"
        else { return false }
        return sideHas(battlers[target].side, "safeguard")
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
            // A boss loses a sixteenth to Curse and Nightmare, not a quarter: they would take any boss in four turns.
            let share = b.spec.isBoss ? 16 : 4
            if b.cursed, !guarded, !battlers[index].isFainted { hurt(index, max(1, b.maxHP / share), .curse) }
            if b.nightmare, !guarded, !battlers[index].isFainted {
                if battlers[index].status == .sleep {
                    hurt(index, max(1, b.maxHP / share), .nightmare)
                } else {
                    battlers[index].nightmare = false
                }
            }
            if b.salted, !guarded, !battlers[index].isFainted {
                // Salt Cure: an eighth each turn, a quarter for a Water or Steel type, a sixteenth for a boss.
                let salt = b.spec.isBoss ? 16 : b.types.contains(.water) || b.types.contains(.steel) ? 4 : 8
                hurt(index, max(1, b.maxHP / salt), .curse)
            }
            if b.syrupLeft > 0, !battlers[index].isFainted {
                battlers[index].syrupLeft -= 1
                changeStage(index, .speed, by: -1, fromFoe: true)
            }
            if b.ingrained, !battlers[index].isFainted { heal(index, max(1, b.maxHP / 16), .ingrain) }
            if b.aquaRing, !battlers[index].isFainted { heal(index, max(1, b.maxHP / 16), .aquaRing) }
            if let locker = b.octolockedBy, !battlers[index].isFainted {
                if battlers[locker].isFainted || battlers[locker].slot == nil {
                    battlers[index].octolockedBy = nil
                } else {
                    changeStage(index, .defense, by: -1, fromFoe: true)
                    changeStage(index, .specialDefense, by: -1, fromFoe: true)
                }
            }
        }
    }

    // MARK: HP

    private mutating func hurt(_ index: Int, _ amount: Int, _ cause: BattleHurtCause) {
        guard !battlers[index].isFainted, amount > 0 else { return }
        battlers[index].lastDamagedAt = now
        let taken = min(amount, battlers[index].hp)
        battlers[index].hp -= taken
        log(.hurt(battler: battlers[index].spec.id, amount: taken, hp: battlers[index].hp, cause: cause))
        if battlers[index].isFainted { faint(index, by: nil) } else { eatBerryIfLow(index) }
    }

    private mutating func heal(_ index: Int, _ amount: Int, _ cause: BattleHealCause) {
        guard !battlers[index].isFainted, amount > 0, battlers[index].hp < battlers[index].maxHP else { return }
        if battlers[index].healBlockedUntil > now, cause != .painSplit { return }
        let gained = min(amount, battlers[index].maxHP - battlers[index].hp)
        battlers[index].hp += gained
        log(.heal(battler: battlers[index].spec.id, amount: gained, hp: battlers[index].hp, cause: cause))
    }

    /// A side's berry, eaten once per Pokémon when its HP fall under half: a Sitrus under a quarter, else an Oran first.
    private mutating func eatBerryIfLow(_ index: Int) {
        let b = battlers[index]
        guard !b.ateBerry, !b.isFainted, b.hp * 2 < b.maxHP, !fieldHas("magic-room"), b.embargoUntil <= now else { return }
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
        battlers[index].consumedBerry = pick
        log(.berry(battler: b.spec.id, berry: pick))
        heal(index, max(1, Int(Double(b.maxHP) * pick.share)), .berry)
    }

    // MARK: Berries held

    /// The berry a Pokémon holds: its side's best one left, unless it ate, used or lost its own (a side shares its
    /// berries, one per Pokémon).
    private func heldBerry(_ index: Int) -> BattleBerry? {
        guard !battlers[index].ateBerry else { return nil }
        let side = battlers[index].side
        if (berries[side][.sitrus] ?? 0) > 0 { return .sitrus }
        if (berries[side][.oran] ?? 0) > 0 { return .oran }
        return nil
    }

    /// The berry leaves its holder: gone from its side, the holder holding none from now on.
    private mutating func takeBerry(_ index: Int, by taker: Int?) -> BattleBerry? {
        guard let berry = heldBerry(index) else { return nil }
        berries[battlers[index].side][berry, default: 0] -= 1
        battlers[index].ateBerry = true
        log(.berryTaken(battler: battlers[index].spec.id, berry: berry, by: taker.map { battlers[$0].spec.id }))
        return berry
    }

    private mutating func giveBerry(_ berry: BattleBerry, to index: Int) {
        berries[battlers[index].side][berry, default: 0] += 1
        battlers[index].ateBerry = false
        log(.berryGiven(battler: battlers[index].spec.id, berry: berry))
    }

    /// Eaten on the spot (Pluck, Stuff Cheeks, Teatime, a flung one): its healing, whatever the HP.
    private mutating func eat(_ berry: BattleBerry, by index: Int) {
        battlers[index].consumedBerry = berry
        log(.berry(battler: battlers[index].spec.id, berry: berry))
        heal(index, max(1, Int(Double(battlers[index].maxHP) * berry.share)), .berry)
    }

    /// What a damaging move does to berries once it hit: Knock Off knocks it off, Thief and Covet steal it for a
    /// user holding none, Pluck and Bug Bite eat it, Incinerate burns it; a flung berry is eaten by its target.
    private mutating func berryAfterHit(_ move: BattleMove, by index: Int, on target: Int) {
        switch move.slug {
        case "knock-off", "incinerate":
            _ = takeBerry(target, by: nil)
        case "thief", "covet":
            guard heldBerry(index) == nil, let berry = takeBerry(target, by: index) else { return }
            giveBerry(berry, to: index)
        case "pluck", "bug-bite":
            guard let berry = takeBerry(target, by: index) else { return }
            eat(berry, by: index)
        case "fling":
            if let berry = battlers[index].throwing, !battlers[target].isFainted { eat(berry, by: target) }
        default:
            break
        }
    }

    private mutating func faint(_ index: Int, by attacker: Int?) {
        let id = battlers[index].spec.id
        battlers[index].castMove = nil
        log(.faint(battler: id))
        // Grudge: the move that knocked its user out is lost to the attacker for the battle.
        if battlers[index].grudge, let attacker, attacker != index, let move = battlers[attacker].lastMove {
            battlers[attacker].lostMoves.insert(move)
            log(.volatile(battler: battlers[attacker].spec.id, effect: "grudge"))
        }
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
        if fromFoe, amount < 0, sideHas(battlers[index].side, "mist") { return }
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
        if next < current { battlers[index].loweredAt = now }
        if next > current { battlers[index].raisedAt = now }
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
    /// The moves whose hits after the first each roll their accuracy.
    static let eachHitRolled: Set<String> = ["triple-kick", "triple-axel", "population-bomb"]
    /// The moves that cost their user half its HP when they do not land.
    static let crashMoves: Set<String> = ["jump-kick", "high-jump-kick", "axe-kick", "supercell-slam"]
    static let semiInvulnerableMoves: Set<String> = ["fly", "dig", "dive", "bounce", "phantom-force", "shadow-force",
                                                     "sky-drop"]
    /// The moves that reach a Pokémon out of reach, by where it hides.
    static let reachesHidden: [String: Set<String>] = [
        "fly": ["thunder", "hurricane", "gust", "twister", "sky-uppercut", "smack-down", "thousand-arrows"],
        "bounce": ["thunder", "hurricane", "gust", "twister", "sky-uppercut", "smack-down", "thousand-arrows"],
        "sky-drop": ["thunder", "hurricane", "gust", "twister", "sky-uppercut", "smack-down", "thousand-arrows"],
        "dig": ["earthquake", "magnitude", "fissure"],
        "dive": ["surf", "whirlpool"],
    ]
    static let doublesOnHidden: [String: Set<String>] = [
        "fly": ["gust", "twister"], "bounce": ["gust", "twister"], "sky-drop": ["gust", "twister"],
        "dig": ["earthquake", "magnitude"], "dive": ["surf", "whirlpool"],
    ]
    /// The moves that lock their user in, and for how many casts (0: two or three, then confusion).
    static let lockingMoves: [String: Int] = ["outrage": 0, "thrash": 0, "petal-dance": 0, "raging-fury": 0,
                                              "rollout": 5, "ice-ball": 5, "uproar": 3]
    /// The moves that break Reflect, Light Screen and Aurora Veil before they hit.
    static let screenBreakers: Set<String> = ["brick-break", "psychic-fangs", "raging-bull"]
    /// The moves whose success falls when one follows another.
    static let protectionMoves: Set<String> = ["protect", "detect", "kings-shield", "spiky-shield", "baneful-bunker",
        "obstruct", "silk-trap", "burning-bulwark", "endure", "wide-guard", "quick-guard", "mat-block"]
    /// The shields that stop damaging moves only.
    static let damageOnlyShields: Set<String> = ["kings-shield", "obstruct", "silk-trap", "burning-bulwark"]
    static let protectionBreakers: Set<String> = ["feint", "shadow-force", "phantom-force", "hyperspace-hole",
                                                  "hyperspace-fury"]

    /// The moves that use another in their place (`call`).
    static let callers: Set<String> = ["metronome", "assist", "sleep-talk", "copycat", "mirror-move", "me-first",
                                       "nature-power"]
    static let sleepMoves: Set<String> = ["sleep-talk", "snore"]
    /// What no calling or copying move uses: the callers and copiers, protections, moves aimed at an ally, those
    /// that answer a hit or wait for one, and Z and Max Moves (Metronome's list in the games, mostly).
    static let uncallable: Set<String> = [
        "after-you", "assist", "baneful-bunker", "beak-blast", "belch", "bestow", "bide", "burning-bulwark",
        "celebrate", "chatter", "comeuppance", "copycat", "counter", "covet", "crafty-shield", "destiny-bond", "detect",
        "endure", "feint", "focus-punch", "follow-me", "helping-hand", "hold-hands", "instruct", "kings-shield",
        "mat-block", "max-guard", "me-first", "metal-burst", "metronome", "mimic", "mirror-coat", "mirror-move",
        "nature-power", "obstruct", "protect", "quash", "quick-guard", "rage-powder", "shell-trap", "silk-trap",
        "sketch", "sleep-talk", "snatch", "snore", "spiky-shield", "spotlight", "struggle", "switcheroo", "thief",
        "transform", "trick", "wide-guard",
    ]
    static func canBeCalled(_ slug: String) -> Bool {
        !uncallable.contains(slug) && MoveTable.move(slug).map { !$0.isZOrMax } ?? false
    }
    /// Every move Metronome may use, in a fixed order for the seed.
    static let metronomePool: [String] = MoveTable.all.keys.filter(canBeCalled).sorted()

    /// The moves that send back the damage taken, and by how much.
    static let reactiveMoves: [String: Double] = ["counter": 2, "mirror-coat": 2, "bide": 2, "metal-burst": 1.5,
                                                  "comeuppance": 1.5]

    /// What a status move does, as the engine reads it: a move PokéAPI files as unique but that only changes stats
    /// (Shell Smash) counts as a stat move.
    static func statusKind(_ move: BattleMove) -> MoveMetaCategory {
        if move.category == .unique, !move.statChanges.isEmpty { return .netGoodStats }
        return move.category
    }

    /// The moves the engine plays, the others doing nothing here: the Pokémon sheet says so (`BattleMove.hasEffect`).
    static let handledStatusMoves = Set(["protect", "detect", "kings-shield", "spiky-shield", "baneful-bunker",
        "obstruct", "silk-trap", "burning-bulwark", "destiny-bond", "wish", "rest", "belly-drum", "pain-split",
        "transform", "mimic", "sketch", "instruct", "endure", "substitute", "wide-guard", "quick-guard", "crafty-shield",
        "mat-block", "magic-coat", "snatch", "reflect", "light-screen", "aurora-veil", "safeguard", "mist", "tailwind",
        "lucky-chant", "spikes", "toxic-spikes", "stealth-rock", "sticky-web", "trick-room", "gravity", "magic-room",
        "wonder-room", "haze", "mud-sport", "water-sport", "fairy-lock", "ion-deluge", "court-change", "defog", "tidy-up",
        "taunt", "encore", "disable", "torment", "imprison", "heal-block", "embargo", "perish-song", "nightmare", "ingrain",
        "aqua-ring", "foresight", "odor-sleuth", "miracle-eye", "telekinesis", "magnet-rise", "curse", "spite", "grudge",
        "lock-on", "mind-reader", "block", "mean-look", "spider-web", "octolock", "tar-shot", "no-retreat",
        "power-swap", "guard-swap", "heart-swap", "speed-swap", "power-split", "guard-split", "power-trick", "power-shift",
        "psych-up", "topsy-turvy", "acupressure", "soak", "magic-powder", "conversion", "conversion-2", "reflect-type",
        "camouflage", "forests-curse", "trick-or-treat", "electrify", "simple-beam", "worry-seed", "entrainment",
        "role-play", "skill-swap", "gastro-acid", "baton-pass", "shed-tail", "teleport", "roar", "whirlwind",
        "ally-switch", "follow-me", "rage-powder", "spotlight", "after-you", "quash", "helping-hand", "parting-shot",
        "trick", "switcheroo", "bestow", "recycle", "stuff-cheeks", "teatime", "corrosive-gas", "stockpile", "swallow",
        "memento", "healing-wish", "lunar-dance", "strength-sap", "purify", "jungle-healing", "lunar-blessing",
        "heal-bell", "aromatherapy", "refresh", "roost", "revival-blessing", "focus-energy", "laser-focus", "attract",
        "dragon-cheer", "shelter", "victory-dance", "take-heart", "powder", "psycho-shift", "doodle"])
    // Splash, Celebrate, Hold Hands and Happy Hour are played ("nothing happens") but do nothing, as in the games: the
    // loop editor shows them so and the suggestions never pick them.
        .union(callers)
        .union(weatherMoves.keys).union(terrainMoves.keys)
}
