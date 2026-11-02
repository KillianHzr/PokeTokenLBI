import Foundation

/// The words of the dungeons, in the app's eight languages.
extension L {
    var dungeonItemHint: String {
        t("던전용", "For dungeons", "ダンジョン用", "Para mazmorras", "Pour les donjons", "Para masmorras", "Für Dungeons",
          "Для подземелий")
    }

    /// A dungeon's egg, on Home while it incubates: the Bag names its Pokémon.
    var dungeonEggName: String {
        t("던전의 알", "Dungeon Egg", "ダンジョンのタマゴ", "Huevo de mazmorra", "Œuf de donjon", "Ovo de masmorra",
          "Dungeon-Ei", "Яйцо из подземелья")
    }

    /// The places' official names (Q26).
    func dungeonName(_ id: DungeonID) -> String {
        switch id {
        case .viridianForest: t("상록숲", "Viridian Forest", "トキワのもり", "Bosque Verde", "Forêt de Jade",
                                "Floresta de Viridian", "Vertania-Wald", "Виридиан-лес")
        case .diglettsCave: t("디그다굴", "Diglett's Cave", "ディグダのあな", "Cueva Diglett", "Grotte Taupiqueur",
                              "Caverna do Diglett", "Digda-Höhle", "Пещера Диглетта")
        case .mtMoon: t("달맞이산", "Mt. Moon", "おつきみやま", "Mt. Moon", "Mont Sélénite", "Monte Lua", "Mondberg",
                        "Гора Луны")
        case .mtEmber: t("불꽃산", "Mt. Ember", "ともしびやま", "Monte Ascuas", "Mont Braise", "Monte Brasa", "Glutberg",
                         "Гора Эмбер")
        case .victoryRoad: t("챔피언로드", "Victory Road", "チャンピオンロード", "Calle Victoria", "Route Victoire",
                             "Estrada Vitória", "Siegesstraße", "Дорога победы")
        case .pokemonTower: t("포켓몬타워", "Pokémon Tower", "ポケモンタワー", "Torre Pokémon", "Tour Pokémon",
                              "Torre Pokémon", "Pokémon-Turm", "Покемон-башня")
        case .dragonsDen: t("용의굴", "Dragon's Den", "りゅうのあな", "Guarida Dragón", "Antre du Dragon",
                            "Covil do Dragão", "Drachenhöhle", "Логово дракона")
        case .powerPlant: t("무인발전소", "Power Plant", "むじんはつでんしょ", "Central Energía", "Centrale",
                            "Usina de Energia", "Kraftwerk", "Электростанция")
        case .seafoamIslands: t("쌍둥이섬", "Seafoam Islands", "ふたごじま", "Islas Espuma", "Îles Écume",
                                "Ilhas Seafoam", "Seeschauminseln", "Острова Сифоум")
        case .ceruleanCave: t("블루시티동굴", "Cerulean Cave", "ハナダのどうくつ", "Cueva Celeste", "Caverne Azurée",
                              "Caverna Celeste", "Azuria-Höhle", "Церулинская пещера")
        case .mtCoronet: t("천관산", "Mt. Coronet", "テンガンざん", "Monte Corona", "Mont Couronné", "Monte Coronet",
                           "Kraterberg", "Гора Коронет")
        case .ruinsOfAlph: t("알프의 유적", "Ruins of Alph", "アルフのいせき", "Ruinas Alfa", "Ruines d'Alpha",
                             "Ruínas de Alfa", "Alph-Ruinen", "Руины Альфа")
        case .hallOfOrigin: t("시작의 방", "Hall of Origin", "はじまりのま", "Sala del Origen", "Salle Originelle",
                              "Salão da Origem", "Saal des Ursprungs", "Зал Истоков")
        }
    }
}
