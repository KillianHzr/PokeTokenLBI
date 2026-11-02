#!/usr/bin/env python3
"""Generate the battle tables the dungeons' engine reads, from PokéAPI's GraphQL endpoint.

Writes Sources/PokeTokenBar/Core/Battle/BattleData.generated.swift: every move's battle data, and every Pokémon
variety's base stats, abilities and the four moves a wild one or a boss loops. Facts only, no names or texts: the app
fetches the localized names at runtime, as it does today.

    python3 -I scripts/generate-battle-data.py

The tables are text in Swift string literals, parsed once at first use: thousands of struct literals would slow
the compiler down far more than the parse costs at runtime.
"""

import json
import sys
import time
import urllib.request
from pathlib import Path

ENDPOINT = "https://graphql.pokeapi.co/v1beta2"
OUT = Path(__file__).resolve().parent.parent / "Sources/PokeTokenBar/Core/Battle/BattleData.generated.swift"

# The games each species learns its moves in, as `PokemonDetails.preferredVersionGroups` reads them; a form outside
# its species' games falls back to `formVersionGroups`.
FORM_GROUPS = ["ultra-sun-ultra-moon", "sun-moon", "sword-shield", "legends-arceus",
               "brilliant-diamond-and-shining-pearl", "scarlet-violet"]


def preferred_groups(species_id):
    if species_id <= 649:
        return ["black-2-white-2", "black-white"]
    if species_id <= 721:
        return ["omega-ruby-alpha-sapphire", "x-y"]
    if species_id <= 809:
        return ["ultra-sun-ultra-moon", "sun-moon"]
    if species_id <= 905:
        return ["sword-shield", "legends-arceus", "brilliant-diamond-and-shining-pearl"]
    return ["scarlet-violet"]


def query(text, retries=4):
    body = json.dumps({"query": text}).encode()
    for attempt in range(retries):
        try:
            request = urllib.request.Request(ENDPOINT, data=body, headers={"Content-Type": "application/json", "User-Agent": "PokeTokenBar-battle-data"})
            with urllib.request.urlopen(request, timeout=180) as response:
                data = json.load(response)
            if "errors" in data:
                raise RuntimeError(data["errors"])
            return data["data"]
        except Exception as error:  # noqa: BLE001 - network or server hiccup: retry
            if attempt == retries - 1:
                raise
            print(f"retry after {error}", file=sys.stderr)
            time.sleep(3 * (attempt + 1))


def fetch_moves():
    data = query("""{ move(where: {id: {_lt: 10000}}, order_by: {id: asc}) {
        id name power accuracy priority move_effect_chance
        type { name } movedamageclass { name } movetarget { name }
        movemeta { ailment_chance crit_rate drain flinch_chance healing max_hits min_hits max_turns min_turns
                   stat_chance movemetaailment { name } movemetacategory { name } }
        movemetastatchanges { change stat { name } }
        moveattributemaps { moveattribute { name } } } }""")
    return data["move"]


def fetch_pokemon():
    data = query("""{ pokemon(order_by: {id: asc}) {
        id name pokemon_species_id is_default
        pokemonstats { base_stat stat { name } }
        pokemonabilities(order_by: {slot: asc}) { slot is_hidden ability { name } }
        pokemontypes(order_by: {slot: asc}) { type { name } } } }""")
    return data["pokemon"]


def fetch_species():
    data = query("""{ pokemonspecies(order_by: {id: asc}) {
        id capture_rate is_legendary is_mythical evolves_from_species_id generation_id
        pokemonegggroups { egggroup { name } } } }""")
    return data["pokemonspecies"]


def species_line(s):
    """id|captureRate|legendary (1 for the unbreedable legendaries and mythicals, as `BaseSpecies` reads them)|
    evolvesFrom|generation"""
    groups = [row["egggroup"]["name"] for row in s["pokemonegggroups"]]
    legendary = (s["is_legendary"] or s["is_mythical"]) and not any(g != "no-eggs" for g in groups)
    return "|".join(str(f) for f in [s["id"], s["capture_rate"] or 0, 1 if legendary else 0,
                                     s["evolves_from_species_id"] or 0, s["generation_id"] or 0])


