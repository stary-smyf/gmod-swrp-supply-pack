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
6. E na wlasnej paczce podnosi ja; kolejny rzut jest dostepny po 3 sekundach.

Alternatywnie w konsoli Sandbox: `give weapon_supplypack`

## Domyslne parametry
- Zasieg: 5 m (262,45 jednostek Source w skali HL2).
- Czas zycia: 600 s (10 minut).
- Cooldown rzutu: 25 s.
- Kazde 2 s przez caly czas zycia paczki: +5 HP, +5 pancerza i +100 amunicji kazdego typu uzywanego przez posiadane bronie.
- Bronie ze wspolna amunicja otrzymuja jeden przydzial danego typu na impuls.
- Nie przekracza maksymalnego HP i pancerza gracza.
- Paczka uzupelnia zapas do 1000 sztuk kazdego typu, niezaleznie od nizszych limitow podnoszenia amunicji silnika.
- Jedna aktywna paczka na rzucajacego gracza.
- Wplywa na wszystkich zywych graczy w promieniu, bez sprawdzania druzyn lub przeszkod.
- Wyswietla prosty zielony okrag zasiegu.

## Konfiguracja
Wszystkie parametry zmienisz w pliku:
`lua/autorun/sh_supplypack_config.lua`

Szczegolnie istotne: `Radius`, `Lifetime`, `ThrowCooldown`, `PulseInterval` (zdrowie i pancerz), `AmmoPulseInterval` (amunicja),
`HealthPerPulse`, `ArmorPerPulse`, `AmmoPerPulse`, `AmmoReserveCap`, `DrawRangeCircle`.

## Modele
- Model rzuconej paczki: `models/custom/scifiboxes/crate_d.mdl` (skala 0.5; wymaga zainstalowanego modelu).
- Model broni w rekach: standardowy granat HL2.

Mozna pozniej zastapic je wlasnymi modelami.

## Techniczne
- Bron (SWEP): `weapon_supplypack`
- Encja: `ent_supplypack`
- Logika leczenia i amunicji dziala na serwerze, zeby gracze nie mogli latwo manipulowac punktami z klienta.
- Celowany tryb: Sandbox, gra jedno- i wieloosobowa.
- Nie przeprowadzono testu w uruchomionej grze, dlatego moga byc potrzebne drobne poprawki dla specyficznych gamemode'ow lub niestandardowej amunicji.
