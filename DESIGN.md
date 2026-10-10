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
Planner.Build (pure)  knowledge: name > signature > rules ─► fixed icons ─► kill ladder ─► CC pass ─► CC fallback ─► overflow
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
| Clear all marks | `TMF_ClearButton` | macro: `/click TMF_ClearAll` (`clear-all`), then `/click TMF_FollowK` per follow mark; also resets the selection |

## Modules
| File | Role |
|---|---|
| `Core/Init.lua` | namespace `TMF` (global `TankMarkForever`), modules, `TMF:On/Fire` messages, blocked-action interceptor |
| `Core/Config.lua` | defaults, `TankMarkForeverDB`, learned mobs per zone |
| `Core/Utils.lua` | secret-safe reads, icon helpers |
| `Data/ModelNames.lua` | generated: creature model file ID -> model name (tools/gen-model-names.ps1) |
| `Data/InstanceMobs.lua` | generated: instance map + model file ID -> NPC variants (type, power, levels, CC immunities, name), from the 1.12 world DB + Forever DB2 (tools/gen-instance-mobs.ps1) |
| `Data/Rules.lua` | pure legacy rules: CC legality, role×tier priority, CC worthiness, power→role, signature |
| `Modules/Plates.lua` | nameplate records, Shift-hover selection, deaths |
| `Modules/MobDB.lua` | learned mobs per zone (by name / by signature), learn/forget, edits, labels, recorder (new mob types in dungeons become entries) |
| `Modules/Team.lua` | the team setup (kill order, tank owners, CC players), roster, announcement |
| `Modules/Planner.lua` | pure `Build` (legacy `DecidePull` port) + shell (rebuild out of combat, reserved icons, report) |
| `Modules/Marker.lua` | the secure buttons, snippets, attribute writer, pull lock |
| `Modules/Overlay.lua` | planned-icon preview frames |
| `UI/Setup.lua` | team setup window (`/tmf`): 8 rows icon/role (Tank/CC)/player, up/down, Announce |
| `UI/HUD.lua` | always-on HUD: marks in use, on/off per mark, collapsible title bar, saved position |
| `UI/Mobs.lua` | mob database window (`/tmf mobs`): zone arrows, paged rows, type/prio/icon/class/delete, signature labels; signatures named from the offline data ("Ragefire Trogg", "Searing Blade Cultist +1", all names in the tooltip), your note wins |
| `UI/Commands.lua` | `/tmf` |

## Known limits
- One key press per pull; nothing happens on its own.
- Distance: only steps up to ~30 yd, player to mob (exact distance and positions are blank for mobs). "Only plan nearby
  mobs" (default on) plans plates within ~30 yd (range item 835, fallback interact check 4), re-checked every 0.5 s out
  of combat; a Shift-hover selection overrides it. It can't tell two packs at the same distance apart.
