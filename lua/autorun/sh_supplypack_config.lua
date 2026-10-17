-- Paczka zaopatrzeniowa - wspolna konfiguracja (serwer + klient).
-- Zmien wartosci ponizej, aby dopasowac balans do swojego serwera.
if SERVER then
    AddCSLuaFile()
end

SupplyPack = SupplyPack or {}
SupplyPack.Config = {
    -- 1 metr ~ 52.49 jednostek Source (skala postaci HL2).
    Radius = 5 * 52.49,

    Lifetime = 20,          -- czas istnienia paczki (sekundy)
    ThrowCooldown = 25,     -- odstep miedzy rzutami (sekundy)
    PulseInterval = 0.5,    -- co ile sekund uzupelniac zasoby

    HealthPerPulse = 5,     -- punkty HP na impuls
    ArmorPerPulse = 5,      -- punkty pancerza na impuls
    AmmoPerPulse = 10,     -- sztuk amunicji danego rodzaju na impuls

    AmmoReserveCap = 180,  -- dodatkowy limit zapasu dla kazdego rodzaju amunicji
    DrawRangeCircle = true -- wyswietlaj okrag zasiegu na ziemi
}
