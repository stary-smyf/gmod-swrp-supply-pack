-- Paczka zaopatrzeniowa - wspolna konfiguracja (serwer + klient).
-- Zmien wartosci ponizej, aby dopasowac balans do swojego serwera.
if SERVER then
    AddCSLuaFile()
end

SupplyPack = SupplyPack or {}
SupplyPack.Config = {
    BoxColor = Color(255, 0, 0), -- kolor wszystkich modeli paczki
    -- 1 metr ~ 52.49 jednostek Source (skala postaci HL2).
    Radius = 3 * 52.49,

    Lifetime = 600,          -- czas istnienia paczki (sekundy)
    ThrowCooldown = 30,     -- odstep miedzy rzutami (sekundy)
    PickupCooldown = 5,     -- odstep do kolejnego rzutu po podniesieniu paczki
    PulseInterval = 1,    -- co ile sekund uzupelniac zdrowie i pancerz
    AmmoPulseInterval = 5, -- co ile sekund uzupelniac amunicje

    HealthPerPulse = 5,     -- punkty HP na impuls
    ArmorPerPulse = 5,      -- punkty pancerza na impuls
    AmmoPerPulse = 100,    -- amunicja kazdego posiadanego typu na impuls

    AmmoReserveCap = 1000, -- dodatkowy limit zapasu dla kazdego rodzaju amunicji
    AmmoReserveCaps = {
        rpg_round = 3,
        grenade = 3,
        smg1_grenade = 3,
        ar2altfire = 3,
    },
    DrawRangeCircle = true -- wyswietlaj okrag zasiegu na ziemi
}
