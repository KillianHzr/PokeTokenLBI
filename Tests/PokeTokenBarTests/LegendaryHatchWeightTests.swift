import XCTest
@testable import PokeTokenBar

/// The egg roll weighs every line of a rarity the same (`PokemonOdds.hatchWeight`). Capture rate only decides the
/// rarity, and a legendary is one by its flag whatever its capture rate (Mew, Celebi, Rayquaza and Shaymin are 45,
/// Necrozma and Eternatus 255). These tests pin the rule at both places where candidates are built from PokéAPI data.
final class LegendaryHatchWeightTests: XCTestCase {
    private func graphQLRow(_ id: Int, _ captureRate: Int, legendary: Bool = false, mythical: Bool = false,
                            eggGroups: [String]) -> String {
        let groups = eggGroups.map { #"{"egggroup":{"name":"\#($0)"}}"# }.joined(separator: ",")
        return #"{"id":\#(id),"capture_rate":\#(captureRate),"is_legendary":\#(legendary),"is_mythical":\#(mythical),"pokemonegggroups":[\#(groups)]}"#
    }

    func testGraphQLIndexWeighsEachLineByItsRarity() throws {
        let rows = [
            graphQLRow(1, 45, eggGroups: ["monster", "plant"]),            // Bulbasaur: regular rare
            graphQLRow(151, 45, mythical: true, eggGroups: ["no-eggs"]),   // Mew
            graphQLRow(172, 190, eggGroups: ["no-eggs"]),                  // Pichu: baby, not legendary
            graphQLRow(384, 45, legendary: true, eggGroups: ["no-eggs"]),  // Rayquaza
            graphQLRow(489, 30, mythical: true, eggGroups: ["water1", "fairy"]),   // Phione: hatches from eggs
            graphQLRow(800, 255, legendary: true, eggGroups: ["no-eggs"]), // Necrozma
            graphQLRow(999, 45, legendary: true, eggGroups: []),           // missing egg group data
        ]
        let json = #"{"data":{"pokemonspecies":[\#(rows.joined(separator: ","))]}}"#
        let entries = try PokeAPIClient.baseIndexEntries(from: Data(json.utf8))
        XCTAssertEqual(entries.map(\.id), [1, 151, 172, 384, 489, 800, 999])
        XCTAssertEqual(entries.map(\.captureRate), [45, 45, 190, 45, 30, 255, 45], "capture_rate itself is kept")
        XCTAssertEqual(entries.map(\.hatchWeight), [40, 3, 212, 3, 3, 3, 3],
                       "rare, legendary, common, then legendaries whatever their capture rate, Phione too")
        XCTAssertEqual(entries.map(\.isLegendary), [false, true, false, true, true, true, true],
                       "the Azure Flute's targets: legendaries and mythicals, breedable or not")
    }

    func testRESTFallbackUsesTheSameLegendaryRule() throws {
        func species(_ captureRate: Int, mythical: Bool, eggGroups: [String]?, evolvesFrom: String? = nil) throws -> SpeciesDTO {
            let groups = eggGroups.map { "[" + $0.map { #"{"name":"\#($0)","url":null}"# }.joined(separator: ",") + "]" } ?? "null"
            let from = evolvesFrom.map { #"{"name":"\#($0)","url":null}"# } ?? "null"
            let json = #"{"capture_rate":\#(captureRate),"is_legendary":false,"is_mythical":\#(mythical),"names":[],"evolution_chain":{"url":"https://pokeapi.co/api/v2/evolution-chain/1/"},"evolves_from_species":\#(from),"gender_rate":-1,"egg_groups":\#(groups)}"#
            return try JSONDecoder().decode(SpeciesDTO.self, from: Data(json.utf8))
        }
        let mew = PokeAPIClient.baseSpecies(id: 151, species: try species(45, mythical: true, eggGroups: ["no-eggs"]))
        let phione = PokeAPIClient.baseSpecies(id: 489, species: try species(30, mythical: true, eggGroups: ["water1", "fairy"]))
        let noGroups = PokeAPIClient.baseSpecies(id: 251, species: try species(45, mythical: true, eggGroups: nil))
        XCTAssertEqual(mew?.hatchWeight, 3)
        XCTAssertEqual(phione?.hatchWeight, 3, "a legendary, though it hatches from eggs in the games")
        XCTAssertEqual(noGroups?.hatchWeight, 3, "a response without egg_groups must not restore the capture_rate weight")
        XCTAssertEqual([mew, phione, noGroups].map { $0?.isLegendary }, [true, true, true])
        XCTAssertNil(PokeAPIClient.baseSpecies(id: 2, species: try species(45, mythical: false, eggGroups: ["monster"],
                                                                         evolvesFrom: "bulbasaur")),
                     "an evolved species is still not a hatch candidate")
    }

    /// base-index.json lives 30 days. An index cached before the flag existed must not decode, or the
    /// app keeps rolling Mew at weight 45 until it expires.
    func testBaseIndexCachedWithoutTheFlagIsNotReused() {
        XCTAssertThrowsError(try JSONDecoder().decode(BaseSpecies.self, from: Data(#"{"id":151,"captureRate":45}"#.utf8)))
        // Nor one cached before `isLegendary`, or the Azure Flute keeps boosting Beldum until it expires.
        XCTAssertThrowsError(try JSONDecoder().decode(BaseSpecies.self, from: Data(
            #"{"id":374,"captureRate":3,"isUnbreedableLegendary":false}"#.utf8)))
        let current = BaseSpecies(id: 151, captureRate: 45, isUnbreedableLegendary: true)
        let roundTrip = try? JSONDecoder().decode(BaseSpecies.self, from: JSONEncoder().encode(current))
        XCTAssertEqual(roundTrip?.hatchWeight, 3)
    }
}
