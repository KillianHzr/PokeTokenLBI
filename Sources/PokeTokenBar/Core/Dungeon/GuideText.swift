import Foundation

/// The guide's words on Home while a team explores (the owner, 2026-11-10, choice C), in the app's eight languages.
extension L {
    /// "A, B et C": names joined as each language lists them.
    func listed(_ names: [String]) -> String {
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        let head = names.dropLast().joined(separator: t(", ", ", ", "、", ", ", ", ", ", ", ", ", ", "))
        return head + t(", ", " and ", "と", " y ", " et ", " e ", " und ", " и ") + last
    }

    func guideFloors(done: Int) -> String {
        if done <= 0 {
            return t("팀이 막 들어갔어요.", "Your team has just gone in.", "チームが入ったところです。", "Tu equipo acaba de entrar.",
                     "Ton équipe vient d'entrer.", "Sua equipe acabou de entrar.", "Dein Team ist gerade hinein.",
                     "Ваша команда только вошла.")
        }
        return t("팀이 \(done)층을 지나왔어요.", "Your team is past floor \(done).", "チームは\(done)階を越えました。",
                 "Tu equipo ha pasado el piso \(done).", "Ton équipe a passé l'étage \(done).", "Sua equipe passou do andar \(done).",
                 "Dein Team hat Ebene \(done) hinter sich.", "Ваша команда прошла этаж \(done).")
    }

    func guideFainted(_ names: [String]) -> String {
        let n = listed(names), many = names.count > 1
        return t("\(n) 기절.", many ? "\(n) are down." : "\(n) is down.", "\(n)はひんし。",
                 many ? "\(n) están debilitados." : "\(n) está debilitado.", many ? "\(n) sont K.O." : "\(n) est K.O.",
                 many ? "\(n) estão nocauteados." : "\(n) está nocauteado.", many ? "\(n) sind besiegt." : "\(n) ist besiegt.",
                 many ? "\(n) без сознания." : "\(n) без сознания.")
    }

    func guideWeak(_ names: [String]) -> String {
        let n = listed(names), many = names.count > 1
        return t("\(n) 위험해요.", many ? "\(n) are weak." : "\(n) is weak.", "\(n)はピンチです。",
                 many ? "\(n) flaquean." : "\(n) flaquea.", many ? "\(n) faiblissent." : "\(n) faiblit.",
                 many ? "\(n) estão fracos." : "\(n) está fraco.", many ? "\(n) sind geschwächt." : "\(n) ist geschwächt.",
                 many ? "\(n) слабеют." : "\(n) слабеет.")
    }

    func guideBoss(at floor: Int) -> String {
        t("보스는 \(floor)층에서 기다려요.", "The boss waits on floor \(floor).", "ボスは\(floor)階で待っています。",
          "El jefe espera en el piso \(floor).", "Le boss t'attend à l'étage \(floor).", "O chefe espera no andar \(floor).",
          "Der Boss wartet auf Ebene \(floor).", "Босс ждёт на этаже \(floor).")
    }

    var guideNeedsHeal: String {
        t("이대로는 위험해요: 회복할지 정해 주세요.", "It is getting dangerous: decide whether to heal them.",
          "このままでは危険です。回復するか決めてください。", "Se pone peligroso: decide si los curas.",
          "Ça devient dangereux : décide si tu les soignes.", "Está ficando perigoso: decida se vai curá-los.",
          "Es wird gefährlich: Entscheide, ob du sie heilst.", "Становится опасно: решите, лечить ли их.")
    }

    /// A fight's foes in the floors' tooltips.
    func guideFoes(_ n: Int) -> String {
        t("상대 \(n)마리", n == 1 ? "1 foe" : "\(n) foes", "相手\(n)匹", n == 1 ? "1 rival" : "\(n) rivales",
          n == 1 ? "1 adversaire" : "\(n) adversaires", n == 1 ? "1 adversário" : "\(n) adversários",
          n == 1 ? "1 Gegner" : "\(n) Gegner", "соперников: \(n)")
    }

    /// The guide's word on the return.
    func guideResult(won: Bool, roped: Bool) -> String {
        if won {
            return t("멋져요! 보스를 쓰러뜨렸어요.", "Well done! The boss fell.", "おみごと！ボスを倒しました。", "¡Bien hecho! El jefe ha caído.",
                     "Bravo ! Le boss est tombé.", "Muito bem! O chefe caiu.", "Gut gemacht! Der Boss ist gefallen.", "Отлично! Босс повержен.")
        }
        if roped {
            return t("팀이 무사히 돌아왔어요. 지나온 층의 전리품은 그대로예요.", "Your team is back safe, with the floors' loot.",
                     "チームは無事に戻りました。通った階の戦利品はそのままです。", "Tu equipo ha vuelto a salvo, con el botín de los pisos.",
                     "Ton équipe est rentrée saine et sauve, avec le butin des étages.", "Sua equipe voltou a salvo, com o butim dos andares.",
                     "Dein Team ist heil zurück, mit der Beute der Ebenen.", "Ваша команда вернулась целой, с добычей этажей.")
        }
        return t("이번엔 졌어요. 지나온 층의 전리품은 남아요.", "Not this time: the floors' loot is kept.",
                 "今回は負けました。通った階の戦利品は残ります。", "Esta vez no: el botín de los pisos se queda.",
                 "Pas cette fois : le butin des étages est gardé.", "Não desta vez: o butim dos andares fica.",
                 "Diesmal nicht: Die Beute der Ebenen bleibt.", "Не в этот раз: добыча этажей остаётся.")
    }
}
