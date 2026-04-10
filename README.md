# Twisted Treeline

A fan-made recreation of League of Legends' retired **Twisted Treeline** 3v3 MOBA game mode, built in **Godot 4** (GDScript).

> Twisted Treeline was removed from League of Legends in November 2019. This project brings it back as a standalone, open-source game.

---

## Current State — MVP

The MVP covers the full core gameplay loop: champion selection, laning, jungling, objectives, and nexus destruction. It runs locally on Mac (and any platform Godot 4 exports to). Multiplayer is built in via ENet — LAN host/join works, a dedicated Ubuntu server is planned next.

### What's implemented

| System | Status |
|---|---|
| Map: 2 lanes + jungle, 3200×2000px | ✅ |
| 3 playable champions (Garen, Ashe, Annie) | ✅ |
| 4 abilities per champion, fully scripted | ✅ |
| Click-to-move, attack-move (A+click) | ✅ |
| Basic attacks with on-hit effects | ✅ |
| Minion waves (melee, caster, cannon, super) | ✅ |
| Tower AI (7 per team, priority targeting) | ✅ |
| Inhibitor + Nexus destruction / win condition | ✅ |
| Altar capture mechanic (9s, 90s seal, buffs) | ✅ |
| Vilemaw boss (spawns 10:00, Crest buff) | ✅ |
| Jungle camps (Golems + Wraiths, 75s respawn) | ✅ |
| Health packs in jungle | ✅ |
| Economy (passive gold, kill/assist gold, XP) | ✅ |
| Level scaling (1–18, stat growth) | ✅ |
| Status effects (Slow, Silence, Stun, Knockup, Knockback, Shield, Ghost) | ✅ |
| Fog of war (team vision, per-unit radius) | ✅ |
| Champion select screen | ✅ |
| HUD (HP/mana bars, ability cooldowns, gold, scoreboard, altar/Vilemaw timers) | ✅ |
| Victory/defeat screen | ✅ |
| LAN multiplayer host/join (ENet) | ✅ |
| Respawn system (scales with level) | ✅ |

### What's intentionally deferred (post-MVP)

- Item shop (champions use fixed starting loadouts for now)
- Ranked/matchmaking
- Wards and ward items
- Sound and music
- Champion animations (placeholder colored rects)
- Spectator mode / replay system
- Dedicated Ubuntu server deployment

---

## Champions

Three champions are available, each with a full Q/W/E/R kit:

### Garen — Fighter
Melee bruiser with no mana. Built for diving and sustained fighting.
- **Q — Decisive Strike:** Silences the target and empowers Garen's next basic attack.
- **W — Courage:** Passive armor/MR stacks on kills. Active: 60% damage reduction brace → 30% for duration.
- **E — Judgment:** Spins for 3 seconds dealing AOE physical damage to all nearby enemies.
- **R — Demacian Justice:** True damage execute scaling with target's missing HP.

### Ashe — Marksman
Long-range carry with slows and global CC. Fragile but high utility.
- **Q — Ranger's Focus:** Stacks Focus on basic attacks; at 4 stacks fires a 4-arrow cone.
- **W — Volley:** Fires 7 slowing arrows in a cone.
- **E — Hawkshot:** Sends a hawk scouting to a target location, revealing an area.
- **R — Enchanted Crystal Arrow:** Global skillshot — stuns first champion hit for 1–3.5s (scales with distance).

### Annie — Mage
High burst mage with a powerful stun passive. Biggest damage threat at range.
- **Passive:** Every 4th ability cast stuns the next target hit (1.75s).
- **Q — Disintegrate:** Fireball that refunds mana on kill.
- **W — Incinerate:** AOE cone of fire.
- **E — Molten Shield:** Shields Annie and reflects damage back at attackers.
- **R — Summon: Tibbers:** Calls down a giant bear dealing burst AOE damage, then aura damage for 45 seconds.

---

## Map — Twisted Treeline Layout

```
[Blue Nexus] ←── Top Lane ──────────────────────── Top Lane ──→ [Red Nexus]
                    ↑                                     ↑
             [Altar A]    [Golems] [Vilemaw] [Wraiths]    [Altar B]
                    ↓       Jungle (450–1550px)            ↓
[Blue Nexus] ←── Bot Lane ──────────────────────── Bot Lane ──→ [Red Nexus]
```

- **Canvas size:** 3200 × 2000 px
- **Blue base:** x 0–350 | **Red base:** x 2850–3200
- **Top lane:** y 0–450 | **Bot lane:** y 1550–2000 | **Jungle:** y 450–1550
- **Towers:** 2 outer → 2 inner → 2 inhibitor → 1 nexus per team (7 each)
- **Altar A:** (850, 750) blue-side jungle | **Altar B:** (2350, 750) red-side jungle
- **Vilemaw:** (1600, 750) center jungle — spawns at 10:00, respawns after 6 min
- **Jungle camps:** Golems + Wraiths per side, 75s respawn
- **Health packs:** 3 locations in jungle, 30s respawn, 12% HP/mana + 30% speed boost

---

## Altar Mechanic

Stand on an altar for 9 seconds (faster with more allies, paused if contested) to capture it. It seals for 90 seconds after capture.

| Altars owned | Bonus |
|---|---|
| 0 | None |
| 1 | +10% movement speed for your team |
| 2 | +1% max HP regenerated on kill/monster for your team |

Each capture grants **80 gold** to every teammate.

---

## Vilemaw — Crest of Crushing Wrath

Kill Vilemaw (8000 HP) to grant all living teammates a 3-minute buff:

