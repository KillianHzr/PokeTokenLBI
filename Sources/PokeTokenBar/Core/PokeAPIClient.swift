import Foundation

/// 부화 후보 — 진화라인 시작점(base) 종과 공식 희귀도.
struct BaseSpecies: Sendable, Codable {
    let id: Int
    let captureRate: Int    // 3(뮤츠급)~255(캐터피급), 공식 희귀도 신호
    /// Legendary or mythical species that no game lets hatch from an egg. Required when decoding: a base index
    /// cached before this field existed fails to decode and is fetched again.
    let isUnbreedableLegendary: Bool
    /// Legendary or mythical (PokéAPI `is_legendary`/`is_mythical`): the Azure Flute's target. Required when
    /// decoding, like `isUnbreedableLegendary`, so an index cached before it is fetched again.
    let isLegendary: Bool

    init(id: Int, captureRate: Int, isUnbreedableLegendary: Bool = false, isLegendary: Bool? = nil) {
        self.id = id
        self.captureRate = captureRate
        self.isUnbreedableLegendary = isUnbreedableLegendary
        self.isLegendary = isLegendary ?? isUnbreedableLegendary
    }

    /// The species' rarity, as its card shows it: legendary by its flag, the others by capture rate.
    var rarity: Rarity { Rarity.from(captureRate: captureRate, isLegendary: isLegendary, isMythical: false) }

    /// Weight of this species in the egg roll (`CompanionStore.chooseBase`): its rarity's, the same for every
    /// line of a rarity. Capture rate measures how hard a Pokémon is to catch with a ball, not how rare it is
    /// in an egg: it only decides the rarity.
    var hatchWeight: Int { PokemonOdds.hatchWeight(rarity) }

    /// Phione and Manaphy are the only legendary or mythical species with an egg group other than
    /// "no-eggs" (Phione hatches from Manaphy's egg in the games), so they keep their capture_rate.
    /// Missing egg group data counts as unbreedable: a legendary never falls back to a common weight.
    static func isUnbreedableLegendary(isLegendary: Bool, isMythical: Bool, eggGroups: [String]) -> Bool {
        (isLegendary || isMythical) && !eggGroups.contains { $0 != "no-eggs" }
    }
}

/// 포켓몬 라인 데이터 제공(주입 가능 — 테스트는 스텁 사용).
protocol PokeProviding: Sendable {
    func line(baseSpeciesID: Int) async throws -> EvoLine
    /// 1~5세대 base 전체 인덱스 (GraphQL 1쿼리, 디스크 캐시).
    func baseSpeciesIndex() async throws -> [BaseSpecies]
    /// 단일 종이 base(진화 시작점)면 BaseSpecies, 아니면 nil.
    /// GraphQL 인덱스 엔드포인트 장애 시 REST(pokemon-species)로 부화 후보를 뽑는 폴백용.
    func baseSpecies(id: Int) async throws -> BaseSpecies?
}

/// Separate from `PokeProviding` so existing evolution-only test doubles stay small.
protocol PokemonDetailProviding: Sendable {
    func pokemonDetails(speciesID: Int) async throws -> PokemonDetails
    /// One variety's data: a species' default form (`pokemonID == speciesID`) or a form of its own.
    func pokemonDetails(pokemonID: Int, speciesID: Int) async throws -> PokemonDetails
}

extension PokemonDetailProviding {
    /// Test doubles that model one form per species answer every variety with it.
    func pokemonDetails(pokemonID: Int, speciesID: Int) async throws -> PokemonDetails {
        try await pokemonDetails(speciesID: speciesID)
    }
}

