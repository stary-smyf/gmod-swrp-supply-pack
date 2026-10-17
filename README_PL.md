# Paczka zaopatrzeniowa — Garry's Mod

Prototyp addonu: rzucasz paczke pod nogi jak w strzelankach Battlefield.
Paczka automatycznie regeneruje HP, pancerz i zapas amunicji u zywych graczy w promieniu ok. 5 m.
Dziala bez dodatkowych modeli i zaleznosci.

## Instalacja
1. Wypakuj archiwum ZIP.
2. Skopiuj caly folder `supply_pack_gmod` do katalogu `garrysmod/addons/`.
3. Uruchom ponownie Garry's Mod (lub serwer).
4. Otworz Sandbox -> Q -> Bronie -> Zaopatrzenie -> `Paczka zaopatrzeniowa`.
5. Lewy przycisk myszy (LPM) rzuca paczke.

Alternatywnie w konsoli Sandbox: `give weapon_supplypack`

## Domyslne parametry
- Zasieg: 5 m (262,45 jednostek Source w skali HL2).
- Czas zycia: 20 s.
- Cooldown rzutu: 25 s.
- Kazde 0,5 s: +5 HP, +5 pancerza, +10 amunicji kazdego typu z posiadanych broni.
- Nie przekracza maksymalnego HP i pancerza gracza.
- Amunicja nie przekracza nizszego z dwoch limitow: limitu typu amunicji i 180 sztuk rezerwy.
- Jedna aktywna paczka na rzucajacego gracza.
- Wplywa na wszystkich zywych graczy w promieniu, bez sprawdzania druzyn lub przeszkod.
- Wyswietla prosty zielony okrag zasiegu.

## Konfiguracja
Wszystkie parametry zmienisz w pliku:
`lua/autorun/sh_supplypack_config.lua`

Szczegolnie istotne: `Radius`, `Lifetime`, `ThrowCooldown`, `PulseInterval`,
`HealthPerPulse`, `ArmorPerPulse`, `AmmoPerPulse`, `AmmoReserveCap`, `DrawRangeCircle`.

## Modele
- Model rzuconej paczki: `models/items/boxmrounds.mdl` (standardowy HL2).
- Model broni w rekach: standardowy granat HL2.

Mozna pozniej zastapic je wlasnymi modelami.

## Techniczne
- Bron (SWEP): `weapon_supplypack`
- Encja: `ent_supplypack`
- Logika leczenia i amunicji dziala na serwerze, zeby gracze nie mogli latwo manipulowac punktami z klienta.
- Celowany tryb: Sandbox, gra jedno- i wieloosobowa.
- Nie przeprowadzono testu w uruchomionej grze, dlatego moga byc potrzebne drobne poprawki dla specyficznych gamemode'ow lub niestandardowej amunicji.
