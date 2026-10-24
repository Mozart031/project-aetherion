# Phase 20 — Godot simulation foundation

Project Aetherion is the technical repository for **Isla del Caos**.

## Current scaffold

- Godot 4.3+ main scene, 8 × 4 board, two 4 × 4 player territories.
- Fixed-step deterministic state updates at 20 Hz.
- Two hidden-core coordinates, provisional 12 HP per core.
- Esencia: start 4, maximum 8, +1 every 3 seconds.
- Six creature data definitions: boar, turtle, beaver, golem, rhino, pigeon.
- Summoning costs, one unit per cell, combat-only card recovery timers.
- Explicit adjacent attack commands, simultaneous damage application, attack cooldowns.
- Explicit core attacks and provisional match-end logic.
- Demo automatically summons boar and turtle and exchanges attacks.

## Important limitations

**This is an engine scaffold, not a complete playable game.** There is no unit movement/pathfinding, construction, terrains, disasters, Sol del Caos, deck interface, enemy AI, multiplayer, Android controls, scouting, core discovery, or volcano finale. Core attack commands currently require a unit to occupy the core cell; movement has not yet been implemented. The 10-minute timeout currently compares core HP only; complete tiebreakers are future work. No real-time multiplayer lockstep guarantee is claimed.

## How to run

1. Unzip the project and open `project.godot` in Godot 4.3 or newer.
2. Press **F6** in `scenes/main.tscn`, or **F5** to run the project.
3. Blue and orange circles represent opposing units. The demo resolves combat at 20 ticks/sec.
4. Optional headless smoke test: `godot --headless --path . --script res://tests/simulation_smoke.gd`.

## Next milestones

1. Deterministic command ordering and robust tests/replays.
2. Continuous movement and pathfinding over 32 terrain spaces.
3. Creature targeting and automatic defense.
4. Terrain destruction, combat locks, constructions and deck economy.
5. Android-friendly input and UI.
