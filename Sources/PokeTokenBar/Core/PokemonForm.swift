import Foundation

/// An individual's appearance within a species: Unown's letter, Shaymin's Sky Forme, Shellos's sea.
///
/// The value belongs to the individual and is resolved per species of its line, so a Sandy Burmy
/// becomes a Sandy Wormadam while the Mothim branch keeps Mothim's single appearance. Species IDs
/// and evolution paths are unchanged; the form only selects sprites, names and collection slots.
struct PokemonForm: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }

    static let unownSpeciesID = 201

    /// Unown shows its letter instead of a localized form name.
    var symbol: String {
        switch rawValue {
        case "exclamation": return "!"
        case "question": return "?"
        default: return rawValue.uppercased()
        }
    }

    // MARK: Catalog

    /// `pokemonID` is the PokéAPI variety whose static PNG holds this form (`10006.png` for Sky
    /// Shaymin); nil means the static sprite is named like the animated one (`412-sandy.png`).
    /// `formID` is the PokéAPI `pokemon-form` resource that carries the localized form names.
    struct Entry: Sendable {
        let form: PokemonForm
        let formID: Int
        let pokemonID: Int?
        /// The static PNG's name where it differs from the GIF's: Alcremie's keep PokéAPI's "-sweet".
        let pngName: String?

        init(_ rawValue: String, formID: Int, pokemonID: Int? = nil, pngName: String? = nil) {
            form = PokemonForm(rawValue)
            self.formID = formID
            self.pokemonID = pokemonID
            self.pngName = pngName
        }
    }

    /// Every catalogued species lists its default appearance first; that one keeps the plain
    /// `<id>.png`/`<id>.gif` sprites. Only forms with a Gen V animated sprite are listed, the same
    /// source that bounds hatchable species. Gender differences are not forms.
    static let catalog: [Int: [Entry]] = {
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init) + ["exclamation", "question"]
        let unown = letters.enumerated().map { index, letter in
            Entry(letter, formID: index == 0 ? unownSpeciesID : 10000 + index)
        }
        return [
            unownSpeciesID: unown,
            351: [.init("normal", formID: 351), .init("sunny", formID: 10028, pokemonID: 10013),
                  .init("rainy", formID: 10029, pokemonID: 10014), .init("snowy", formID: 10030, pokemonID: 10015)],
            386: [.init("normal", formID: 386), .init("attack", formID: 10031, pokemonID: 10001),
                  .init("defense", formID: 10032, pokemonID: 10002), .init("speed", formID: 10033, pokemonID: 10003)],
            412: [.init("plant", formID: 412), .init("sandy", formID: 10034), .init("trash", formID: 10035)],
            413: [.init("plant", formID: 413), .init("sandy", formID: 10036, pokemonID: 10004),
                  .init("trash", formID: 10037, pokemonID: 10005)],
            421: [.init("overcast", formID: 421), .init("sunshine", formID: 10038)],
            422: [.init("west", formID: 422), .init("east", formID: 10039)],
            423: [.init("west", formID: 423), .init("east", formID: 10040)],
            479: [.init("normal", formID: 479), .init("heat", formID: 10058, pokemonID: 10008),
                  .init("wash", formID: 10059, pokemonID: 10009), .init("frost", formID: 10060, pokemonID: 10010),
                  .init("fan", formID: 10061, pokemonID: 10011), .init("mow", formID: 10062, pokemonID: 10012)],
            487: [.init("altered", formID: 487), .init("origin", formID: 10063, pokemonID: 10007)],
            492: [.init("land", formID: 492), .init("sky", formID: 10064, pokemonID: 10006)],
            493: [.init("normal", formID: 493), .init("fighting", formID: 10045), .init("flying", formID: 10047),
                  .init("poison", formID: 10052), .init("ground", formID: 10050), .init("rock", formID: 10054),
                  .init("bug", formID: 10041), .init("ghost", formID: 10048), .init("steel", formID: 10055),
                  .init("fire", formID: 10046), .init("water", formID: 10056), .init("grass", formID: 10049),
                  .init("electric", formID: 10044), .init("psychic", formID: 10053), .init("ice", formID: 10051),
                  .init("dragon", formID: 10043), .init("dark", formID: 10042), .init("fairy", formID: 10085)],
            550: [.init("red-striped", formID: 550), .init("blue-striped", formID: 10066, pokemonID: 10016),
                  .init("white-striped", formID: 10416, pokemonID: 10247)],
            555: [.init("standard", formID: 555), .init("zen", formID: 10067, pokemonID: 10017),
                  .init("galar-standard", formID: 10336, pokemonID: 10177),
                  .init("galar-zen", formID: 10337, pokemonID: 10178)],
            585: [.init("spring", formID: 585), .init("summer", formID: 10068),
                  .init("autumn", formID: 10069), .init("winter", formID: 10070)],
            586: [.init("spring", formID: 586), .init("summer", formID: 10071),
                  .init("autumn", formID: 10072), .init("winter", formID: 10073)],
            641: [.init("incarnate", formID: 641), .init("therian", formID: 10079, pokemonID: 10019)],
            642: [.init("incarnate", formID: 642), .init("therian", formID: 10080, pokemonID: 10020)],
            645: [.init("incarnate", formID: 645), .init("therian", formID: 10081, pokemonID: 10021)],
            646: [.init("normal", formID: 646), .init("black", formID: 10082, pokemonID: 10022),
                  .init("white", formID: 10083, pokemonID: 10023)],
            647: [.init("ordinary", formID: 647), .init("resolute", formID: 10084, pokemonID: 10024)],
            648: [.init("aria", formID: 648), .init("pirouette", formID: 10074, pokemonID: 10018)],
            649: [.init("normal", formID: 649), .init("douse", formID: 10075), .init("shock", formID: 10076),
                  .init("burn", formID: 10077), .init("chill", formID: 10078)],
            // MARK: Gen 6 (Kalos)
            666: [
                .init("meadow", formID: 666),
                .init("icy-snow", formID: 10086),
                .init("polar", formID: 10087),
                .init("tundra", formID: 10088),
                .init("continental", formID: 10089),
                .init("garden", formID: 10090),
                .init("elegant", formID: 10091),
                .init("modern", formID: 10092),
                .init("marine", formID: 10093),
                .init("archipelago", formID: 10094),
                .init("high-plains", formID: 10095),
                .init("sandstorm", formID: 10096),
                .init("river", formID: 10097),
                .init("monsoon", formID: 10098),
                .init("savanna", formID: 10099),
                .init("sun", formID: 10100),
                .init("ocean", formID: 10101),
                .init("jungle", formID: 10102),
                .init("fancy", formID: 10161),
                .init("poke-ball", formID: 10162),
            ],
            669: [
                .init("red", formID: 669),
                .init("yellow", formID: 10103),
                .init("orange", formID: 10104),
                .init("blue", formID: 10105),
                .init("white", formID: 10106),
            ],
            670: [
                .init("red", formID: 670),
                .init("yellow", formID: 10107),
                .init("orange", formID: 10108),
                .init("blue", formID: 10109),
                .init("white", formID: 10110),
            ],
            671: [
                .init("red", formID: 671),
                .init("yellow", formID: 10111),
                .init("orange", formID: 10112),
                .init("blue", formID: 10113),
                .init("white", formID: 10114),
            ],
            676: [
                .init("natural", formID: 676),
                .init("heart", formID: 10115),
                .init("star", formID: 10116),
                .init("diamond", formID: 10117),
                .init("debutante", formID: 10118),
                .init("matron", formID: 10119),
                .init("dandy", formID: 10120),
                .init("la-reine", formID: 10121),
                .init("kabuki", formID: 10122),
                .init("pharaoh", formID: 10123),
            ],
            678: [
                .init("male", formID: 678),
                .init("female", formID: 10124, pokemonID: 10025),
            ],
            681: [
                .init("shield", formID: 681),
                .init("blade", formID: 10125, pokemonID: 10026),
            ],
            710: [
                .init("average", formID: 710),
                .init("small", formID: 10126, pokemonID: 10027),
                .init("large", formID: 10127, pokemonID: 10028),
                .init("super", formID: 10128, pokemonID: 10029),
            ],
            711: [
                .init("average", formID: 711),
                .init("small", formID: 10129, pokemonID: 10030),
                .init("large", formID: 10130, pokemonID: 10031),
                .init("super", formID: 10131, pokemonID: 10032),
            ],
            718: [
                .init("50", formID: 718),
                .init("10", formID: 10340, pokemonID: 10181),
                .init("complete", formID: 10222, pokemonID: 10120),
            ],
            // MARK: Gen 7 (Alola) & Alolan Regional Forms
            19: [.init("normal", formID: 19), .init("alola", formID: 10193, pokemonID: 10091)],
            20: [.init("normal", formID: 20), .init("alola", formID: 10194, pokemonID: 10092)],
            26: [.init("normal", formID: 26), .init("alola", formID: 10202, pokemonID: 10100)],
            27: [.init("normal", formID: 27), .init("alola", formID: 10203, pokemonID: 10101)],
            28: [.init("normal", formID: 28), .init("alola", formID: 10204, pokemonID: 10102)],
            37: [.init("normal", formID: 37), .init("alola", formID: 10205, pokemonID: 10103)],
            38: [.init("normal", formID: 38), .init("alola", formID: 10206, pokemonID: 10104)],
            50: [.init("normal", formID: 50), .init("alola", formID: 10207, pokemonID: 10105)],
            51: [.init("normal", formID: 51), .init("alola", formID: 10208, pokemonID: 10106)],
            52: [.init("normal", formID: 52), .init("alola", formID: 10209, pokemonID: 10107),
                 .init("galar", formID: 10320, pokemonID: 10161)],
            53: [.init("normal", formID: 53), .init("alola", formID: 10210, pokemonID: 10108)],
            74: [.init("normal", formID: 74), .init("alola", formID: 10211, pokemonID: 10109)],
            75: [.init("normal", formID: 75), .init("alola", formID: 10212, pokemonID: 10110)],
            76: [.init("normal", formID: 76), .init("alola", formID: 10213, pokemonID: 10111)],
            88: [.init("normal", formID: 88), .init("alola", formID: 10214, pokemonID: 10112)],
            89: [.init("normal", formID: 89), .init("alola", formID: 10215, pokemonID: 10113)],
            103: [.init("normal", formID: 103), .init("alola", formID: 10216, pokemonID: 10114)],
            105: [.init("normal", formID: 105), .init("alola", formID: 10217, pokemonID: 10115)],
            741: [
                .init("baile", formID: 741),
                .init("pom-pom", formID: 10225, pokemonID: 10123),
                .init("pau", formID: 10226, pokemonID: 10124),
                .init("sensu", formID: 10227, pokemonID: 10125),
            ],
            745: [
                .init("midday", formID: 745),
                .init("midnight", formID: 10228, pokemonID: 10126),
                .init("dusk", formID: 10311, pokemonID: 10152),
            ],
            746: [
                .init("solo", formID: 746),
                .init("school", formID: 10229, pokemonID: 10127),
            ],
            773: [
                .init("normal", formID: 773), .init("fighting", formID: 10232), .init("flying", formID: 10233),
                .init("poison", formID: 10234), .init("ground", formID: 10235), .init("rock", formID: 10236),
                .init("bug", formID: 10237), .init("ghost", formID: 10238), .init("steel", formID: 10239),
                .init("fire", formID: 10240), .init("water", formID: 10241), .init("grass", formID: 10242),
                .init("electric", formID: 10243), .init("psychic", formID: 10244), .init("ice", formID: 10245),
                .init("dragon", formID: 10246), .init("dark", formID: 10247), .init("fairy", formID: 10248),
            ],
            774: [
                .init("meteor", formID: 774),
                .init("red", formID: 10255, pokemonID: 10136),
                .init("orange", formID: 10256, pokemonID: 10137),
                .init("yellow", formID: 10257, pokemonID: 10138),
                .init("green", formID: 10258, pokemonID: 10139),
                .init("blue", formID: 10259, pokemonID: 10140),
                .init("indigo", formID: 10260, pokemonID: 10141),
                .init("violet", formID: 10261, pokemonID: 10142),
            ],
            778: [
                .init("disguised", formID: 778),
                .init("busted", formID: 10262, pokemonID: 10143),
            ],
            800: [
                .init("normal", formID: 800),
                .init("dusk", formID: 10314, pokemonID: 10155),
                .init("dawn", formID: 10315, pokemonID: 10156),
                .init("ultra", formID: 10316, pokemonID: 10157),
            ],
            801: [
                .init("normal", formID: 801),
                .init("original", formID: 10266, pokemonID: 10147),
            ],
            // MARK: Gen 8 (Galar & Hisui) & Regional Forms
            77: [.init("normal", formID: 77), .init("galar", formID: 10321, pokemonID: 10162)],
            78: [.init("normal", formID: 78), .init("galar", formID: 10322, pokemonID: 10163)],
            79: [.init("normal", formID: 79), .init("galar", formID: 10323, pokemonID: 10164)],
            80: [.init("normal", formID: 80), .init("galar", formID: 10324, pokemonID: 10165)],
            83: [.init("normal", formID: 83), .init("galar", formID: 10325, pokemonID: 10166)],
            110: [.init("normal", formID: 110), .init("galar", formID: 10326, pokemonID: 10167)],
            122: [.init("normal", formID: 122), .init("galar", formID: 10327, pokemonID: 10168)],
            144: [.init("normal", formID: 144), .init("galar", formID: 10328, pokemonID: 10169)],
            145: [.init("normal", formID: 145), .init("galar", formID: 10329, pokemonID: 10170)],
            146: [.init("normal", formID: 146), .init("galar", formID: 10330, pokemonID: 10171)],
            199: [.init("normal", formID: 199), .init("galar", formID: 10331, pokemonID: 10172)],
            222: [.init("normal", formID: 222), .init("galar", formID: 10332, pokemonID: 10173)],
            263: [.init("normal", formID: 263), .init("galar", formID: 10333, pokemonID: 10174)],
            264: [.init("normal", formID: 264), .init("galar", formID: 10334, pokemonID: 10175)],
            554: [.init("standard", formID: 554), .init("galar", formID: 10335, pokemonID: 10176)],
            562: [.init("normal", formID: 562), .init("galar", formID: 10338, pokemonID: 10179)],
            618: [.init("normal", formID: 618), .init("galar", formID: 10339, pokemonID: 10180)],
            58: [.init("normal", formID: 58), .init("hisui", formID: 10398, pokemonID: 10229)],
            59: [.init("normal", formID: 59), .init("hisui", formID: 10399, pokemonID: 10230)],
            100: [.init("normal", formID: 100), .init("hisui", formID: 10400, pokemonID: 10231)],
            101: [.init("normal", formID: 101), .init("hisui", formID: 10401, pokemonID: 10232)],
            157: [.init("normal", formID: 157), .init("hisui", formID: 10402, pokemonID: 10233)],
            211: [.init("normal", formID: 211), .init("hisui", formID: 10403, pokemonID: 10234)],
            215: [.init("normal", formID: 215), .init("hisui", formID: 10404, pokemonID: 10235)],
            503: [.init("normal", formID: 503), .init("hisui", formID: 10405, pokemonID: 10236)],
            549: [.init("normal", formID: 549), .init("hisui", formID: 10406, pokemonID: 10237)],
            570: [.init("normal", formID: 570), .init("hisui", formID: 10407, pokemonID: 10238)],
            571: [.init("normal", formID: 571), .init("hisui", formID: 10408, pokemonID: 10239)],
            628: [.init("normal", formID: 628), .init("hisui", formID: 10409, pokemonID: 10240)],
            705: [.init("normal", formID: 705), .init("hisui", formID: 10410, pokemonID: 10241)],
            706: [.init("normal", formID: 706), .init("hisui", formID: 10411, pokemonID: 10242)],
            713: [.init("normal", formID: 713), .init("hisui", formID: 10412, pokemonID: 10243)],
            724: [.init("normal", formID: 724), .init("hisui", formID: 10413, pokemonID: 10244)],
            845: [
                .init("normal", formID: 845),
                .init("gulping", formID: 10341, pokemonID: 10182),
                .init("gorging", formID: 10342, pokemonID: 10183),
            ],
            849: [
                .init("amped", formID: 849),
                .init("low-key", formID: 10343, pokemonID: 10184),
            ],
            875: [
                .init("ice", formID: 875),
                .init("noice", formID: 10354, pokemonID: 10185),
            ],
            877: [
                .init("full-belly", formID: 877),
                .init("hangry", formID: 10356, pokemonID: 10187),
            ],
            888: [
                .init("hero", formID: 888),
                .init("crowned", formID: 10357, pokemonID: 10188),
            ],
            889: [
                .init("hero", formID: 889),
                .init("crowned", formID: 10358, pokemonID: 10189),
            ],
            892: [
                .init("single-strike", formID: 892),
                .init("rapid-strike", formID: 10360, pokemonID: 10191),
            ],
            893: [
                .init("normal", formID: 893),
                .init("dada", formID: 10361, pokemonID: 10192),
            ],
            898: [
                .init("normal", formID: 898),
                .init("ice", formID: 10362, pokemonID: 10193),
                .init("shadow", formID: 10363, pokemonID: 10194),
            ],
            902: [
                .init("male", formID: 902),
                .init("female", formID: 10417, pokemonID: 10248),
            ],
            905: [
                .init("incarnate", formID: 905),
                .init("therian", formID: 10418, pokemonID: 10249),
            ],
            // Origin Dialga and Palkia, Hoopa Unbound, Bloodmoon Ursaluna, and the female Indeedee and Oinkologne,
            // separate PokéAPI varieties like Giratina's Origin and Meowstic's female.
            483: [.init("normal", formID: 483), .init("origin", formID: 10414, pokemonID: 10245)],
            484: [.init("normal", formID: 484), .init("origin", formID: 10415, pokemonID: 10246)],
            720: [.init("confined", formID: 720), .init("unbound", formID: 10188, pokemonID: 10086)],
            876: [.init("male", formID: 876), .init("female", formID: 10355, pokemonID: 10186)],
            901: [.init("normal", formID: 901), .init("bloodmoon", formID: 10441, pokemonID: 10272)],
            916: [.init("male", formID: 916), .init("female", formID: 10423, pokemonID: 10254)],
            // Maushold's default is the Family of Four; Showdown's files are the other way round (`showdownNames`).
            925: [.init("family-of-four", formID: 925), .init("family-of-three", formID: 10426, pokemonID: 10257)],
            // Partner Eevee, from Let's Go; it does not evolve (`PokemonEvolutionData.formGates`).
            133: [.init("normal", formID: 133), .init("starter", formID: 10318, pokemonID: 10159)],
            // Alcremie's 63 creams and sweets: one look each, no variety of their own. Showdown names them
            // `869-<cream>-<sweet>`, without PokéAPI's "-sweet".
            869: [
                .init("vanilla-cream-strawberry", formID: 869),
                .init("ruby-cream-strawberry", formID: 10346, pngName: "869-ruby-cream-strawberry-sweet"),
                .init("matcha-cream-strawberry", formID: 10347, pngName: "869-matcha-cream-strawberry-sweet"),
                .init("mint-cream-strawberry", formID: 10348, pngName: "869-mint-cream-strawberry-sweet"),
                .init("lemon-cream-strawberry", formID: 10349, pngName: "869-lemon-cream-strawberry-sweet"),
                .init("salted-cream-strawberry", formID: 10350, pngName: "869-salted-cream-strawberry-sweet"),
                .init("ruby-swirl-strawberry", formID: 10351, pngName: "869-ruby-swirl-strawberry-sweet"),
                .init("caramel-swirl-strawberry", formID: 10352, pngName: "869-caramel-swirl-strawberry-sweet"),
                .init("rainbow-swirl-strawberry", formID: 10353, pngName: "869-rainbow-swirl-strawberry-sweet"),
                .init("vanilla-cream-berry", formID: 10449, pngName: "869-vanilla-cream-berry-sweet"),
                .init("ruby-cream-berry", formID: 10450, pngName: "869-ruby-cream-berry-sweet"),
                .init("matcha-cream-berry", formID: 10451, pngName: "869-matcha-cream-berry-sweet"),
                .init("mint-cream-berry", formID: 10452, pngName: "869-mint-cream-berry-sweet"),
                .init("lemon-cream-berry", formID: 10453, pngName: "869-lemon-cream-berry-sweet"),
                .init("salted-cream-berry", formID: 10454, pngName: "869-salted-cream-berry-sweet"),
                .init("ruby-swirl-berry", formID: 10455, pngName: "869-ruby-swirl-berry-sweet"),
                .init("caramel-swirl-berry", formID: 10456, pngName: "869-caramel-swirl-berry-sweet"),
                .init("rainbow-swirl-berry", formID: 10457, pngName: "869-rainbow-swirl-berry-sweet"),
                .init("vanilla-cream-love", formID: 10458, pngName: "869-vanilla-cream-love-sweet"),
                .init("ruby-cream-love", formID: 10459, pngName: "869-ruby-cream-love-sweet"),
                .init("matcha-cream-love", formID: 10460, pngName: "869-matcha-cream-love-sweet"),
                .init("mint-cream-love", formID: 10461, pngName: "869-mint-cream-love-sweet"),
                .init("lemon-cream-love", formID: 10462, pngName: "869-lemon-cream-love-sweet"),
                .init("salted-cream-love", formID: 10463, pngName: "869-salted-cream-love-sweet"),
                .init("ruby-swirl-love", formID: 10464, pngName: "869-ruby-swirl-love-sweet"),
                .init("caramel-swirl-love", formID: 10465, pngName: "869-caramel-swirl-love-sweet"),
                .init("rainbow-swirl-love", formID: 10466, pngName: "869-rainbow-swirl-love-sweet"),
                .init("vanilla-cream-star", formID: 10467, pngName: "869-vanilla-cream-star-sweet"),
                .init("ruby-cream-star", formID: 10468, pngName: "869-ruby-cream-star-sweet"),
                .init("matcha-cream-star", formID: 10469, pngName: "869-matcha-cream-star-sweet"),
                .init("mint-cream-star", formID: 10470, pngName: "869-mint-cream-star-sweet"),
                .init("lemon-cream-star", formID: 10471, pngName: "869-lemon-cream-star-sweet"),
                .init("salted-cream-star", formID: 10472, pngName: "869-salted-cream-star-sweet"),
                .init("ruby-swirl-star", formID: 10473, pngName: "869-ruby-swirl-star-sweet"),
                .init("caramel-swirl-star", formID: 10474, pngName: "869-caramel-swirl-star-sweet"),
                .init("rainbow-swirl-star", formID: 10475, pngName: "869-rainbow-swirl-star-sweet"),
                .init("vanilla-cream-clover", formID: 10476, pngName: "869-vanilla-cream-clover-sweet"),
                .init("ruby-cream-clover", formID: 10477, pngName: "869-ruby-cream-clover-sweet"),
                .init("matcha-cream-clover", formID: 10478, pngName: "869-matcha-cream-clover-sweet"),
                .init("mint-cream-clover", formID: 10479, pngName: "869-mint-cream-clover-sweet"),
                .init("lemon-cream-clover", formID: 10480, pngName: "869-lemon-cream-clover-sweet"),
                .init("salted-cream-clover", formID: 10481, pngName: "869-salted-cream-clover-sweet"),
                .init("ruby-swirl-clover", formID: 10482, pngName: "869-ruby-swirl-clover-sweet"),
                .init("caramel-swirl-clover", formID: 10483, pngName: "869-caramel-swirl-clover-sweet"),
                .init("rainbow-swirl-clover", formID: 10484, pngName: "869-rainbow-swirl-clover-sweet"),
                .init("vanilla-cream-flower", formID: 10485, pngName: "869-vanilla-cream-flower-sweet"),
                .init("ruby-cream-flower", formID: 10486, pngName: "869-ruby-cream-flower-sweet"),
                .init("matcha-cream-flower", formID: 10487, pngName: "869-matcha-cream-flower-sweet"),
                .init("mint-cream-flower", formID: 10488, pngName: "869-mint-cream-flower-sweet"),
                .init("lemon-cream-flower", formID: 10489, pngName: "869-lemon-cream-flower-sweet"),
                .init("salted-cream-flower", formID: 10490, pngName: "869-salted-cream-flower-sweet"),
                .init("ruby-swirl-flower", formID: 10491, pngName: "869-ruby-swirl-flower-sweet"),
                .init("caramel-swirl-flower", formID: 10492, pngName: "869-caramel-swirl-flower-sweet"),
                .init("rainbow-swirl-flower", formID: 10493, pngName: "869-rainbow-swirl-flower-sweet"),
                .init("vanilla-cream-ribbon", formID: 10494, pngName: "869-vanilla-cream-ribbon-sweet"),
                .init("ruby-cream-ribbon", formID: 10495, pngName: "869-ruby-cream-ribbon-sweet"),
                .init("matcha-cream-ribbon", formID: 10496, pngName: "869-matcha-cream-ribbon-sweet"),
                .init("mint-cream-ribbon", formID: 10497, pngName: "869-mint-cream-ribbon-sweet"),
                .init("lemon-cream-ribbon", formID: 10498, pngName: "869-lemon-cream-ribbon-sweet"),
                .init("salted-cream-ribbon", formID: 10499, pngName: "869-salted-cream-ribbon-sweet"),
                .init("ruby-swirl-ribbon", formID: 10500, pngName: "869-ruby-swirl-ribbon-sweet"),
                .init("caramel-swirl-ribbon", formID: 10501, pngName: "869-caramel-swirl-ribbon-sweet"),
                .init("rainbow-swirl-ribbon", formID: 10502, pngName: "869-rainbow-swirl-ribbon-sweet"),
            ],
            // MARK: Gen 9 (Paldea & DLC) & Paldean Regional Forms
            128: [
                .init("normal", formID: 128),
                .init("paldea-combat", formID: 10419, pokemonID: 10250),
                .init("paldea-blaze", formID: 10420, pokemonID: 10251),
                .init("paldea-aqua", formID: 10421, pokemonID: 10252),
            ],
            194: [
                .init("normal", formID: 194),
                .init("paldea", formID: 10422, pokemonID: 10253),
            ],
            931: [
                .init("green", formID: 931),
                .init("blue", formID: 10429, pokemonID: 10260),
                .init("yellow", formID: 10430, pokemonID: 10261),
                .init("white", formID: 10431, pokemonID: 10262),
            ],
            964: [
                .init("zero", formID: 964),
                .init("hero", formID: 10425, pokemonID: 10256),
            ],
            978: [
                .init("curly", formID: 978),
                .init("droopy", formID: 10427, pokemonID: 10258),
                .init("stretchy", formID: 10428, pokemonID: 10259),
            ],
            982: [
                .init("two-segment", formID: 982),
                .init("three-segment", formID: 10424, pokemonID: 10255),
            ],
            999: [
                .init("chest", formID: 999),
                .init("roaming", formID: 10432, pokemonID: 10263),
            ],
            1012: [
                .init("counterfeit", formID: 1012),
                .init("artisan", formID: 10447),
            ],
            1013: [
                .init("unremarkable", formID: 1013),
                .init("masterpiece", formID: 10448),
            ],
            1017: [
                .init("teal", formID: 1017),
                .init("wellspring", formID: 10442, pokemonID: 10273),
                .init("hearthflame", formID: 10443, pokemonID: 10274),
                .init("cornerstone", formID: 10444, pokemonID: 10275),
            ],
            1024: [
                .init("normal", formID: 1024),
                .init("terastal", formID: 10445, pokemonID: 10276),
                .init("stellar", formID: 10446, pokemonID: 10277),
            ],
        ]
    }()

    /// Catalogued species whose line starts elsewhere, mapped to that line's base. The individual's form
    /// is chosen at hatch, so Cherubi and Darumaka eggs already know which Cherrim or Darmanitan they will
    /// become. A catalogued species missing here can never show its forms (`testEveryCatalogedFormCanBeRolled`).
    private static let lineBaseIDs: [Int: Int] = [
        413: 412, 421: 420, 423: 422, 555: 554, 586: 585,
        670: 669, 671: 669, 711: 710,
        20: 19, 28: 27, 38: 37, 51: 50, 53: 52, 75: 74, 76: 74, 89: 88,
        78: 77, 80: 79, 199: 79, 264: 263, 59: 58, 101: 100, 571: 570,
        26: 172, 103: 102, 105: 104, 110: 109, 122: 439, 157: 155, 503: 501, 549: 548, 628: 627,
        666: 664, 678: 677, 681: 679, 705: 704, 706: 704, 713: 712, 724: 722, 745: 744, 773: 772,
        849: 848, 892: 891, 902: 550, 964: 963, 982: 206, 1013: 1012,
        869: 868, 901: 216, 916: 915, 925: 924,
    ]

    static func entries(speciesID: Int) -> [Entry] { catalog[speciesID] ?? [] }

    /// The species' forms, default first. Empty when the species has a single appearance.
    static func forms(speciesID: Int) -> [PokemonForm] { entries(speciesID: speciesID).map(\.form) }

    static func hasForms(speciesID: Int) -> Bool { catalog[speciesID] != nil }

    /// Species of the line that change appearance with the individual's form, in line order.
    static func formSpecies(baseID: Int) -> [Int] {
        catalog.keys.filter { (lineBaseIDs[$0] ?? $0) == baseID }.sorted()
    }

    /// Lines whose species name their forms differently: one rolled form sets each species' own form, as in
    /// the games (a counterfeit Poltchageist becomes an unremarkable Sinistcha, only a white-striped Basculin
    /// becomes a Basculegion, male or female). Other lines share form names from one species to the next.
    private static let lineVariants: [Int: [(form: String, species: [Int: String])]] = [
        550: [("red-striped", [550: "red-striped"]), ("blue-striped", [550: "blue-striped"]),
              ("white-striped-male", [550: "white-striped", 902: "male"]),
              ("white-striped-female", [550: "white-striped", 902: "female"])],
        554: [("standard", [554: "standard", 555: "standard"]), ("zen", [554: "standard", 555: "zen"]),
              ("galar-standard", [554: "galar", 555: "galar-standard"]), ("galar-zen", [554: "galar", 555: "galar-zen"])],
        1012: [("counterfeit", [1012: "counterfeit", 1013: "unremarkable"]),
               ("artisan", [1012: "artisan", 1013: "masterpiece"])],
    ]

    /// Where a species gets its type forms when no egg rolls them, as in the games: Arceus holds a Plate, which
    /// the gym badge of each type gives; Silvally holds a Memory, which a legendary or mythical Pokémon of that
    /// type in the Pokédex gives. Such a species hatches or evolves in its default form; the others unlock for
    /// it (`CompanionState.itemUnlockedForms`).
    enum UnlockSource: Sendable {
        case gymBadge
        case legendaryType
    }

    static let unlockSources: [Int: UnlockSource] = [493: .gymBadge, 773: .legendaryType]

    /// Type: Null, the base of Silvally's line: the egg the last Memory leads to hatches it.
    static let typeNullSpeciesID = 772

    /// Silvally's Memories: one per type but Normal, its default form.
    static let memoryTypes = PokemonType.allCases.filter { $0 != .normal }

    static func unlockSource(speciesID: Int) -> UnlockSource? { unlockSources[speciesID] }

    /// The type a form of such a species stands for (Fire Arceus: Fire). Nil for its default form.
    static func unlockType(speciesID: Int, form: PokemonForm) -> PokemonType? {
        guard unlockSources[speciesID] != nil, form != forms(speciesID: speciesID).first else { return nil }
        return PokemonType(rawValue: form.rawValue)
    }

    /// Forms an egg of this line rolls: only the default on a line whose forms come from items.
    static func rollableLineForms(baseID: Int) -> [PokemonForm] {
        let forms = lineForms(baseID: baseID)
        guard formSpecies(baseID: baseID).contains(where: { unlockSources[$0] != nil }) else { return forms }
        return Array(forms.prefix(1))
    }

    /// Base of the line a catalogued species belongs to.
    static func lineBase(of speciesID: Int) -> Int { lineBaseIDs[speciesID] ?? speciesID }

    /// Everything an individual of this line can carry, default first.
    static func lineForms(baseID: Int) -> [PokemonForm] {
        if let variants = lineVariants[baseID] { return variants.map { PokemonForm($0.form) } }
        var seen = Set<PokemonForm>()
        return formSpecies(baseID: baseID).flatMap(forms(speciesID:)).filter { seen.insert($0).inserted }
    }

    /// The form one species of the line shows for an individual's line form, or nil when that species
    /// does not carry it.
    static func ownForm(speciesID: Int, lineForm form: PokemonForm) -> PokemonForm? {
        if let variant = lineVariants[lineBase(of: speciesID)]?.first(where: { $0.form == form.rawValue }) {
            return variant.species[speciesID].map { PokemonForm($0) }
        }
        return forms(speciesID: speciesID).contains(form) ? form : nil
    }

    /// The appearance of an individual at one species: its own form when that species has it,
    /// otherwise the species default. Nil for species without forms.
    static func resolved(speciesID: Int, form: PokemonForm?) -> PokemonForm? {
        // A costume only changes Pikachu's sprites (`PikachuCostume`).
        if PikachuCostume(speciesID: speciesID, form: form) != nil { return form }
        let forms = forms(speciesID: speciesID)
        guard let first = forms.first else { return nil }
        return form.flatMap { ownForm(speciesID: speciesID, lineForm: $0) } ?? first
    }

    /// Normalizes the form an individual stores: nil for lines without forms, and the line default
    /// for records written before this line had forms (older Unown saves keep their A).
    static func resolved(baseID: Int, form: PokemonForm?) -> PokemonForm? {
        let forms = lineForms(baseID: baseID)
        guard let first = forms.first else { return nil }
        return form.flatMap { forms.contains($0) ? $0 : legacyLineForm(baseID: baseID, $0) } ?? first
    }

    /// Saves written before `lineVariants` stored one species' own form for those lines: the first line form
    /// showing it (`galar` was a Galarian Darumaka, `masterpiece` an artisan Sinistcha, `female` a Basculegion).
    private static func legacyLineForm(baseID: Int, _ form: PokemonForm) -> PokemonForm? {
        lineVariants[baseID]?.first { $0.species.values.contains(form.rawValue) }.map { PokemonForm($0.form) }
    }

    static func isDefault(_ form: PokemonForm?, speciesID: Int) -> Bool {
        forms(speciesID: speciesID).first == resolved(speciesID: speciesID, form: form)
    }

    static func sortOrder(_ form: PokemonForm?, speciesID: Int) -> Int {
        guard let form else { return 0 }
        return forms(speciesID: speciesID).firstIndex(of: form) ?? 0
    }

    /// Chosen only after the species roll: uncollected forms weigh 2, collected forms weigh 1.
    static func roll(_ roll: UInt64, among forms: [PokemonForm], collected: Set<PokemonForm>) -> PokemonForm {
        let weights = rollWeights(among: forms, collected: collected)
        var remaining = Int(roll % UInt64(weights.reduce(0, +)))
        for (form, weight) in zip(forms.dropLast(), weights) {
            remaining -= weight
            if remaining < 0 { return form }
        }
        return forms.last! // Any remaining roll belongs to the last form.
    }

    /// Each form's weight in `roll`.
    static func rollWeights(among forms: [PokemonForm], collected: Set<PokemonForm>) -> [Int] {
        forms.map { CollectionWeight.adjusted(2, isCollected: collected.contains($0)) }
    }

    // MARK: Sprites and names

    /// Animated GIFs and cache files use `<id>-<form>`; the default keeps the plain `<id>` names
    /// (and so the cache keys of saves written before forms existed).
    static func assetName(speciesID: Int, form: PokemonForm?) -> String {
        if let costume = PikachuCostume(speciesID: speciesID, form: form) { return "\(speciesID)-\(costume.rawValue)" }
        guard let form = resolved(speciesID: speciesID, form: form), !isDefault(form, speciesID: speciesID) else {
            return String(speciesID)
        }
        return "\(speciesID)-\(form.rawValue)"
    }

    /// Static PNGs of forms that are separate PokéAPI varieties live under the variety id.
    static func staticAssetName(speciesID: Int, form: PokemonForm?) -> String {
        if let costume = PikachuCostume(speciesID: speciesID, form: form) { return String(costume.pokemonID) }
        let resolved = resolved(speciesID: speciesID, form: form)
        if let pokemonID = entries(speciesID: speciesID).first(where: { $0.form == resolved })?.pokemonID {
            return String(pokemonID)
        }
        return assetName(speciesID: speciesID, form: form)
    }

    /// The static PNG: the entry's own name where it has one, else the static asset's.
    static func pngName(speciesID: Int, form: PokemonForm?) -> String {
        let resolved = resolved(speciesID: speciesID, form: form)
        return entries(speciesID: speciesID).first { $0.form == resolved }?.pngName
            ?? staticAssetName(speciesID: speciesID, form: form)
    }

    /// PokéAPI `pokemon` resource holding an individual's stats, abilities, size and moves: its form's own variety
    /// (10103 for an Alolan Vulpix), else the species, whose default form also stands for the forms that only change
    /// a look (Unown's letters, Arceus's Plates).
    static func detailsID(speciesID: Int, form: PokemonForm?) -> Int {
        let resolved = resolved(speciesID: speciesID, form: form)
        return entries(speciesID: speciesID).first { $0.form == resolved }?.pokemonID ?? speciesID
    }

    /// PokéAPI `pokemon-form` id holding the localized form names. Nil for species without forms.
    static func formID(speciesID: Int, form: PokemonForm?) -> Int? {
        let resolved = resolved(speciesID: speciesID, form: form)
        return entries(speciesID: speciesID).first { $0.form == resolved }?.formID
    }

    /// Unown always names its letter; other species name only a non-default form.
    static func displayName(_ name: String, speciesID: Int, form: PokemonForm?, label: String?) -> String {
        guard let form = resolved(speciesID: speciesID, form: form) else { return name }
        if speciesID == unownSpeciesID { return "\(name) [\(form.symbol)]" }
        guard !isDefault(form, speciesID: speciesID), let label, !label.isEmpty else { return name }
        return "\(name) [\(label)]"
    }
}

