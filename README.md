# Out of Spec

Desktop (1920x1080, Steam/PC) chunky 3D voxel life-sim: satellite-linked remote farming/mining, indoor tarantula terrariums, satirical metrology. Godot 4.5, Forward+, GDScript.

## Run

Open `project.godot` in Godot 4.5 and press F5. Main scene: `scenes/main_farm.tscn`.

| Input | Action |
|---|---|
| WASD / arrows | Drive rover (through the uplink lag) |
| Space | Till the soil tile under the rover |
| R or ZERO STEERING button | Re-zero steering drift |

## Layout

```
scenes/          playable scenes
scripts/         GDScript (autoload/, rover/, world/, camera/, ui/)
ui/              UI scenes (field phone HUD)
data/            JSON game data, loaded by the DataManager autoload
scripts/metrology/  DriftModel: shared instrument drift + guard-band status
assets/voxels/   MagicaVoxel exports (Week 4)
docs/design/     concept blueprint and art bible (ignored by Godot via docs/.gdignore)
docs/decisions.md  design calls that shape code and data
```

## Data

`DataManager` loads each file in `data/` as-is. Arrays of `{ "id": ... }` objects are indexed by id (`get_record`, `get_records`); everything else is read by path (`get_value("instruments/hygrometer/max_permissible_error")`). Add new record sections to `RECORD_SECTIONS` in `scripts/autoload/DataManager.gd`.

Exporting: add `data/*.json` to Export > Resources > "Filters to export non-resource files".

## Vertical slice plan

1. Week 1: greybox rover, field-phone HUD, LOS-based uplink lag, steering drift, tilling
2. Week 2: one terrarium, sensor drift, bench zeroing, silk harvest
3. Week 3: day clock, morning dispatches, drop-pod, first audit
4. Week 4: MagicaVoxel models, lighting, one colonist
