# NCC — Norwegian Carry Crew

En World of Warcraft addon for Norwegian Carry Crew. Spiller egne lyder for hendelser som død, loot og pull timers — med full synk slik at hele gruppa holder takten.

## Funksjoner

- **Pull Timer** — Nedtelling på skjermen med stemte tall (5 → 1 → GO) og synkronisert med alle NCC-brukere i gruppa via addon-meldinger
- **Dødslyder** — Spiller en unik trist lyd når et tracket guildmedlem dør
- **Ring-varsel** — Spiller en lyd når en ring dropper i en 5-manns dungeon
- **Egendefinerte grupper** — Legg til spillere i lydgrupper med `/ncc add`, lagres mellom reloads

## Slash-kommandoer

| Kommando | Beskrivelse |
|---|---|
| `/ncc on` / `off` / `toggle` | Skru addon av eller på |
| `/ncc pull [sekunder]` | Start en synkronisert pull timer (standard 10s, maks 60s) |
| `/ncc pull cancel` | Avbryt aktiv pull timer |
| `/ncc test` | Spill lust-lyden |
| `/ncc test <gruppe>` | Spill trist-lyd for en spesifikk gruppe |
| `/ncc death` | Spill trist-lyd for group1 |
| `/ncc ring` | Spill ring-loot-lyden |
| `/ncc groups` | Vis alle grupper og medlemmer |
| `/ncc add <navn> <gruppe>` | Legg til en spiller i en gruppe (lagres mellom reloads) |

## Installasjon

1. Trykk på den grønne **Code**-knappen på repoet og velg **Download ZIP**
2. Pakk ut `NCC`-mappen til `World of Warcraft/_retail_/Interface/AddOns/`
3. Start spillet på nytt eller skriv `/reload`

## Pull Timer Synk

Når du bruker `/ncc pull`, starter alle gruppe-/raidmedlemmer med NCC automatisk sin egen lokale nedtelling med lyder. Avbryt fungerer også — `/ncc pull cancel` stopper timeren for alle.