extension PokemonForm {
    private struct StoredKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// Reads the first present key; saves written before other species had forms used `unownForm`.
    /// Malformed values read as nil so the caller's resolution falls back to the default form.
    static func decoded(from decoder: Decoder, keys: String...) -> PokemonForm? {
        guard let c = try? decoder.container(keyedBy: StoredKey.self) else { return nil }
        for key in keys {
            if let form = try? c.decodeIfPresent(PokemonForm.self, forKey: StoredKey(stringValue: key)) {
                return form
            }
        }
        return nil
    }
}

extension PokemonForm {
    /// Castform, Rotom, Kyurem, Genesect, Eevee, Dialga, Palkia and Ursaluna have no official name for their usual look:
    /// PokéAPI only says "Forme de Motisma" or nothing at all.
    private static let unnamedDefaultSpecies: Set<Int> = [351, 479, 646, 649, 133, 483, 484, 901]

    private static func hasUnnamedDefault(speciesID: Int, form: PokemonForm?) -> Bool {
        unnamedDefaultSpecies.contains(speciesID) && isDefault(form, speciesID: speciesID)
    }

    /// PokéAPI resource with the localized name of the form this species shows.
    /// Unown and the unnamed usual looks need none.
    static func nameResource(speciesID: Int, form: PokemonForm?) -> PokemonNameResource? {
        guard speciesID != unownSpeciesID, !hasUnnamedDefault(speciesID: speciesID, form: form),
              let id = formID(speciesID: speciesID, form: form) else { return nil }
        return PokemonNameResource(kind: .pokemonForm, name: String(id))
    }

