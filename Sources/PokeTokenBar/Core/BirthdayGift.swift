import Foundation

/// The day and month the player was born, without the year (Settings).
struct Birthday: Codable, Hashable, Sendable {
    let month: Int
    let day: Int

    /// Nil for a day no year has (April 31); February 29 is kept.
    init?(month: Int, day: Int) {
        guard (1...12).contains(month), (1...Self.days(inMonth: month)).contains(day) else { return nil }
        self.month = month
        self.day = day
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let valid = Birthday(month: try c.decode(Int.self, forKey: .month), day: try c.decode(Int.self, forKey: .day))
        else { throw DecodingError.dataCorruptedError(forKey: .day, in: c, debugDescription: "no such day") }
        self = valid
    }

    /// The days a month can have, February 29 included.
    static func days(inMonth month: Int) -> Int {
        switch month {
        case 2: return 29
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// The birthday in `year`, at the start of its day: February 29 falls on February 28 in other years.
    func date(in year: Int, calendar: Calendar) -> Date {
        var parts = DateComponents(year: year, month: month, day: day)
        if month == 2, day == 29,
           let february = calendar.date(from: DateComponents(year: year, month: 2, day: 1)),
           calendar.range(of: .day, in: .month, for: february)?.count != 29 {
            parts.day = 28
        }
        return calendar.date(from: parts) ?? .distantPast
    }

    /// The last time it came, on or before `now`.
    func last(atOrBefore now: Date, calendar: Calendar) -> Date {
        let year = calendar.component(.year, from: now)
        let thisYear = date(in: year, calendar: calendar)
        return thisYear <= now ? thisYear : date(in: year - 1, calendar: calendar)
    }
}

/// The birthday gift: a Birthday Egg, once a year per save. From the birthday on, the player claims it the first time they
/// open the app, up to three months later: on holiday, with the Mac off, or before they entered the date.
enum BirthdayGift {
    static let claimDays = 7
    static let catchUpMonths = 3

    enum Occasion: Equatable, Sendable {
        /// The birthday's week.
        case birthday
        /// After the birthday's week, within three months.
        case belated
    }

    /// The gift claimable at `now`: its birthday's year and the occasion. Nil when no birthday is set, its gift was
    /// claimed, or its time has passed. A birthday in the last days of December claimed in January counts for the
    /// year before, so the next one still brings a gift. `changedAfterGiftYear`: the birthday changed after a gift
    /// claimed that calendar year, so only a later birthday year brings one (a December gift claimed in January, then a
    /// February date, would otherwise bring two eggs within weeks).
    static func claimable(birthday: Birthday?, lastGiftYear: Int?, changedAfterGiftYear: Int? = nil, now: Date,
                          calendar: Calendar) -> (year: Int, occasion: Occasion)? {
        guard let birthday else { return nil }
        let last = birthday.last(atOrBefore: now, calendar: calendar)
        let year = calendar.component(.year, from: last)
        if let lastGiftYear, lastGiftYear >= year { return nil }
        if let changedAfterGiftYear, changedAfterGiftYear >= year { return nil }
        if let week = calendar.date(byAdding: .day, value: claimDays, to: last), now < week { return (year, .birthday) }
        guard let catchUp = calendar.date(byAdding: .month, value: catchUpMonths, to: last), now < catchUp else { return nil }
        return (year, .belated)
    }

    /// What a Birthday Egg can hatch, among the index's legendary and mythical lines: the mythical lines not graduated
    /// yet, else the legendary ones, every missing line as likely; once all of them graduated, any of them by its
    /// hatch weight, shiny.
    static func pool(_ index: [BaseSpecies], graduated: Set<Int>,
                     without excluded: Set<Int> = PokemonOdds.dungeonOnly) -> (lines: [BaseSpecies], byWeight: Bool) {
        let legends = index.filter { $0.isLegendary && !excluded.contains($0.id) }
        let missing = legends.filter { !graduated.contains($0.id) }
        let mythicals = missing.filter { SpeciesGoal.mythicals.contains($0.id) }
        if !mythicals.isEmpty { return (mythicals, false) }
        if !missing.isEmpty { return (missing, false) }
        return (legends, true)
    }
}

extension L {
    var birthdayLabel: String {
        t("내 생일", "My birthday", "わたしの誕生日", "Mi cumpleaños", "Mon anniversaire", "Meu aniversário", "Mein Geburtstag",
          "Мой день рождения")
    }
    var birthdayHint: String {
        t("생일에 선물 알을 받아요", "A gift egg on your birthday", "誕生日にプレゼントのタマゴが届きます",
          "Un huevo de regalo en tu cumpleaños", "Un œuf cadeau pour ton anniversaire", "Um ovo de presente no seu aniversário",
          "Ein Geschenk-Ei zum Geburtstag", "Яйцо-подарок на день рождения")
    }
    var birthdayNotSet: String {
        t("설정 안 함", "Not set", "未設定", "Sin fijar", "Non renseigné", "Não definido", "Nicht gesetzt", "Не указан")
    }
    var birthdayBannerTitle: String {
        t("생일 축하해요!", "Happy birthday!", "お誕生日おめでとう！", "¡Feliz cumpleaños!", "Joyeux anniversaire !",
          "Feliz aniversário!", "Alles Gute zum Geburtstag!", "С днём рождения!")
    }
    var birthdayBelatedTitle: String {
        t("조금 늦었지만 생일 축하해요!", "Happy belated birthday!", "少し遅れたけど、お誕生日おめでとう！",
          "¡Feliz cumpleaños atrasado!", "Joyeux anniversaire, avec un peu de retard !", "Feliz aniversário atrasado!",
          "Nachträglich alles Gute zum Geburtstag!", "С прошедшим днём рождения!")
    }
    var birthdayBannerBody: String {
        t("선물 알이 기다리고 있어요. 무엇이 태어날까요?", "A gift egg is waiting for you. What will hatch from it?",
          "プレゼントのタマゴが待っています。なにが生まれるかな？", "Un huevo de regalo te espera. ¿Qué saldrá de él?",
          "Un œuf cadeau t'attend. Qu'est-ce qui va en sortir ?", "Um ovo de presente está esperando por você. O que vai sair dele?",
          "Ein Geschenk-Ei wartet auf dich. Was wohl daraus schlüpft?", "Вас ждёт яйцо-подарок. Кто из него вылупится?")
    }
    var birthdayClaim: String {
        t("선물 열기", "Open the gift", "プレゼントを受け取る", "Abrir el regalo", "Ouvrir le cadeau", "Abrir o presente",
          "Geschenk öffnen", "Открыть подарок")
    }
    var birthdayClaimed: String {
        t("선물 알을 가방에 넣었어요. 원할 때 써 보세요.", "The gift egg is in your Bag: use it whenever you like.",
          "プレゼントのタマゴをバッグに入れました。好きなときに使ってね。",
          "El huevo de regalo está en tu Bolsa: úsalo cuando quieras.",
          "L'œuf cadeau est dans ton Sac : utilise-le quand tu veux.",
          "O ovo de presente está na sua Bolsa: use quando quiser.",
          "Das Geschenk-Ei ist in deinem Beutel: Nutze es, wann du willst.",
          "Яйцо-подарок в вашей сумке: используйте его когда захотите.")
    }
    var notifBirthdayTitle: String { birthdayBannerTitle }
    var notifBirthdayBody: String {
        t("선물 알이 기다리고 있어요.", "A gift egg is waiting for you.", "プレゼントのタマゴが待っています。",
          "Un huevo de regalo te espera.", "Un œuf cadeau t'attend.", "Um ovo de presente está esperando por você.",
          "Ein Geschenk-Ei wartet auf dich.", "Вас ждёт яйцо-подарок.")
    }
}
