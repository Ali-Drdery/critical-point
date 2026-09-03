# Critical Point

A 2D narrative game built in **Godot 4.7.1** for a 4-day game jam.

The game follows a young man's struggle to overcome addiction (never named
explicitly — represented visually as chains that keep pulling him back).
The character grows from child to young adult across repeated attempts to
reach a door that represents freedom. A single night is split into five
stages, each ending at an Adhan checkpoint (Istighfar, Temptation, Boredom,
Distractions, Night Routine), followed by a final battle against the
*qarin* (inner voice), and — if you win — an escape through the door.

## Gameplay

- 3 shared lives across the whole night; losing all 3 ends the run
- Each stage has its own countdown to its Adhan checkpoint — finish early
  and time skips ahead, run out of time and you still hit Adhan, but it
  counts as a loss for that stage
- Three possible endings: **Game Over** (out of lives), **Bad Ending**
  (lost the qarin battle), **Good Ending — "FREE"** (qarin defeated, door
  reached)

## Project structure

- `main.tscn` / `main.gd` — drives the whole room: background, the five
  stage triggers (placed geographically, not random), ladder, qarin-battle
  trigger, and the door (only appears once the qarin is defeated)
- `player.tscn` / `player.gd` — `CharacterBody2D` movement, camera limits,
  climbing
- `stage_base.gd` — shared base class for the five challenge stages
- `istighfar_stage.gd`, `temptation_stage.gd`, `boredom_stage.gd`,
  `distraction_stage.gd`, `night_routine_stage.gd` — the individual stage
  challenges
- `qarin_stage.gd` — the final inner-voice battle
- `intro_cutscene.tscn` / `intro_cutscene.gd` — the opening cutscene
- `main_menu.tscn` / `main_menu.gd` — main menu
- `audio_manager.gd` — central audio/SFX/voice playback and mixing
- `chain_trail.gd` — the chain-pull visual effect

## Opening the project

1. Install [Godot 4.7.1](https://godotengine.org/download).
2. Clone this repo.
3. Open Godot, choose **Import**, and select the `project.godot` file in
   the cloned folder.

## Credits

Built for a game jam. Uses third-party art/audio packs (character and
demon spritesheets, UI assets, sound effects) — see individual asset
folders for sources.