/// PokéAPI 클라이언트 — 종/진화체인을 런타임 fetch + 파싱. 포켓몬 데이터는 레포에 번들하지 않는다.
/// species 응답은 actor 캐시(다국어 이름 재사용).
actor PokeAPIClient: PokeProviding, PokemonDetailProviding {
    static let shared = PokeAPIClient()
    private let base = URL(string: "https://pokeapi.co/api/v2")!
    static var langCodes: [String] { AppLanguage.allCases.flatMap(\.apiCodes) }
    private var speciesCache: [Int: SpeciesDTO] = [:]
    private var lineCache: [Int: EvoLine] = [:]   // 프리패칭 → 부화 순간 네트워크 0
    private var detailsCache: [Int: PokemonDetails] = [:]

    private static let detailsDirectory: URL = {
        let dir = AppStatePaths.directory().appendingPathComponent("pokemon-details-v1", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private struct DetailSnapshot: Codable {
        let fetchedAt: Date
        let details: PokemonDetails
    }

    /// Default-form battle metadata.
    func pokemonDetails(speciesID: Int) async throws -> PokemonDetails {
        try await pokemonDetails(pokemonID: speciesID, speciesID: speciesID)
    }

    /// Battle metadata of one variety, keyed by its `pokemon` id: an Alolan Vulpix reads `pokemon/10103`, and its
    /// species for the gender rate. Memory → 30-day disk cache → REST, with stale disk fallback offline.
    func pokemonDetails(pokemonID: Int, speciesID: Int) async throws -> PokemonDetails {
        if let cached = detailsCache[pokemonID] { return cached }
        let file = Self.detailsDirectory.appendingPathComponent("\(pokemonID).json")
        let disk = (try? Data(contentsOf: file))
            .flatMap { try? JSONDecoder().decode(DetailSnapshot.self, from: $0) }
        if let disk, Date().timeIntervalSince(disk.fetchedAt) < 30 * 86400 {
            detailsCache[pokemonID] = disk.details
            return disk.details
        }
        do {
            let dto: PokemonDTO = try await get(base.appendingPathComponent("pokemon/\(pokemonID)"))
            let speciesDTO = try await species(speciesID)
            let details = PokemonDetails(
                speciesID: speciesID,
                name: dto.name,
                height: dto.height,
                weight: dto.weight,
                baseExperience: dto.base_experience,
                genderRate: speciesDTO.gender_rate ?? -1,
                types: dto.types.sorted { $0.slot < $1.slot }.map { $0.type.name },
                baseStats: Dictionary(uniqueKeysWithValues: dto.stats.map { ($0.stat.name, $0.base_stat) }),
                abilities: dto.abilities.map {
                    PokemonAbilityOption(name: $0.ability.name, slot: $0.slot, isHidden: $0.is_hidden)
                }.sorted { $0.slot < $1.slot },
                moves: Self.normalizedMoves(dto.moves, for: speciesID))
            detailsCache[pokemonID] = details
            if let data = try? JSONEncoder().encode(DetailSnapshot(fetchedAt: Date(), details: details)) {
                try? data.write(to: file, options: .atomic)
            }
            return details
        } catch {
            if let disk {
                detailsCache[pokemonID] = disk.details
                return disk.details
            }
            throw error
        }
    }

    /// Reduce PokéAPI's cross-generation move history at the trust boundary, before it reaches
    /// either memory or disk. Moves absent from the supported version group are omitted entirely.
    static func normalizedMoves(_ moves: [PokemonMoveDTO], for speciesID: Int? = nil) -> [PokemonMoveOption] {
        // A regional form is missing from its species' games (no Alolan Vulpix in Black 2): then the first game
        // that has it, in release order from Sun and Moon.
        let targets = (speciesID.map(PokemonDetails.preferredVersionGroups(for:)) ?? [PokemonDetails.preferredVersionGroup])
            + PokemonDetails.formVersionGroups
        let chosenGroup = targets.first { target in
            moves.contains { move in move.version_group_details.contains { $0.version_group.name == target } }
        } ?? targets[0]
        return moves.compactMap { move in
            let methods = move.version_group_details.compactMap { row -> PokemonMoveLearnMethod? in
                guard row.version_group.name == chosenGroup else { return nil }
                return PokemonMoveLearnMethod(method: row.move_learn_method.name,
                                              level: row.level_learned_at)
            }
            guard !methods.isEmpty else { return nil }
            return PokemonMoveOption(name: move.move.name, learnMethods: methods)
        }.sorted { $0.name < $1.name }
    }

    func line(baseSpeciesID: Int) async throws -> EvoLine {
        if let cached = lineCache[baseSpeciesID] { return cached }
        let baseSpecies = try await species(baseSpeciesID)
        // PokéAPI 응답의 URL — 비정상/빈 값이면 force-unwrap 대신 throw(앱은 알 상태 유지).
        guard let chainURL = Self.validatedChainURL(baseSpecies.evolution_chain.url) else {
            throw URLError(.badURL)
        }
        let chainDTO: ChainDTO = try await get(chainURL)
        let tree = node(from: chainDTO.chain)
        let rarity = Rarity.from(captureRate: baseSpecies.capture_rate,
                                 isLegendary: baseSpecies.is_legendary,
                                 isMythical: baseSpecies.is_mythical)
        // Keep all API languages so later app-language additions can reuse persisted names.
        var names: [Int: [String: String]] = [:]
        for id in allIDs(tree) {
            let sp = try await species(id)
            names[id] = PokemonNameLocalization.collect(sp.names)
        }
        let line = EvoLine(baseID: baseSpeciesID, tree: tree, rarity: rarity, names: names)
        lineCache[baseSpeciesID] = line
        return line
    }

    // MARK: base 인덱스 (부화 후보)

    private var baseIndexCache: [BaseSpecies]?
    private var restBuildInFlight = false
    private var restBuildTried = false   // 세션당 1회 (GraphQL 다운 시 REST 인덱스 구축 트리거)
    private static let baseIndexFile: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PokeTokenBar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("base-index.json")
    }()
    /// `maxSpeciesID` is the last national dex number the index was fetched up to: nil for snapshots written
    /// before the field existed, which stopped at #649.
    struct BaseIndexSnapshot: Codable {
        let fetchedAt: Date
        let entries: [BaseSpecies]
        var maxSpeciesID: Int?
    }

    /// Whether a cached index can be reused without fetching: younger than 30 days and fetched for the species
    /// range that hatches now. An index cached before the Gen 6 to 9 range existed would otherwise keep them out
    /// of every egg for up to a month.
    static func isFreshBaseIndex(_ snapshot: BaseIndexSnapshot, now: Date = Date()) -> Bool {
        now.timeIntervalSince(snapshot.fetchedAt) < 30 * 86400
            && snapshot.maxSpeciesID == PokemonAssets.animatedSpeciesIDs.upperBound
            && !snapshot.entries.isEmpty
    }
    private struct GraphQLBaseResponse: Decodable {
        struct DataBox: Decodable { let pokemonspecies: [Row] }
        struct Row: Decodable {
            let id: Int
            let capture_rate: Int
            let is_legendary: Bool
            let is_mythical: Bool
            let pokemonegggroups: [EggGroupLink]
        }
        struct EggGroupLink: Decodable {
            struct Group: Decodable { let name: String }
            let egggroup: Group?
        }
        let data: DataBox
    }

    /// GraphQL base index response → candidates. Split from the fetch so the legendary rule is testable offline.
    static func baseIndexEntries(from data: Data) throws -> [BaseSpecies] {
        try JSONDecoder().decode(GraphQLBaseResponse.self, from: data).data.pokemonspecies.map {
            BaseSpecies(id: $0.id, captureRate: $0.capture_rate,
                        isUnbreedableLegendary: BaseSpecies.isUnbreedableLegendary(
                            isLegendary: $0.is_legendary, isMythical: $0.is_mythical,
                            eggGroups: $0.pokemonegggroups.compactMap { $0.egggroup?.name }),
                        isLegendary: $0.is_legendary || $0.is_mythical)
        }
    }

    /// 부화 가능한 범위(`PokemonAssets.animatedSpeciesIDs`)의 base(진화라인 시작점) 전체 — PokéAPI GraphQL 1쿼리.
    /// 우선순위: 메모리 캐시 → 디스크 캐시(30일 TTL, 같은 범위일 때만) → GraphQL fetch(성공 시 디스크 갱신)
    /// → TTL 지난 디스크라도 있으면 사용(오프라인 폴백). 전부 실패 시 throw(알 유지, 다음 틱 재시도).
    func baseSpeciesIndex() async throws -> [BaseSpecies] {
        if let c = baseIndexCache { return c }
        let disk = (try? Data(contentsOf: Self.baseIndexFile))
            .flatMap { try? JSONDecoder().decode(BaseIndexSnapshot.self, from: $0) }
        if let disk, Self.isFreshBaseIndex(disk) {
            baseIndexCache = disk.entries
            return disk.entries
        }
        do {
            let entries = try await fetchBaseIndex()
            baseIndexCache = entries
            if let data = try? JSONEncoder().encode(BaseIndexSnapshot(
                fetchedAt: Date(), entries: entries, maxSpeciesID: PokemonAssets.animatedSpeciesIDs.upperBound)) {
                try? data.write(to: Self.baseIndexFile, options: .atomic)
            }
            return entries
        } catch {
            if let disk, !disk.entries.isEmpty {   // 오프라인 — 오래된 인덱스라도 사용
                baseIndexCache = disk.entries
                return disk.entries
            }
            // GraphQL 다운 + 캐시 없음 → REST 로 인덱스를 백그라운드 구축(세션 1회).
            // 이번 부화는 per-hatch REST 폴백(chooseBaseViaREST)이 즉시 처리하고,
            // 구축이 끝나면 디스크 캐시로 남아 이후 선택이 가중·수집반영·오프라인가능으로 복귀한다.
            if !restBuildTried {
                restBuildTried = true
                Task { await self.buildBaseIndexViaREST() }
            }
            AppLog.write("base index (GraphQL) failed, no cache — REST build triggered; per-hatch fallback handles now: \(error)")
            throw error
        }
    }

    /// GraphQL base 인덱스 엔드포인트 장애 시 REST(pokemon-species/{id})로 base 인덱스를 직접 구축·영속.
    /// 한 번 성공하면 base-index.json(30일)으로 남아 이후 선택은 네트워크 없이 가중·수집반영으로 동작 →
    /// 부화가 특정 엔드포인트 생존에 영구히 묶이지 않게 하는 자가치유 캐시. PokéAPI 배려로 소규모 동시성.
    func buildBaseIndexViaREST() async {
        guard baseIndexCache == nil, !restBuildInFlight else { return }
        restBuildInFlight = true
        defer { restBuildInFlight = false }
        AppLog.write("base index: building via REST (GraphQL unavailable)…")
        var bases: [BaseSpecies] = []
        let batchSize = 6
        var start = 1
        let maxID = PokemonAssets.animatedSpeciesIDs.upperBound
        while start <= maxID {
            let end = min(start + batchSize - 1, maxID)
            let found = await withTaskGroup(of: BaseSpecies?.self) { group -> [BaseSpecies] in
                for id in start...end { group.addTask { try? await self.baseSpecies(id: id) } }
                var acc: [BaseSpecies] = []
                for await r in group { if let r { acc.append(r) } }
                return acc
            }
            bases.append(contentsOf: found)
            start += batchSize
        }
        // 대부분 실패(네트워크 불안정)면 빈약한 인덱스를 영속하지 않고 다음 세션 재시도.
        guard bases.count >= 150 else {
            AppLog.write("base index: REST build incomplete (\(bases.count)) — not cached, will retry next session")
            return
        }
        bases.sort { $0.id < $1.id }
        baseIndexCache = bases
        if let data = try? JSONEncoder().encode(BaseIndexSnapshot(fetchedAt: Date(), entries: bases, maxSpeciesID: maxID)) {
            try? data.write(to: Self.baseIndexFile, options: .atomic)
        }
        AppLog.write("base index: REST build done — \(bases.count) bases persisted (offline-capable now)")
    }

    private func fetchBaseIndex() async throws -> [BaseSpecies] {
        // 공식 GraphQL — evolves_from IS NULL(=base) + id ≤ 649(Gen-V 애니메이션 스프라이트 상한)
        guard let url = URL(string: "https://graphql.pokeapi.co/v1beta2") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 메타몽(#132)은 위장 리빌 전용 → 일반 부화 풀에서 제외(_neq).
        let maxID = PokemonAssets.animatedSpeciesIDs.upperBound
        let query = "{ pokemonspecies(where: {evolves_from_species_id: {_is_null: true}, id: {_lte: \(maxID), _neq: \(PokemonOdds.dittoSpeciesID)}}, order_by: {id: asc}) { id capture_rate is_legendary is_mythical pokemonegggroups { egggroup { name } } } }"
        req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let entries = try Self.baseIndexEntries(from: data)
        guard !entries.isEmpty else { throw URLError(.cannotParseResponse) }
        return entries
    }

    private func species(_ id: Int) async throws -> SpeciesDTO {
        if let c = speciesCache[id] { return c }
        let dto: SpeciesDTO = try await get(base.appendingPathComponent("pokemon-species/\(id)"))
        speciesCache[id] = dto
        return dto
    }

    /// REST 폴백 — 단일 종 상세(pokemon-species/{id})로 base 여부·capture_rate 판정.
    /// GraphQL base 인덱스가 죽어도 REST(pokeapi.co/api/v2)는 별개 엔드포인트라 동작한다.
    func baseSpecies(id: Int) async throws -> BaseSpecies? {
        guard id != PokemonOdds.dittoSpeciesID else { return nil }   // 메타몽은 위장 리빌 전용 — 일반 부화 제외
        let dto = try await species(id)
        return Self.baseSpecies(id: id, species: dto)
    }

    /// REST species → candidate, with the same legendary rule as the GraphQL index.
    static func baseSpecies(id: Int, species dto: SpeciesDTO) -> BaseSpecies? {
        guard dto.evolves_from_species == nil else { return nil }   // 진화 중간체는 부화 후보 아님
        return BaseSpecies(id: id, captureRate: dto.capture_rate,
                           isUnbreedableLegendary: BaseSpecies.isUnbreedableLegendary(
                               isLegendary: dto.is_legendary, isMythical: dto.is_mythical,
                               eggGroups: (dto.egg_groups ?? []).map(\.name)),
                           isLegendary: dto.is_legendary || dto.is_mythical)
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func node(from link: ChainLink) -> EvoNode {
        EvoNode(speciesID: Self.id(from: link.species.url ?? ""),
                children: link.evolves_to.map(node(from:)))
    }
    private func allIDs(_ n: EvoNode) -> [Int] { [n.speciesID] + n.children.flatMap(allIDs) }

    static func id(from speciesURL: String) -> Int {
        // ".../pokemon-species/{id}/"
        let parts = speciesURL.split(separator: "/").filter { !$0.isEmpty }
        return Int(parts.last ?? "0") ?? 0
    }

    /// PokéAPI evolution_chain URL 검증(SSRF 가드) — 서버 제어 문자열이므로 https + pokeapi.co 로 고정해
    /// 응답 변조 시 임의 호스트 fetch 를 막는다. 부적합하면 nil(호출부가 throw → 앱은 알 상태 유지).
    static func validatedChainURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme == "https", url.host == "pokeapi.co" else { return nil }
        return url
    }
}

// MARK: - DTO (PokéAPI 응답 부분 디코드)

struct SpeciesDTO: Decodable, Sendable {
    let capture_rate: Int
    let is_legendary: Bool
    let is_mythical: Bool
    let names: [NameDTO]
    let evolution_chain: URLRef
    let evolves_from_species: NamedRef?   // nil = 진화라인 시작점(base)
    let gender_rate: Int?
    let egg_groups: [NamedRef]?
}
struct NameDTO: Decodable, Sendable { let name: String; let language: NamedRef }
struct NamedRef: Decodable, Sendable { let name: String; let url: String? }
struct URLRef: Decodable, Sendable { let url: String }
struct ChainDTO: Decodable, Sendable { let chain: ChainLink }
struct ChainLink: Decodable, Sendable {
    let species: NamedRef
    let evolves_to: [ChainLink]
}

struct PokemonDTO: Decodable, Sendable {
    let name: String
    let height: Int
    let weight: Int
    let base_experience: Int?
    let types: [PokemonTypeDTO]
    let abilities: [PokemonAbilityDTO]
    let stats: [PokemonStatDTO]
    let moves: [PokemonMoveDTO]
}
struct PokemonTypeDTO: Decodable, Sendable { let slot: Int; let type: NamedRef }
struct PokemonAbilityDTO: Decodable, Sendable {
    let is_hidden: Bool
    let slot: Int
    let ability: NamedRef
}
struct PokemonStatDTO: Decodable, Sendable { let base_stat: Int; let stat: NamedRef }
struct PokemonMoveDTO: Decodable, Sendable {
    let move: NamedRef
    let version_group_details: [PokemonMoveVersionDTO]
}
struct PokemonMoveVersionDTO: Decodable, Sendable {
    let level_learned_at: Int
    let move_learn_method: NamedRef
    let version_group: NamedRef
}