    /// Every form of the species, for pickers that label all of them.
    static func nameResources(speciesID: Int) -> [PokemonNameResource] {
        forms(speciesID: speciesID).compactMap { nameResource(speciesID: speciesID, form: $0) }
    }

    /// Localized form name ("Forme Céleste"), Unown's letter, or the identifier until PokéAPI answers.
    /// Nil for species without forms.
    @MainActor
    static func label(speciesID: Int, form: PokemonForm?, language: AppLanguage,
                      names: PokemonNameDisplayStore = .shared) -> String? {
        guard let form = resolved(speciesID: speciesID, form: form) else { return nil }
        if speciesID == unownSpeciesID { return form.symbol }
        if hasUnnamedDefault(speciesID: speciesID, form: form) { return L(language).normalForm }
        if let name = appName(speciesID: speciesID, form: form, language: language, names: names) { return name }
        let translations = nameResource(speciesID: speciesID, form: form).flatMap { names.names[$0] }
        return translations.flatMap(language.resolveName) ?? PokemonNameLocalization.identifier(form.rawValue)
    }

    /// Names PokéAPI gives wrong or not at all: Hoopa's forms carry the species' name ("Hoopa Unbound"), Partner Eevee
    /// and Maushold's families have few languages, the three Paldean Tauros all read "Paldean Form" outside English,
    /// and both Darmanitan Zen Modes read "Zen Mode" (#55).
    @MainActor
    private static func appName(speciesID: Int, form: PokemonForm, language: AppLanguage,
                                names: PokemonNameDisplayStore) -> String? {
        let l = L(language)
        switch (speciesID, form.rawValue) {
        case (720, "confined"): return l.formHoopaConfined
        case (720, "unbound"): return l.formHoopaUnbound
        case (133, "starter"): return l.formPartner
        case (925, "family-of-four"): return l.formFamilyOfFour
        case (925, "family-of-three"): return l.formFamilyOfThree
        case (128, "paldea-combat"): return l.formTaurosCombatBreed
        case (128, "paldea-blaze"): return l.formTaurosBlazeBreed
        case (128, "paldea-aqua"): return l.formTaurosAquaBreed
        case (555, "galar-zen"):
            // Galarian Darmanitan's own name, then the Zen Mode's ("Forme de Galar, Mode Transe").
            guard let galar = label(speciesID: 555, form: PokemonForm("galar-standard"), language: language, names: names),
                  let zen = label(speciesID: 555, form: PokemonForm("zen"), language: language, names: names)
            else { return nil }
            return "\(galar), \(zen)"
        default: return nil
        }
    }

    @MainActor
    static func displayName(_ name: String, speciesID: Int, form: PokemonForm?, language: AppLanguage) -> String {
        displayName(name, speciesID: speciesID, form: form,
                    label: label(speciesID: speciesID, form: form, language: language))
    }
}