def fetch_learnsets(ids):
    """Level-up and machine moves of these varieties, in every version group: filtered per species below."""
    out = {}
    for start in range(0, len(ids), 40):
        chunk = ids[start:start + 40]
        data = query("""{ pokemonmove(where: {pokemon_id: {_in: %s},
                                             movelearnmethod: {name: {_in: ["level-up", "machine"]}}}) {
            pokemon_id level move { name } movelearnmethod { name } versiongroup { name } } }""" % json.dumps(chunk))
        for row in data["pokemonmove"]:
            out.setdefault(row["pokemon_id"], []).append(row)
        print(f"learnsets {start + len(chunk)}/{len(ids)}", file=sys.stderr)
    return out


STAT_KEYS = ["hp", "attack", "defense", "special-attack", "special-defense", "speed"]
# Moves a wild Pokémon or a boss never loops: they knock out their user, need a setup the loop cannot make, or do
# nothing on their own.
NEVER_LOOPED = {"explosion", "self-destruct", "memento", "final-gambit", "healing-wish", "lunar-dance", "misty-explosion",
                "dream-eater", "nightmare", "snore", "sleep-talk", "last-resort", "belch", "focus-punch", "fling",
                "natural-gift", "spit-up", "swallow", "stockpile", "synchronoise", "steel-beam", "mind-blown",
                "struggle", "counter", "mirror-coat", "metal-burst", "bide", "endeavor", "pain-split", "curse",
                "beat-up", "present", "magnitude", "trump-card", "punishment", "hidden-power", "frustration", "return",
                "rollout", "ice-ball", "outrage", "thrash", "petal-dance", "uproar", "fake-out", "first-impression",
                "sucker-punch", "dragon-tail", "circle-throw", "whirlwind", "roar", "teleport", "u-turn", "volt-switch",
                "flip-turn", "parting-shot", "baton-pass", "transform", "sketch", "mimic", "copycat", "mirror-move",
                "metronome", "assist", "me-first", "after-you", "quash", "ally-switch", "helping-hand", "follow-me",
                "rage-powder", "spotlight", "perish-song", "destiny-bond", "grudge", "spite", "disable", "encore",
                "torment", "taunt", "imprison", "snatch", "magic-coat", "role-play", "skill-swap", "entrainment",
                "simple-beam", "worry-seed", "gastro-acid", "trick", "switcheroo", "bestow", "recycle", "covet",
                "thief", "knock-off", "incinerate", "pluck", "bug-bite", "power-split", "guard-split", "power-swap",
                "guard-swap", "heart-swap", "speed-swap", "psych-up", "haze", "conversion", "conversion-2",
                "reflect-type", "soak", "magic-powder", "camouflage", "lock-on", "mind-reader", "foresight",
                "odor-sleuth", "miracle-eye", "telekinesis", "gravity", "trick-room", "wonder-room", "magic-room",
                "ingrain", "aqua-ring", "substitute", "protect", "detect", "endure", "kings-shield", "spiky-shield",
                "baneful-bunker", "obstruct", "silk-trap", "burning-bulwark", "max-guard", "quick-guard", "wide-guard",
                "crafty-shield", "mat-block", "safeguard", "mist", "lucky-chant", "tailwind", "rest", "focus-energy",
                "splash", "celebrate", "hold-hands", "happy-hour", "flash", "kinesis", "sand-attack", "smokescreen",
                "minimize", "double-team", "growl", "tail-whip", "leer", "string-shot", "sweet-scent", "defog",
                "lock-on", "charge", "laser-focus", "refresh", "heal-bell", "aromatherapy", "purify", "pollen-puff",
                "power-trick", "acupressure", "doodle", "chilly-reception", "shed-tail", "revival-blessing",
                "court-change", "corrosive-gas", "teatime", "stuff-cheeks", "no-retreat", "octolock", "jaw-lock",
                "dragon-cheer", "instruct", "fairy-lock", "embargo", "heal-block", "block", "mean-look",
                "spider-web", "attract", "captivate", "venom-drench", "toxic-thread", "tar-shot", "electrify",
                "ion-deluge", "powder", "forests-curse", "trick-or-treat", "magnet-rise", "flower-shield",
                "rototiller", "gear-up", "magnetic-flux", "aurora-veil", "reflect", "light-screen", "geomancy",
                "future-sight", "doom-desire", "sky-drop", "shadow-force", "phantom-force", "dig", "dive", "fly",
                "bounce", "solar-blade", "meteor-beam", "electro-shot", "razor-wind", "skull-bash", "sky-attack",
                "freeze-shock", "ice-burn", "dynamax-cannon", "behemoth-blade", "behemoth-bash", "eternabeam"}
