---
summary: "Collectible alternate forms (Unown letters, Rotom, Arceus…): catalog, draw, Pokédex, save keys and sprite names."
read_when:
  - adding or removing a species' forms, or touching form sprites and their cache keys
  - changing how an individual's form is drawn, saved, imported or displayed
---

# Pokémon forms

Species with alternate forms are collectible across generations 1 to 9, regional
forms included. Gen 1 to 5 forms animate with the Black/White GIFs; Gen 6 to 9
species and regional forms use the Showdown GIFs. The catalog lives in
`PokemonForm.catalog`, default form first. A form on an evolved species is only
rolled when `lineBaseIDs` maps that species to the base of its line
(`PokemonFormLineTests` checks every catalogued species against PokéAPI). The Luck
screen replays past eggs with the forms they could roll: a new line with forms gets
its arrival in `HatchRules.formArrivals` (`testEveryLineWithFormsHasItsArrival`), and
any other change to what an egg rolls gets a `HatchRules.Change`:

| Species | Forms |
| --- | --- |
| Rattata #19, Raticate #20 | normal, alola |
| Raichu #26 | normal, alola |
| Sandshrew #27, Sandslash #28 | normal, alola |
| Vulpix #37, Ninetales #38 | normal, alola |
| Diglett #50, Dugtrio #51 | normal, alola |
| Meowth #52 | normal, alola, galar |
| Persian #53 | normal, alola |
| Growlithe #58, Arcanine #59 | normal, hisui |
| Geodude #74, Graveler #75, Golem #76 | normal, alola |
| Ponyta #77, Rapidash #78 | normal, galar |
| Slowpoke #79, Slowbro #80, Slowking #199 | normal, galar |
| Farfetch’d #83 | normal, galar |
| Grimer #88, Muk #89 | normal, alola |
| Voltorb #100, Electrode #101 | normal, hisui |
| Exeggutor #103 | normal, alola |
| Marowak #105 | normal, alola |
| Weezing #110 | normal, galar |
| Mr. Mime #122 | normal, galar |
| Tauros #128 | normal, paldea-combat, paldea-blaze, paldea-aqua |
| Eevee #133 | normal, starter (Partner Eevee, which does not evolve) |
| Articuno #144 | normal, galar |
| Zapdos #145 | normal, galar |
| Moltres #146 | normal, galar |
| Typhlosion #157 | normal, hisui |
| Wooper #194 | normal, paldea |
| Unown #201 | A–Z, ! and ? |
| Qwilfish #211 | normal, hisui |
| Sneasel #215 | normal, hisui |
| Corsola #222 | normal, galar |
| Zigzagoon #263, Linoone #264 | normal, galar |
| Castform #351 | normal, sunny, rainy, snowy |
| Deoxys #386 | normal, attack, defense, speed |
| Burmy #412, Wormadam #413 | plant, sandy, trash |
| Cherrim #421 | overcast, sunshine |
| Shellos #422, Gastrodon #423 | west, east |
| Rotom #479 | normal, heat, wash, frost, fan, mow |
| Dialga #483, Palkia #484 | normal, origin |
| Giratina #487 | altered, origin |
| Shaymin #492 | land, sky |
| Arceus #493 | the 18 types |
| Samurott #503 | normal, hisui |
| Lilligant #549 | normal, hisui |
| Basculin #550 | red-striped, blue-striped, white-striped |
| Darumaka #554 | standard, galar |
| Darmanitan #555 | standard, zen, galar-standard, galar-zen |
| Yamask #562 | normal, galar |
| Zorua #570, Zoroark #571 | normal, hisui |
| Deerling #585, Sawsbuck #586 | spring, summer, autumn, winter |
| Stunfisk #618 | normal, galar |
| Braviary #628 | normal, hisui |
| Tornadus #641 | incarnate, therian |
| Thundurus #642 | incarnate, therian |
| Landorus #645 | incarnate, therian |
| Kyurem #646 | normal, black, white |
| Keldeo #647 | ordinary, resolute |
| Meloetta #648 | aria, pirouette |
| Genesect #649 | normal, douse, shock, burn, chill |
| Vivillon #666 | meadow, icy-snow, polar, tundra, continental, garden, elegant, modern, marine, archipelago, high-plains, sandstorm, river, monsoon, savanna, sun, ocean, jungle, fancy, poke-ball |
| Flabébé #669, Floette #670, Florges #671 | red, yellow, orange, blue, white |
| Furfrou #676 | natural, heart, star, diamond, debutante, matron, dandy, la-reine, kabuki, pharaoh |
| Meowstic #678 | male, female |
| Aegislash #681 | shield, blade |
| Sliggoo #705, Goodra #706 | normal, hisui |
| Pumpkaboo #710, Gourgeist #711 | average, small, large, super |
| Avalugg #713 | normal, hisui |
| Zygarde #718 | 50, 10, complete |
| Hoopa #720 | confined, unbound |
| Decidueye #724 | normal, hisui |
| Oricorio #741 | baile, pom-pom, pau, sensu |
| Lycanroc #745 | midday, midnight, dusk |
| Wishiwashi #746 | solo, school |
| Silvally #773 | the 18 types |
| Minior #774 | meteor, red, orange, yellow, green, blue, indigo, violet |
| Mimikyu #778 | disguised, busted |
| Necrozma #800 | normal, dusk, dawn, ultra |
| Magearna #801 | normal, original |
| Cramorant #845 | normal, gulping, gorging |
| Toxtricity #849 | amped, low-key |
| Alcremie #869 | 63 looks, `<cream>-<sweet>`: 9 creams × 7 sweets, `vanilla-cream-strawberry` first |
| Eiscue #875 | ice, noice |
| Indeedee #876 | male, female |
| Morpeko #877 | full-belly, hangry |
| Zacian #888 | hero, crowned |
| Zamazenta #889 | hero, crowned |
| Urshifu #892 | single-strike, rapid-strike |
| Zarude #893 | normal, dada |
| Calyrex #898 | normal, ice, shadow |
| Ursaluna #901 | normal, bloodmoon |
| Basculegion #902 | male, female |
| Enamorus #905 | incarnate, therian |
| Oinkologne #916 | male, female |
| Maushold #925 | family-of-four, family-of-three |
| Squawkabilly #931 | green, blue, yellow, white |
| Palafin #964 | zero, hero |
| Tatsugiri #978 | curly, droopy, stretchy |
| Dudunsparce #982 | two-segment, three-segment |
| Gimmighoul #999 | chest, roaming |
| Poltchageist #1012 | counterfeit, artisan |
| Sinistcha #1013 | unremarkable, masterpiece |
| Ogerpon #1017 | teal, wellspring, hearthflame, cornerstone |
| Terapagos #1024 | normal, terastal, stellar |

