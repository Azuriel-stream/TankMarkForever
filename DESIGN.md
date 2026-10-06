# TankMark Forever: design

A rewrite of TankMark (Turtle WoW 1.12 + SuperWoW, legacy v0.32) for WoW: Forever (interface 16001), built on
the *concept*, not the code. Evidence for every Forever fact: `kb/addons/TankMark.md` (spike runs 1-4) in the
workspace repo.

## Why a redesign
| Legacy (SuperWoW) | Forever reality | TankMark Forever |
|---|---|---|
| Scanner marks mobs automatically as they appear | Addon `SetRaidTarget` is **forbidden everywhere** | Marks only on a **key press**, through Blizzard's secure `raidtarget` action |
| Mob database by name | Names/GUIDs are **secret in combat**, and **always secret inside dungeons and raids** | Learned by name in the open world, by **signature** (level, classification, power type) inside instances, rules otherwise |
| In-combat skull succession, death cleanup | Addon can't change secure attributes in combat; `nameplateN` tokens churn in combat | Pack marked pre-pull; the group follows the agreed icon order. In combat, override keys act on your **target**: **next skull**, **next free icon** |
| Reads existing marks | `GetRaidTargetIndex` is secret | `set-unmarked` (secure) never overwrites; `GetNextAvailableRaidTargetMarkerIndex` tells which icons are worn |
| WotLK/Ascension: two hover sweeps | Nameplate tokens exist on Forever | Plan from all visible plates (or a Shift-hover selection), mark all with **one** key |

## Flow
```
NAME_PLATE_UNIT_ADDED ─► Plates (record per nameplateN: name?, level, tier, power, sig, dead)
        │ debounced PLATES_CHANGED (out of combat)
        ▼
Planner.Build (pure)  knowledge: name > signature > rules ─► fixed icons ─► kill ladder ─► CC pass ─► overflow
        │ PLAN_CHANGED
        ├─► Marker: writes secure attributes (TMF_Mark1..8 units/icons, pack macro, skull kill list, cycle icons)
        └─► Overlay: planned icon above each plate
Key press ─► TMF_PackButton macro: /click TMF_Mark1..N  (raidtarget, set-unmarked) ─► marks
```
In combat nothing is rewritten (attributes are frozen); the skull and cycle snippets still run.

## Keys (Key Bindings > AddOns)
| Key | Button | Does |
|---|---|---|
| Mark planned pack | `TMF_PackButton` | one press marks every planned mob (5+ at once confirmed, no throttle) |
| Next skull on target | `TMF_SkullButton` | override: skull moves to your (hostile, living) target; works in combat |
| Next free icon on target | `TMF_CycleButton` | next ladder icon nobody wears, on your target (adds); skips marked mobs |
| Clear all marks | `TMF_ClearButton` | `clear-all`; also resets the selection |

## Modules
| File | Role |
|---|---|
| `Core/Init.lua` | namespace `TMF` (global `TankMarkForever`), modules, `TMF:On/Fire` messages, blocked-action interceptor |
| `Core/Config.lua` | defaults, `TankMarkForeverDB`, learned mobs per zone |
| `Core/Utils.lua` | secret-safe reads, icon helpers |
| `Data/Rules.lua` | pure legacy rules: CC legality, role×tier priority, CC worthiness, power→role, signature |
| `Modules/Plates.lua` | nameplate records, Shift-hover selection, deaths |
| `Modules/Planner.lua` | pure `Build` (legacy `DecidePull` port) + shell (rebuild out of combat, reserved icons, report) |
| `Modules/Marker.lua` | the secure buttons, snippets, attribute writer, pull lock |
| `Modules/Overlay.lua` | planned-icon preview frames |
| `UI/Commands.lua` | `/tmf` |

## Known limits
- One key press per pull; nothing happens on its own.
- Inside instances mobs are known only by signature: two mob types with the same level, classification and power
  type share one entry.
- In combat a `nameplateN` token is no mob identity: plates flicker (line of sight) and a dead mob's token was handed to
  another mob in the same second. A frozen kill order hit the wrong mob in-game, and a state-driver guard (0.2 s polling)
  missed it. Secure code can't read names, levels or marks, and can't read data written by addon code in combat
  (`GetPossiblyForbiddenHandleFrame` + `scrub`). Hence target-based override keys (mouseover is too unreliable in a fast fight). The pack key in combat uses tokens frozen
  at the pull (`set-unmarked`, so it can only add icons to unmarked mobs).
- The next-free-icon key hands out icons that were unused at the pull. An icon freed in combat (e.g. cross after
  it was promoted to skull) isn't reused until combat ends: secure code can't see marks, and guessing could move a live mark.
- Blizzard's announced macro marking throttle doesn't apply on Forever (5+ marks per press, in-game).
- No CC planning inside instances unless the learned entry names a CC class (creature type is secret there).

## Milestones
1. **Marking loop** (this): plates, planner (rules + learning via `/tmf learn`), the four keys, overlay, tests.
2. Mob database UI: per-zone list of learned names and signatures, edit prio/icon/type, import of legacy data.
3. Team profiles: kill ladder and CC slots from players (mark → tank/CC), HUD, plan announcement.
4. Sync: share the database and profiles over addon messages (work in dungeons, including trash combat).