- **Champions:** Ghosted (ignore unit collision)
- **Melee minions:** +20 armor/MR, +20% attack speed, +15 AD, +75 range
- **Caster minions:** +10 armor/MR, +10% attack speed, +20 AD, +100 range

---

## How to Run

### Requirements
- [Godot 4.2+](https://godotengine.org/download) (free)

### Local (solo / debug)
1. Clone the repo
2. Open Godot → **Import** → select `project.godot`
3. Press **F5** to run
4. On the Champion Select screen, pick a champion and press **READY** — without connecting, it drops you into solo debug mode (Blue Garen vs Red Annie)

### Local Multiplayer (same network)
1. One machine presses **Host (Local)** on the Champion Select screen
2. Other machines enter the host's LAN IP and press **Join**
3. All players pick a champion and press **READY**
4. The host starts the game

> Default port: **7777** (configurable in the UI)

---

## Project Structure

```
TwistedTreeline/
├── project.godot
├── scenes/
│   ├── Main.tscn                  # Game root
│   ├── Champions/                 # Garen, Ashe, Annie scenes
│   ├── Map/                       # TwistedTreeline, Tower, Altar, Nexus, HealthPack
│   ├── Units/                     # Minion, Vilemaw
│   └── UI/                        # ChampionSelect, HUD, VictoryScreen
└── scripts/
    ├── champion/                  # ChampionBase + per-champion ability scripts
    │   ├── garen/                 # Garen, GarenQ, GarenW, GarenE, GarenR
    │   ├── ashe/                  # Ashe, AsheQ, AsheW, AsheE, AsheR
    │   └── annie/                 # Annie, AnnieQ, AnnieW, AnnieE, AnnieR
    ├── systems/                   # GameManager, EconomyManager, CombatSystem,
    │   │                          # AbilitySystem, StatusEffect, WaveManager, FogOfWar
    ├── units/                     # Tower, Minion, JungleMonster, Vilemaw, Nexus
    ├── map/                       # Altar, HealthPack, JungleCamp, MapSetup
    ├── network/                   # NetworkManager (ENet)
    └── ui/                        # Main, HUD, ChampionSelect, VictoryScreen
```

---

## Roadmap

### Phase 2 — Playability
- [ ] Configure NavigationRegion2D walkable polygon in Godot editor (lanes + jungle)
- [ ] Placeholder sprites for all units (currently colored rectangles)
- [ ] Minimap showing terrain, allies, visible enemies
- [ ] Basic sound effects (attacks, abilities, death, objectives)
- [ ] Fix any remaining runtime script errors from first full playthrough

### Phase 3 — More Champions
- [ ] Malphite (Tank) — Q slow, W armor, E AOE slow, R knockup
- [ ] Janna (Support) — Q tornado, W speed aura, E shield ally, R knockback heal
- [ ] Akali (Assassin) — Q mark, W smoke shroud stealth, E dash, R multi-dash
- [ ] Bring total to 6 champions (original Twisted Treeline draft target)

### Phase 4 — Item Shop
- [ ] In-game gold → item purchase system at fountain
- [ ] Starting item sets per role
- [ ] Core items: Doran's Blade/Ring/Shield, basic boots, component items
- [ ] Item effects wired into stats (e.g. Rabadon's AP%, lifesteal, armor pen)

### Phase 5 — Dedicated Server
- [ ] Export Godot headless server binary
- [ ] Deploy to Ubuntu VPS (port-forwarded)
- [ ] Server lobby: players connect by IP, host starts when all ready
- [ ] Authoritative server model (server runs game logic, clients sync state)
- [ ] Basic anti-cheat: server validates all inputs

### Phase 6 — Polish
- [ ] Champion animations (idle, run, attack, cast, death)
- [ ] Ability visual effects (projectiles, AOE indicators, hit sparks)
- [ ] Map art (proper terrain tiles instead of colored rectangles)
- [ ] Music and full sound design
- [ ] Settings menu (resolution, volume, keybinds)
- [ ] Ping display and basic netcode improvements

### Phase 7 — Game Feel
- [ ] Ability upgrade UI (click to level abilities during game)
- [ ] Death recap screen
- [ ] Post-game stats screen (kills/deaths/assists, damage dealt, gold earned)
- [ ] Spectator mode
- [ ] Replay system

---

## Architecture Notes

### Combat
Damage flows through `CombatSystem.deal_damage(source, target, amount, type)`. Physical damage uses `100 / (100 + armor)` reduction. Magic damage uses the same formula against MR. True damage bypasses both. All status effects are `StatusEffect` nodes added as children of the target — they self-remove after their duration and signal the parent.

### Networking
`NetworkManager` (autoload) wraps Godot's `MultiplayerAPI` (ENet UDP). The host is authoritative — clients send input RPCs, server applies them and broadcasts state. `--server` as a command-line argument starts a headless dedicated server. Port defaults to 7777.

### Adding a Champion
1. Create `scripts/champion/yourname/YourChampion.gd` extending `ChampionBase`
2. Set `class_name`, override `_ready()` for base stats and `_setup_abilities()` to attach Q/W/E/R
3. Create ability scripts extending `AbilitySystem`, implement `cast(target)`
4. Create `scenes/Champions/YourChampion.tscn` with `CharacterBody2D`, `CollisionShape2D`, `NavigationAgent2D`, `HealthBar`, `NameLabel`
5. Register the scene in `Main.gd`'s `CHAMPION_SCENES` dict and `ChampionSelect.gd`

---

## License

This is a fan project made for educational and personal use. All League of Legends IP (champion names, map names, ability names) belongs to Riot Games. This project is not affiliated with or endorsed by Riot Games.