# Setup moves by the side they boost: a special attacker never loops Swords Dance.
PHYSICAL_BOOSTS = {"swords-dance", "dragon-dance", "bulk-up", "coil", "shift-gear", "hone-claws", "howl",
                   "victory-dance", "tidy-up", "belly-drum"}
SPECIAL_BOOSTS = {"nasty-plot", "quiver-dance", "calm-mind", "tail-glow", "geomancy"}
BOOSTS = {"swords-dance": 3, "dragon-dance": 3, "nasty-plot": 3, "quiver-dance": 3, "calm-mind": 2, "bulk-up": 2,
          "shell-smash": 3, "coil": 2, "shift-gear": 3, "hone-claws": 1, "work-up": 1, "growth": 1, "howl": 1,
          "victory-dance": 3, "tidy-up": 2, "agility": 1, "rock-polish": 1, "autotomize": 1, "iron-defense": 1,
          "amnesia": 1, "cosmic-power": 1, "cotton-guard": 1, "acid-armor": 1, "barrier": 1, "tail-glow": 2,
          "belly-drum": 2, "fillet-away": 2}
RECOVERY = {"recover": 3, "roost": 3, "slack-off": 3, "soft-boiled": 3, "milk-drink": 3, "synthesis": 2,
            "moonlight": 2, "morning-sun": 2, "shore-up": 3, "heal-order": 3, "strength-sap": 3, "wish": 2,
            "jungle-healing": 2, "lunar-blessing": 2, "life-dew": 2}
INFLICT = {"will-o-wisp": 2, "thunder-wave": 2, "toxic": 2, "spore": 3, "sleep-powder": 2, "hypnosis": 1,
           "glare": 2, "stun-spore": 2, "yawn": 1, "dark-void": 2, "lovely-kiss": 1, "sing": 1, "grass-whistle": 1,
           "confuse-ray": 1, "poison-powder": 1, "leech-seed": 2, "swagger": 1}


def move_line(move):
    meta = (move["movemeta"] or [None])[0] or {}
    ailment = ((meta.get("movemetaailment") or {}).get("name")) or "none"
    category = ((meta.get("movemetacategory") or {}).get("name")) or "unique"
    stats = ",".join(f'{row["stat"]["name"]}:{row["change"]}' for row in move["movemetastatchanges"])
    flags = ",".join(sorted(row["moveattribute"]["name"] for row in move["moveattributemaps"]))
    fields = [
        move["name"], move["type"]["name"], move["movedamageclass"]["name"],
        move["power"] or 0, move["accuracy"] or 0, move["priority"] or 0, move["movetarget"]["name"],
        move["move_effect_chance"] or 0, ailment, meta.get("ailment_chance") or 0, meta.get("crit_rate") or 0,
        meta.get("drain") or 0, meta.get("healing") or 0, meta.get("flinch_chance") or 0,
        meta.get("min_hits") or 0, meta.get("max_hits") or 0, meta.get("min_turns") or 0, meta.get("max_turns") or 0,
        meta.get("stat_chance") or 0, stats, category, flags,
    ]
    return "|".join(str(f) for f in fields)