Left out on purpose: spiky-eared Pichu and Arceus `unknown`, gender differences
that are not catalogued forms (such as female Frillish), Mothim's cloaks (same
sprite), and battle-only transformations such as Mega Evolution and Gigantamax.
Pikachu's costumes and caps are not forms either: see below.

## Pikachu's costumes

Pikachu's 15 costumes and caps (`PikachuCostume`: Rock Star, Belle, Pop Star,
Ph.D., Libre, Cosplay, the eight caps and Partner Pikachu) are worn over its
look. An egg never rolls them and the Pokédex's form count leaves them out.
Each Pikachu that arrives brings one the save doesn't have yet
(`CompanionState.pikachuCostumes`) and wears it while it grows
(`MonState.pikachuCostume`). Every other Pikachu wears the one equipped on its
Pokédex page (`equippedPikachuCostume`), or its own look with None. All fifteen
unlock the Light Ball. Their sprites are PokéAPI's costume varieties
(`10080` for the Rock Star).

## Drawing a form

The form belongs to the individual and is drawn once for the whole line, when
the egg's species is prepared (so the exact normal and shiny sprites can be
cached before hatching) or at hatch time without preparation. Cherubi, Darumaka
and Burmy eggs therefore already know which Cherrim, Darmanitan or Wormadam
they will become. Each species of the line shows the form when it has it and
its default otherwise: a sandy Burmy that evolves into Mothim keeps `sandy` on
record but looks like Mothim. Evolution paths are unchanged.

The draw reuses the species selector's collected-weight adjustment: each
uncollected form has weight 2 and each collected form has weight 1. Ownership
includes active and recorded Pokémon, regardless of shiny color. In lines where
several species show the form, it counts as collected only once every one of
them is owned in it. There is no duplicate streak counter or guaranteed new
form, and the draw does not change species weights or shiny odds.

## Pokédex

The main Pokédex shows one cell per species with a form count (`3/4`). The
detail page lists every form, with uncollected ones dimmed and disabled.
Selecting a collected form lists only its individuals and allows that form to
be chosen as the representative, which then keeps its form in the menu bar and
floating pet. Shiny ownership is tracked per form; normal and shiny variants do
not increase completion.

Labels come from PokéAPI `pokemon-form` `form_names` (30-day cache), with the
identifier shown until they load. Unown shows its letter. Castform, Rotom,
Kyurem and Genesect have no official name for their usual look, so it is shown
as the app's localized "Normal Form". The companion's title, the form picker
and the hatch, evolution and graduation messages add a `[form]` suffix to
non-default forms. Labels one thumbnail wide (capture log, recap chips) only
keep Unown's letter; their sprite already shows the form. Names are loaded with
the egg's sprites, when the raised Pokémon's line loads, and by the views that
show them.

Forms change appearance, names and collection slots. Types, stats, abilities,
height, weight and moves continue to use the species' default-form data. When
these details are loaded for a non-default form, Home and the Pokédex show a
localized "Data uses the default form" note beside the type badges. The note
also applies to the remaining detail sections; selecting a form does not reroll
the individual's profile or fetch separate battle metadata.

## Saves

Saves use `form` on active Pokémon and Pokédex entries, `pendingForm` on
prepared eggs, and `representativeForm` for the selected representative. Values
are PokeAPI form identifiers (`sky`, `blue-striped`, `exclamation`…). The former
Unown keys `unownForm`, `pendingUnownForm` and `representativeUnownForm` are
still read. A form that does not belong to the line falls back to its default,
so older Unown records without a letter keep their A appearance.

Downgrading loses forms: older versions only read the former Unown keys, so
their Unown individuals fall back to A and other forms are dropped when they
save.

## Sprites

Animated GIFs and cache keys use `<id>-<form>` (`492-sky.gif`,
`201-question.gif`), and the default form keeps the plain `<id>` names. Static
PNGs use the PokeAPI Pokémon ID for forms that are separate Pokémon
(`10006.png` for Sky Shaymin) and `<id>-<form>` for cosmetic forms
(`412-sandy.png`). Alcremie's PNGs keep PokéAPI's `-sweet` (`869-ruby-cream-strawberry-sweet.png`)
while its GIFs drop it (`PokemonForm.pngName`). Showdown names Maushold's
Family of Three `925` and its Family of Four, PokéAPI's default, `925-four`
(`SpriteStore.showdownNames`).