- Line of sight: no API; the engine fades the plate of a mob hidden behind terrain (alpha x nameplateOccludedAlphaMult).
  With the default CVars hidden plates read 0.24-0.40, visible 0.60-1.00, so the same checkbox leaves hidden mobs out
  ("out of sight"). A mob you can see on a ledge below or above is in sight and still planned (height isn't readable).
- Inside instances mobs are known only by signature: classification, power type and **model file** (level-free, so one
  entry covers a mob type at all levels). Different mobs sharing a body, classification and power share an entry; that's
  common in humanoid dungeons, where many NPCs use the same human model file (their looks are textures/gear). The model
  comes from an unguarded API (`SetModelByUnitCreatureDisplayID`); if Blizzard closes it, signatures fall back to
  level|classification|power.
- In combat a `nameplateN` token is no mob identity: plates flicker (line of sight) and a dead mob's token was handed to
  another mob in the same second. A frozen kill order hit the wrong mob in-game, and a state-driver guard (0.2 s polling)
  missed it. Secure code can't read names, levels or marks, and can't read data written by addon code in combat
  (`GetPossiblyForbiddenHandleFrame` + `scrub`). Hence target-based override keys (mouseover is too unreliable in a fast fight). The pack key in combat uses tokens frozen
  at the pull (`set-unmarked`, so it can only add icons to unmarked mobs).
- The next-free-icon key hands out icons that were unused at the pull. An icon freed in combat (e.g. cross after
  it was promoted to skull) isn't reused until combat ends: secure code can't see marks, and guessing could move a live mark.
- Blizzard's announced macro marking throttle doesn't apply on Forever (5+ marks per press, in-game).
- Creature type is secret inside instances. The offline data restores it from (instance, model file), keeping the
  NPCs that match the plate's power type and level, but only when they all agree. Player-race bodies shared by
  humanoids and undead (BRD, Scholomance, Stratholme, Dire Maul, ZF, Sunken Temple) often stay unknown → no auto CC.
  NPCs summoned by scripts aren't in the spawn data. Immunities come from the server emulator DB, not Blizzard.
- Dungeon bosses show as "elite" on Forever. The data marks encounter bosses (their kill completes a DungeonEncounter);
  when every matching NPC is one, the tier becomes "boss": kill priority 1, no CC, and its own signature
  ("boss|RAGE|<model>"), so it doesn.t share the learned entry of trash on the same body.

## Team setup (milestone 3)
One active setup (user choice), edited in `/tmf`. Rows in kill order; each row = icon + role + optional player.
Every mob is killed, so the role only says what happens to the marked mob first (user, 2026-10-10; legacy model):
- **Tank**: in the kill ladder in row order; an owning tank (optional) takes the icon out of the ladder while dead/offline.
- **CC**: needs a player in the group; becomes a CC slot (class/race from the roster) for the planner's CC pass.
- **Follow**: needs a player; that group member (the tank) wears the mark so the group can follow them. Never planned
  on a mob (reserved, even while off), not in the ladder or the cycle key, not allowed on skull (the next-skull key
  moves skull). Buttons `TMF_Follow1..8` (raidtarget, `set-unmarked`: re-applying a worn icon removes it,
  kb/gotchas.md#mark-toggle), unit `player` for yourself, else the member's party/raid token, set out of combat.
  The pack key puts follow marks on first; the clear key clears all, then puts them back. Announced as `Follow:`.

**On/off is separate from the role** and lives in the HUD (`row.off`, saved): a mark that's off isn't planned, isn't
handed out by the next-free-icon key and isn't announced. Setups saved before the split migrate at load (Kill → Tank,
Off → Tank switched off).

## HUD (`UI/HUD.lua`)
Legacy `TankMark_HUD.lua` concept: the leader fits the marks to the pack in front of them. Always shown while
TankMark is enabled (user choice). Like the quest tracker, clicking the title bar collapses/expands it; dragging the
title bar moves it unless the lock icon in the title bar is on. Position (top-left corner), lock, collapsed state and
every mark's on/off are saved. Sections: Tank, CC, Follow.
- Rows: Tank marks (numbered in kill order), then CC marks, each with the owning player (class colour) and the mob
  the current plan puts the mark on. Which mob actually *wears* a mark can't be shown (secret on Forever).
- Left-click a row: switch the mark on/off (plan and keys follow at once; in combat it applies when combat ends).
  Right-click: open the setup. **All on** appears in the title bar while any mark is off; the title counts them.
- No right-click menu as in legacy: addon dropdown menus crash the beta (kb/gotchas.md#menu-crash).

CC inside instances: the creature type comes from the offline data (`Data/InstanceMobs.lua`), so leftover casters get a
legal CC slot as in the open world, and slots whose CC the mob is immune to are skipped. Where the data can't tell
the type, only mobs taught as CC (`/tmf learn cc [class]`) get a CC slot. `/tmf plan` shows each mob's type
("Humanoid (data)", "type ?") and immunities.
**Announce** (button or `/tmf announce`): `[TankMark] Kill order: {rt8} Tank > {rt7} > ...` then `[TankMark] CC: {rt5} Mage (Polymorph)` to
party/raid; nothing is posted automatically. Marks switched off aren't announced.

## Mob database (milestone 2)
`/tmf mobs` (or **Mobs** in the setup window). Per zone (arrows switch zones; no dropdowns), 10 rows per page:
- **name** rows: matched by mob name (open world). **sig** rows (instances, where names are hidden): matched by
  classification|power type|model file, e.g. `elite|RAGE|126512` = "elite worm melee"; the first column shows the levels
  seen (e.g. 13-15). Model names come from `Data/ModelNames.lua`, generated by `tools/gen-model-names.ps1` (workspace
  repo) from the community listfile. A sig without a model (`14|elite|RAGE`: learned before, or with the loophole
  closed) covers every model of that level/class/power; a model entry wins. Step-1 keys (`level|tier|power|model`) are
  migrated at load; duplicates merge (announced in chat). The label is an edit box, so a signature can be named
  "Earthborer"; `/tmf plan` uses it.
- Per row: type Tank/CC/Ignore = the kind of mark the mob prefers (Tank: kill ladder by priority, leftovers may still be
  CC'd; CC: a CC mark, else the next tank mark; Ignore: no mark; saved "KILL" entries migrate to "TANK"), priority -/+ (1 = first),
  fixed icon (click cycles auto, skull..star; right-click: auto),
  CC class (CC rows), delete. **Learn target** adds the target with the rules' default priority.
- Legacy TankMark data isn't imported: its database is keyed by name for raids, where names are secret on Forever.

## Milestones
1. **Marking loop** (done, in-game confirmed): plates, planner (rules + learning via `/tmf learn`), the four keys, overlay, tests.
2. **Mob database UI** (done, in-game confirmed): per-zone list, edit type/prio/icon/class, signature labels. Model
   signatures (identity step 1) built, in-game test pending; step 2 (offline NPC names per dungeon) optional.
3. **Team setup** (done, in-game confirmed): kill order and CC from the setup window, announcement.
   **Tank/CC roles + HUD on/off**, mob types Tank/CC/Ignore + CC fallback (in-game confirmed 2026-10-10).
4. Sync: share the database and profiles over addon messages (work in dungeons, including trash combat).
5. **Follow mark** + HUD lock (in-game confirmed 2026-10-10): see Team setup. One clear press keeps the follow mark:
   the client registers the clear-all before the follow button's `set-unmarked` check in the same macro.