def loop_moves(pokemon, learnset, moves, types):
    """Four moves a wild Pokémon or a boss loops: a setup or recovery move when it has one, then its strongest
    moves, its own types first, then one of another type."""
    stats = {row["stat"]["name"]: row["base_stat"] for row in pokemon["pokemonstats"]}
    physical = stats.get("attack", 0) >= stats.get("special-attack", 0)
    species = pokemon["pokemon_species_id"]
    groups = preferred_groups(species) if pokemon["is_default"] else FORM_GROUPS + preferred_groups(species)
    known = set()
    for group in groups:
        rows = [r for r in learnset if r["versiongroup"]["name"] == group]
        if rows:
            known = {r["move"]["name"] for r in rows if r["movelearnmethod"]["name"] == "machine"
                     or (r["level"] or 0) <= 100}
            break
    if not known:
        known = {r["move"]["name"] for r in learnset}

    def damage(name):
        move = moves.get(name)
        if not move or name in NEVER_LOOPED:
            return 0
        power = move["power"] or 0
        if power == 0 or move["movedamageclass"]["name"] == "status":
            return 0
        flags = {row["moveattribute"]["name"] for row in move["moveattributemaps"]}
        if "charge" in flags or "recharge" in flags:
            power *= 0.5
        meta = (move["movemeta"] or [None])[0] or {}
        hits = ((meta.get("min_hits") or 1) + (meta.get("max_hits") or 1)) / 2
        # Overheat, Draco Meteor, Close Combat: looped, each cast lowers its user again.
        if any(row["change"] < 0 for row in move["movemetastatchanges"]) and \
                ((meta.get("movemetacategory") or {}).get("name")) == "damage-raise":
            power *= 0.6
        accuracy = (move["accuracy"] or 100) / 100
        own = move["type"]["name"] in types
        matches = (move["movedamageclass"]["name"] == "physical") == physical
        return power * hits * accuracy * (1.5 if own else 1) * (1 if matches else 0.55)

    ranked = sorted((n for n in known if damage(n) > 0), key=lambda n: (-damage(n), n))
    chosen = []
    for own in types:
        best = next((n for n in ranked if moves[n]["type"]["name"] == own and n not in chosen), None)
        if best:
            chosen.append(best)
    other = next((n for n in ranked if moves[n]["type"]["name"] not in types and n not in chosen), None)
    if other:
        chosen.append(other)
    def fits(name):
        return not (name in PHYSICAL_BOOSTS and not physical or name in SPECIAL_BOOSTS and physical)

    support = None
    for table in (BOOSTS, RECOVERY, INFLICT):
        options = [n for n in known if n in table and n in moves and fits(n)]
        if support is None and options:
            support = max(options, key=lambda n: (table[n], n))
    # The rest of the loop: a type not covered yet first, then the strongest left.
    for n in ranked:
        if len(chosen) >= (3 if support else 4):
            break
        if n not in chosen and moves[n]["type"]["name"] not in {moves[c]["type"]["name"] for c in chosen}:
            chosen.append(n)
    for n in ranked:
        if len(chosen) >= (3 if support else 4):
            break
        if n not in chosen:
            chosen.append(n)
    chosen = sorted(chosen, key=lambda n: -damage(n))
    if support:
        chosen = [support] + chosen
    return chosen[:4]


def main():
    moves = fetch_moves()
    by_name = {m["name"]: m for m in moves}
    print(f"{len(moves)} moves", file=sys.stderr)
    pokemon = [p for p in fetch_pokemon() if p["pokemonstats"]]
    print(f"{len(pokemon)} varieties", file=sys.stderr)
    learnsets = fetch_learnsets([p["id"] for p in pokemon])
    lines = []
    for p in pokemon:
        stats = {row["stat"]["name"]: row["base_stat"] for row in p["pokemonstats"]}
        abilities = ",".join(f'{a["ability"]["name"]}{"*" if a["is_hidden"] else ""}' for a in p["pokemonabilities"])
        types = [t["type"]["name"] for t in p["pokemontypes"]]
        loop = loop_moves(p, learnsets.get(p["id"], []), by_name, types)
        fields = [p["id"], p["pokemon_species_id"], ",".join(str(stats.get(k, 0)) for k in STAT_KEYS),
                  ",".join(types), abilities, ",".join(loop)]
        lines.append("|".join(str(f) for f in fields))
    move_lines = [move_line(m) for m in moves]
    species_lines = [species_line(s) for s in fetch_species()]

    def literal(rows):
        return "\n".join(rows).replace("\\", "\\\\")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(f'''// Generated by scripts/generate-battle-data.py from PokéAPI. Do not edit by hand: run the script again.
// swiftlint:disable all

/// The battle tables, as text parsed once (`MoveTable`, `SpeciesBattleTable`).
enum BattleDataTables {{
    /// slug|type|class|power|accuracy|priority|target|effectChance|ailment|ailmentChance|critRate|drain|healing|
    /// flinch|minHits|maxHits|minTurns|maxTurns|statChance|stat:change,...|category|flags
    static let moves = """
{literal(move_lines)}
"""

    /// pokemonID|speciesID|hp,atk,def,spa,spd,spe|types|abilities (* = hidden)|loop moves
    static let species = """
{literal(lines)}
"""

    /// speciesID|captureRate|legendary|evolvesFrom|generation
    static let speciesInfo = """
{literal(species_lines)}
"""
}}
''', encoding="utf-8")
    print(f"wrote {OUT} ({len(move_lines)} moves, {len(lines)} varieties)", file=sys.stderr)


if __name__ == "__main__":
    main()
