# Out of Spec — Week 4: MagicaVoxel Asset Production Spec
**Engine:** Godot 4.7 | **Camera:** Orthographic 3/4 Isometric ($Y$-up, $30^\circ$ pitch, $45^\circ$ yaw, ~40m camera distance) | **Target Res:** 1920×1080  
**Rules:** High-contrast silhouettes, chunk size $\ge 2$ voxels for silhouette edges at range, strict telemetry palette coding.

---

## 1. Uplink Tractor (Rover) & Wide-Tread Variant

Small agricultural tractor converted for autonomous relay control via an oversized bolted sat-phone rack.

```
       [ANTENNA/BEACON]
            |
        +---+---+
       /   CAB   \
  +===+===========+
  |ENG|   [SAT]   |[HITCH]
  +===+===========+
 (WHL)             (WHL)
```

* **Footprint:**  
  * Standard: $16 \times 24 \times 14$ voxels ($W \times D \times H$)  
  * Bram’s Wide-Tread Variant: $20 \times 24 \times 14$ voxels (tread assemblies extend $+2$ voxels laterally on both sides).
* **Color Palette:**
  1. Primary Hull (Terracotta Ochre): `#C85A2A`
  2. Sub-frame / Chassis (Slate Shadow): `#1A1D24`
  3. Grille / Engine Block (Cold Steel): `#4D5663`
  4. Cab Glass (Smoked Cyan): `#4A7A82`
  5. Sat-Phone Unit (Industrial White): `#E2E8F0`
  6. Tire Rubber / Tracks (Dark Carbon): `#101216`
  7. Telemetry Beacon (In-Tolerance Teal): `#38E1C6` (Emissive)
  8. Warning / Status Light (Guard-Band Amber): `#F5A623` (Emissive)
  9. Exhaust / Fault LED (Out-of-Spec Red): `#FF5A5F` (Emissive)

### Hero 3/4 Isometric Description
* A stubby, nose-heavy tractor angled down-right. The front features a vertical $6 \times 4$ slatted radiator grille with two high-set round headlamps.
* Behind the short engine hood sits a ruggedized single-seat roll cage cab. An oversized beige sat-phone transponder unit is clamped to the cab roof with a trailing coiled thick wire.
* A vertical whip antenna with a cyan emitter point sticks out from the cab roof rear-right corner.
* **Standard:** Four chunky, deep-tread wheels (front diameter $6$, rear diameter $8$).
* **Wide Variant:** Rear wheels replaced by angular modular continuous-track units, jutting $2$ voxels wider on each side, with visible drive sprockets and mud scrapers.

---

### Orthographic Grid Blueprints (Standard: $16 \times 24 \times 14$)

#### Top View ($Z = 14$ down to $Z = 1$, Grid: $X=1..16, Y=1..24$)
```
Y\X 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16
01  .  .  .  . [G][G][G][G][G][G][G][G] .  .  .  .   <- Front Bumper/Grille
02  . [W][W] . [E][E][E][E][E][E][E][E] . [W][W] .   <- Front Wheels (W)
03  . [W][W] . [E][E][E][E][E][E][E][E] . [W][W] .      Engine Hood (E)
04  . [W][W] . [E][E][E][E][E][E][E][E] . [W][W] .
05  .  .  .  . [E][E][E][E][E][E][E][E] .  .  .  .
06  .  .  .  . [E][E][E][E][E][E][E][E] .  .  .  .
07  .  .  .  . [C][C][C][C][C][C][C][C] .  .  .  .   <- Cab Windshield Base
08  .  .  . [C][C][C][C][C][C][C][C][C][C] .  .  .
09  .  .  . [C][C][S][S][S][S][S][S][C][C] .  .  .   <- Roof / Sat-Phone (S)
10  .  .  . [C][C][S][S][S][S][S][S][C][C] .  .  .
11  .  .  . [C][C][S][S][S][S][S][S][C][C] .  .  .
12  .  .  . [C][C][S][S][A][A][S][S][C][C] .  .  .   <- Antenna Mount (A)
13  .  .  . [C][C][C][C][C][C][C][C][C][C] .  .  .
14  . [T][T][T] . [B][B][B][B][B][B] . [T][T][T] .   <- Rear Wheels/Treads (T)
15  . [T][T][T] . [B][B][B][B][B][B] . [T][T][T] .      Rear Bed/Hitch (B)
16  . [T][T][T] . [B][B][B][B][B][B] . [T][T][T] .
17  . [T][T][T] . [B][B][B][B][B][B] . [T][T][T] .
18  . [T][T][T] . [B][B][B][B][B][B] . [T][T][T] .
19  . [T][T][T] . [B][B][B][B][B][B] . [T][T][T] .
20  .  .  .  .  . [H][H][H][H][H][H] .  .  .  .  .   <- Hitch Assembly
```
*(Bram's Wide Variant: columns 01-03 and 14-16 for $Y=14..19$ expand out to $X=-1..03$ and $X=14..18$, shifting track width from 3 to 5 voxels).*

#### Side View (Port-Side, looking from $+X$, $Y=1..24, Z=1..14$)
```
Z\Y 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20
14  .  .  .  .  .  .  .  .  .  .  . [A] .  .  .  .  .  .  .  .  <- Antenna Tip (Teal)
13  .  .  .  .  .  .  .  .  .  .  . [A] .  .  .  .  .  .  .  .
12  .  .  .  .  .  .  .  . [S][S][S][S] .  .  .  .  .  .  .  .  <- Sat-Phone on roof
11  .  .  .  .  .  .  . [C][C][C][C][C][C] .  .  .  .  .  .  .  <- Cab Roof
10  .  .  .  .  .  . [G][G][G][G][G][G][C] .  .  .  .  .  .  .  <- Cab Windows
09  .  .  .  .  .  . [G][G][G][G][G][G][C] .  .  .  .  .  .  .
08  .  .  .  .  .  . [C][C][C][C][C][C][C][B][B][B][B][B] .  .  <- Cowl / Rear Bed
07  . [E][E][E][E][E][E][C][C][C][C][C][C][B][B][B][B][B][H] .  <- Engine Hood
06  . [E][E][E][E][E][E][C][C][C][C][C][C][T][T][T][T][T][T] .  <- Rear Tire/Tread
05  . [W][W][W] .  .  . [K][K][K][K][K][K][T][T][T][T][T][T] .  <- Frame/Rocker (K)
04  [W][W][W][W][W] .  . [K][K][K][K][K][K][T][T][T][T][T][T] .
03  [W][W][W][W][W] .  .  .  .  .  .  .  . [T][T][T][T][T][T] .
02  [W][W][W][W][W] .  .  .  .  .  .  .  . [T][T][T][T][T][T] .
01  . [W][W][W] .  .  .  .  .  .  .  .  .  . [T][T][T][T][T] .  <- Ground Line
```

#### Front View (Facing Nose, looking from $-Y$, $X=1..16, Z=1..14$)
```
Z\X 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16
14  .  .  .  .  .  .  .  .  .  . [A] .  .  .  .  .  <- Antenna beacon
13  .  .  .  .  .  .  .  .  .  . [A] .  .  .  .  .
12  .  .  .  .  . [S][S][S][S][S][S] .  .  .  .  .  <- Sat receiver box
11  .  .  .  . [C][C][C][C][C][C][C][C] .  .  .  .  <- Cab roof frame
10  .  .  .  . [C][G][G][G][G][G][G][C] .  .  .  .  <- Windshield
09  .  .  .  . [C][G][G][G][G][G][G][C] .  .  .  .
08  .  .  .  . [H][E][E][E][E][E][E][H] .  .  .  .  <- Headlights (H) / Hood (E)
07  .  .  .  . [E][R][R][R][R][R][R][E] .  .  .  .  <- Grille slats (R)
06  . [W][W] . [E][R][R][R][R][R][R][E] . [W][W] .  <- Front tires flank hood
05  [W][W][W] . [K][K][K][K][K][K][K][K] . [W][W][W]
04  [W][W][W] . [K][K][K][K][K][K][K][K] . [W][W][W]
03  [W][W][W] .  . [F][F][F][F][F][F] .  . [W][W][W] <- Front Axle (F)
02  [W][W][W] .  .  .  .  .  .  .  .  .  . [W][W][W]
01  . [W][W] .  .  .  .  .  .  .  .  .  .  . [W][W] .
```

* **Emissive Voxels:**
  * Sat-phone Link Tip: `X=11, Y=12, Z=14` (`#38E1C6`)
  * Sat-phone Mode Display: `X=08..09, Y=09, Z=12` (`#F5A623`)
  * Front Headlamps: `X=05, Y=01, Z=08` & `X=12, Y=01, Z=08` (`#F5A623`)
  * Rear Hitch Telemetry Plug: `X=08, Y=20, Z=07` (`#FF5A5F`)

---

## 2. Terrarium with Curlyhair Tarantula (*Tliltocatl albopilosus*)

Enclosed environmental glass container resting on an industrial workstation corner.

```
         [HEAT LAMP]
             \
        +-----------+
        |   GLASS   |
        |  (SPIDER) |
        | [SUBSTRATE|
        +-----------+
          [HYGRO:LED]
```

* **Footprint:** $14 \times 14 \times 16$ voxels ($W \times D \times H$)
* **Color Palette:**
  1. Base Substrate (Coco Peat Brown): `#3A2312`
  2. Substrate Accent (Dry Soil): `#543821`
  3. Tarantula Body (Velvet Black-Brown): `#1E1714`
  4. Bristle Tips (Pale Curly Gold): `#E5BE79`
  5. Cork Bark Hide (Weathered Bark): `#634E3A`
  6. Terrarium Frame (Matte Charcoal): `#1E2229`
  7. Glass Panes (Translucent Ice Teal, 20% Alpha in Godot): `#95D5D9`
  8. Heat Lamp Hood (Spun Brass): `#9E7D3B`
  9. Heat Lamp Element (Incandescent Glow): `#FFA53B` (Emissive)
  10. Hygrometer Pod (Plastic Off-White): `#D4D9DE`
  11. Hygrometer Readout LED (In-Tolerance Teal): `#38E1C6` (Emissive)

### Hero 3/4 Isometric Description
* A clean glass cuboid with black structural corner posts. Inside, a sloped bed of dark soil rises towards the rear-left.
* A tilted, curved slab of hollow cork bark sits in the back corner.
* Front-center sits the *T. albopilosus*: a thick $3 \times 4$ oval abdomen and $2 \times 2$ cephalothorax, with 8 sprawling legs featuring distinct gold-voxel highlights on the tips and joints.
* Clipped to the front-right upper glass edge is a $2 \times 3$ sensor pod (hygrometer) with a bright `#38E1C6` status light.
* A gooseneck clamp light overhangs the mesh top from the rear-right, bathing the substrate below in warm amber-yellow light.

---

### Orthographic Grid Blueprints ($14 \times 14 \times 16$)

#### Top View ($Z = 16$ through internal $Z = 3$)
```
Y\X 01 02 03 04 05 06 07 08 09 10 11 12 13 14
01  [F][F][F][F][F][F][F][F][F][F][F][F][F][F]   <- Rear Frame Post
02  [F] .  . [L][L][L] .  .  .  .  .  .  .  [F]   <- Heat Lamp fixture at Z=15..16 (L)
03  [F] .  [K][K][K] .  .  .  .  .  .  .  . [F]   <- Cork Bark Hide (K)
04  [F] . [K][K][K][K] .  .  .  .  .  .  .  [F]
05  [F] . [K][K] .  .  .  .  .  .  .  .  .  [F]
06  [F] .  .  .  . [A][A] .  .  .  .  .  .  [F]   <- Tarantula Abdomen (A)
07  [F] .  . [t] . [A][A][A] . [t] .  .  .  [F]   <- Gold-tipped hairs (t)
08  [F] . [p] .  . [T][T] .  .  . [p] .  .  [F]   <- Prosoma/Cephalothorax (T), Legs (p)
09  [F] .  . [p] [c][c] [p] .  .  .  .  .  [F]   <- Chelicerae (c)
10  [F] .  .  .  .  .  .  .  .  .  .  .  .  [F]
11  [F] . [D][D] .  .  .  .  .  .  .  .  .  [F]   <- Water Dish (D)
12  [F] . [D][D] .  .  .  .  .  .  .  .  .  [F]
13  [F] .  .  .  .  .  .  .  .  .  . [H][H] [F]   <- Clipped Hygrometer (H)
14  [F][F][F][F][F][F][F][F][F][F][F][F][F][F]   <- Front Frame
```

#### Side View (Right Side, looking from $+X$, $Y=1..14, Z=1..16$)
```
Z\Y 01 02 03 04 05 06 07 08 09 10 11 12 13 14
16  .  . [L][L][L] .  .  .  .  .  .  .  .  .  <- Lamp dome
15  .  . [L][L][L] .  .  .  .  .  .  .  .  .
14  [F][F][F][F][F][F][F][F][F][F][F][F][F][F] <- Top Mesh Frame
13  [F] .  .  .  .  .  .  .  .  .  .  . [H][F] <- Hygrometer Body
12  [F] .  .  .  .  .  .  .  .  .  .  . [E][F] <- Hygrometer LED (E = Teal)
11  [G] .  .  .  .  .  .  .  .  .  .  .  . [G] <- Glass Panes (G)
10  [G] .  .  .  .  .  .  .  .  .  .  .  . [G]
09  [G] .  .  .  .  .  .  .  .  .  .  .  . [G]
08  [G] .  .  .  .  .  .  .  .  .  .  .  . [G]
07  [G] [K][K] .  .  .  .  .  .  .  .  .  . [G] <- Bark hide elevation
06  [G] [K][K][K] .  .  .  .  .  .  .  .  . [G]
05  [G] [S][K][K][K][p] .  .  .  .  .  .  . [G] <- Spider leg arch
04  [G] [S][S][S][S][A][T][c] .  .  .  .  . [G] <- Spider profile
03  [S][S][S][S][S][S][S][S][S][S][S][S][S][S] <- Substrate line (S)
02  [S][S][S][S][S][S][S][S][S][S][S][S][S][S]
01  [F][F][F][F][F][F][F][F][F][F][F][F][F][F] <- Bottom Rim Frame
```

* **Emissive Voxels:**
  * Heat Lamp Filament: `X=03..05, Y=02..04, Z=14` (`#FFA53B`)
  * Hygrometer LED: `X=12, Y=13, Z=12` (`#38E1C6`)

---

## 3. Bram (Mechanic) & Scrapyard Maintenance Bay

Industrial diorama segment: open C-channel steel frame with a tire rack, dirty work surface, and Bram striking an axle.

```
   +===[I-BEAM ROOF FRAME]===+
   | [TOOL RACK]             |
   | [TIRE STACK]    (BRAM)  |
   |                  \O/    |
   |  [CHEST]          |     |
  #+==================/=\====+#
```

* **Footprint:** $24 \times 20 \times 18$ voxels ($W \times D \times H$)  
  *(Bram Character Footprint: $6 \times 5 \times 10$ voxels)*
* **Color Palette:**
  1. Structural I-Beams (Oxidized Iron): `#383C45`
  2. Concrete Floor Slab (Stained Gray): `#5C6067`
  3. Oil Stains (Slick Pitch): `#1B1D21`
  4. Tool Wall Pegboard (Industrial Tan): `#8B7D6B`
  5. Overalls / Canvas (Grease-Stained Ochre): `#7C623E`
  6. Undershirt (Muted Teal): `#2E6865`
  7. Bram Skin (Sunburnt / Smudged Peach): `#C98869`
  8. Bram Hair / Beard (Unkempt Steel): `#5E5855`
  9. Sledgehammer / Heavy Tools (Tool Steel): `#8C96A6`
  10. Warning Striping / Tag (Guard Amber): `#F5A623` (Emissive)
  11. Worksite Trouble Light (Incandescent Amber): `#FFA726` (Emissive)
  12. Blown Fuse / Error Marker (Out-of-Spec Red): `#FF5A5F` (Emissive)

### Hero 3/4 Isometric Description
* A structural corner of an open garage bay made of chunky dark I-beams running along the back ($-Y$) and left ($-X$) walls, supporting an open roof girder.
* In the left corner ($X=2..8, Y=2..8$), three huge rover tires are stacked haphazardly on their sides, with a metal breaker bar leaning against them.
* Along the back wall hangs a tool rack with dangling open-ended wrenches and a battery charger with a glowing red diagnostic indicator.
* Bram stands in the center-right ($X=14..19, Y=10..14$) mid-swing: torso twisted, boots planted wide, gripping a two-handed sledgehammer raised above a bent suspension arm clamped in a floor vise.
* A caged incandescent trouble light hangs low from the upper ceiling beam, casting long dramatic shadows towards the viewer.

---

### Orthographic Grid Blueprints ($24 \times 20 \times 18$)

#### Top View (Floor Layout: $Z = 1$ to intermediate heights)
```
Y\X 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
01  [C][B][B][B][B][B][B][B][B][B][B][B][B][B][B][B][B][B][B][B][B][B][B][C] <- Back Wall Beam
02  [B] . [W][W][W][W][W][W] .  . [D][D][D][D] .  .  .  .  .  .  .  .  .  [B] <- W=Wall Tools
03  [B] [T][T][T][T] .  .  .  .  . [D][D][D][D] .  .  .  .  .  .  .  .  .  [B] <- D=Work Bench
04  [B] [T][T][T][T][T] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  [B] <- T=Tire Stack
05  [B] [T][T][T][T][T] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
06  [B] [T][T][T][T] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
07  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
08  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
09  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
10  [B] .  .  .  .  .  .  .  .  .  .  .  .  . [m] .  . [m] .  .  .  .  .  .  <- Bram's Boots (m)
11  [B] .  .  .  .  .  .  .  .  .  .  .  . [m][m] .  . [m][m] .  .  .  .  .
12  [B] .  .  .  .  .  .  .  .  .  . [V] .  .  .  .  .  .  .  .  .  .  .  .  <- Floor Vise (V)
13  [B] .  .  .  .  .  .  .  .  .  . [V][V] .  .  .  .  .  .  .  .  .  .  .
14  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
15  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
16  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
17  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
18  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
19  [B] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
20  [C] .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  <- Front Corner Post
```

#### Bram Character Breakdown (Front View, Sub-Grid $6 \times 10$)
```
Z\X 01 02 03 04 05 06
10  . [H][H][H][H] .     H = Hair/Head (Grey/Skin)
09  . [H][S][S][H] .     S = Skin Face
08  . [B][B][B][B] .     B = Bushy Beard
07  [U][O][O][O][O][U]   O = Overalls, U = Upper Arms (bare/stained)
06  [U][O][O][O][O][U]
05  .  [O][O][O][O] .     Tool Belt at Z=05 (Leather/Amber buckle)
04  .  [L][L][L][L] .     Legs / Overalls (L)
03  .  [L][L][L][L] .
02  .  [M][M] . [M][M]   M = Heavy Muddy Boots
01  .  [M][M] . [M][M]
```
*(Sledgehammer extends from hands at $Z=07$ diagonally up to $Z=12$ with a $2 \times 3 \times 2$ steel block head).*

* **Emissive Voxels:**
  * Hanging Cage Trouble Light: `X=12, Y=10, Z=15` (`#FFA726`)
  * Battery Charger Failure Light: `X=06, Y=02, Z=08` (`#FF5A5F`)
  * Work Bench Calibration Strip: `X=10..13, Y=02, Z=06` (`#F5A623`)

---

## 4. Crystal Ore Fissure on the Terracotta Plateau

Geological crevasse exposing raw crystalline energy shards against weathered planar red rock.

```
       ,,~
     //   \\   [CYAN CRYSTALS]
 ___//     \\____   /
(___  /\_/\  ____) /
    \/     \/
 [TERRACOTTA GROUND]
```

* **Footprint:** $8 \times 8 \times 6$ voxels ($W \times D \times H$)
* **Color Palette:**
  1. Terracotta Crust (Oxidized Red Rock): `#A24328`
  2. Mesa Top Shading (Eroded Sandstone): `#BD5D3F`
  3. Crevasse Shadow (Deep Basalt): `#201214`
  4. Core Crystal Cluster (In-Tolerance Teal): `#38E1C6` (Emissive)
  5. Crystal Highlights (Bright Telemetry Cyan): `#8BFFF0` (Emissive)
  6. Sub-surface Crystal Base (Deep Cyan/Mineral): `#1D7373`

### Hero 3/4 Isometric Description
* A modular, stackable ground slab. The top surface sits at $Z=4..5$, broken by a jagged diagonal fracture running from $(X=1, Y=3)$ across to $(X=8, Y=6)$.
* The fissure dips two levels down into dark basalt rock.
* Sharp, asymmetrical geometric prisms of cyan crystal burst upward out of the trench at roughly $45^\circ$ angles, rising above ground level to $Z=6$.
* High-contrast specular planes: the flat red-orange clay strata contrast against the luminescent crystal formations.

---

### Orthographic Grid Blueprints ($8 \times 8 \times 6$)

#### Top View (Surface Elevation & Fissure Chasm)
```
Y\X 01 02 03 04 05 06 07 08
01  [R][R][R][R][R][R][R][R]   R = Red Plateau Surface (Z=4)
02  [R][R][R][R][R][R][R][R]   F = Dark Fissure Trench (Z=1..2)
03  [F][F][R][R][R][R][R][R]   C = Cyan Crystal Spike (Z=3..6)
04  [C][F][F][F][R][R][R][R]
05  .  [C][C][F][F][F][R][R]
06  .  .  [F][C][C][F][F][F]
07  .  .  .  [F][F][C][C][F]
08  .  .  .  .  [F][F][F][F]
```

#### Side View (Looking from $-X$, $Y=1..8, Z=1..6$)
```
Z\Y 01 02 03 04 05 06 07 08
06  .  .  .  . [C] .  .  .   <- Tallest crystal pinnacle
05  .  .  . [C][C][C] .  .   <- Crystal structures breaking surface
04  [R][R][R][R][C][C][R][R] <- Terracotta ground plane
03  [R][R][F][F][B][B][F][F] <- Fissure throat (B = Base mineral)
02  [K][K][K][K][K][K][K][K] <- Sub-rock strata (K)
01  [K][K][K][K][K][K][K][K] <- Diorama Base
```

* **Emissive Voxels:**
  * Primary Crystal Spire: `X=05, Y=05, Z=04..06` (`#8BFFF0`)
  * Secondary Crystal Cluster: `X=04, Y=06, Z=03..05` (`#38E1C6`)
  * Deep Trench Fissure Glow: `X=02, Y=04, Z=02` (`#38E1C6`)

---

## 5. MegaCorp Drop-Pod & AUD-1T Drone

A heavy atmospheric insertion pod beside its deployed spherical/cubic compliance auditor drone.

```
       / \
      /CON\       [AUD-1T]
     /=====\       +-----+
    |       |      | (O) |
    | [HUD] |      +--v--+
    |       |
    +=======+
     / / \ \  [RETRO JETS]
```

* **Footprint:**  
  * Drop-Pod: $16 \times 16 \times 22$ voxels ($W \times D \times H$)  
  * AUD-1T Drone: $6 \times 6 \times 6$ voxels (hovering at $Z=8..13$ alongside)
* **Color Palette:**
  1. Pod Primary Hull (MegaCorp Industrial Orange): `#E65100`
  2. Hull Chamfer/Accents (Deep Industrial Amber): `#BF360C`
  3. Drone Shell / Hull Markings (Sanitary White): `#ECEFF1`
  4. Drone Dark Trim (Slate Gunmetal): `#263238`
  5. Heat Shield / Retro Skirt (Burnt Carbon): `#181A1B`
  6. Compliance Scanner Eye (Guard Amber): `#F5A623` (Emissive)
  7. Airlock Seal / Hatch Status (Out-of-Spec Red): `#FF5A5F` (Emissive)
  8. Pod Telemetry Beacon (In-Tolerance Teal): `#38E1C6` (Emissive)
  9. Thruster Glow (Superheated Plasma): `#FFD54F` (Emissive)

### Hero 3/4 Isometric Description
* **Drop-Pod:** A monumental octagonal pyramid-cone hybrid. The lower half is a vertical prism; the upper half tapers smoothly to a blunt nose cone capped with a teal communications uplink.
* One facet carries an amber-illuminated airlock hatch flanked by vertical red warning borders. Retro-rocket thruster bells extend from the scorched black base skirt.
* **AUD-1T Drone:** Hovering at mid-height next to the pod. It is a clean white $6 \times 6 \times 6$ cube with 45-degree corner bevels.
* The center features an oversized, recessed $2 \times 2$ single amber eye lens staring outward, casting an ominous directional surveillance cone. Two tiny bottom micro-thrusters emit faint orange trails.

---

### Orthographic Grid Blueprints

#### Drop-Pod: Top View ($X=1..16, Y=1..16$ at pod midpoint $Z=10$)
```
Y\X 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16
01  .  .  .  .  [H][H][H][H][H][H][H][H] .  .  .  .
02  .  .  [H][H][H][H][H][H][H][H][H][H][H][H] .  .
03  .  [H][H] .  .  .  .  .  .  .  .  .  . [H][H] .
04  .  [H] .  .  .  .  .  .  .  .  .  .  .  .  [H] .
05  [H][H] .  .  .  .  .  .  .  .  .  .  .  . [H][H]
06  [H] .  .  .  .  .  .  .  .  .  .  .  .  .  .  [H]
07  [H] .  .  .  .  .  .  .  .  .  .  .  .  .  .  [H]
08  [H] .  .  .  .  .  .  .  .  .  .  .  .  .  .  [H]
09  [H] .  .  .  .  .  .  .  .  .  .  .  .  .  .  [H]
10  [H] .  .  .  .  .  .  .  .  .  .  .  .  .  .  [H]
11  [H] .  .  .  .  .  .  .  .  .  .  .  .  .  .  [H]
12  [H][H] .  .  .  .  .  .  .  .  .  .  .  . [H][H]
13  .  [H] .  .  .  .  .  .  .  .  .  .  .  .  [H] .
14  .  [H][H] .  . [D][D][D][D][D][D] .  . [H][H] . <- Airlock Door (D)
05  .  .  [H][H][H][D][D][D][D][D][D][H][H][H] .  .
16  .  .  .  .  [H][H][H][H][H][H][H][H] .  .  .  .
```

#### Drop-Pod: Front View (Facing Airlock Door, $X=1..16, Z=1..22$)
```
Z\X 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16
22  .  .  .  .  .  .  . [T][T] .  .  .  .  .  .  . <- Teal Uplink Beacon
21  .  .  .  .  .  .  [P][P][P][P] .  .  .  .  .  . <- Cone Apex
20  .  .  .  .  .  [P][P][P][P][P][P] .  .  .  .  .
19  .  .  .  .  .  [P][P][P][P][P][P] .  .  .  .  .
18  .  .  .  .  [P][P][P][P][P][P][P][P] .  .  .  .
17  .  .  .  .  [P][P][P][P][P][P][P][P] .  .  .  .
16  .  .  .  [P][P][P][P][P][P][P][P][P][P] .  .  .
15  .  .  .  [P][P][P][P][P][P][P][P][P][P] .  .  .
14  .  .  [P][P][P][P][P][P][P][P][P][P][P][P] .  .
13  .  [P][P][P][P][P][P][P][P][P][P][P][P][P][P] .
12  [P][P][P][P][P][P][P][P][P][P][P][P][P][P][P][P]
11  [P][P][P] [W][D][D][D][D][D][D][W] [P][P][P] <- W = Warning Red border
10  [P][P][P] [W][D][D][A][A][D][D][W] [P][P][P] <- A = Amber Hatch Seal
09  [P][P][P] [W][D][D][A][A][D][D][W] [P][P][P]
08  [P][P][P] [W][D][D][D][D][D][D][W] [P][P][P]
07  [P][P][P] [W][D][D][D][D][D][D][W] [P][P][P]
06  [P][P][P][P][P][P][P][P][P][P][P][P][P][P][P][P]
05  [S][S][S][S][S][S][S][S][S][S][S][S][S][S][S][S] <- Scorched Skirt (S)
04  [S][S][S][S][S][S][S][S][S][S][S][S][S][S][S][S]
03  . [J][J] .  . [J][J] .  . [J][J] .  . [J][J] .   <- Jet Thruster Bells (J)
02  . [J][J] .  . [J][J] .  . [J][J] .  . [J][J] .
01  . [G][G] .  . [G][G] .  . [G][G] .  . [G][G] .   <- Plasma Glow
```

#### AUD-1T Drone Breakdown ($6 \times 6 \times 6$, Front View)
```
Z\X 01 02 03 04 05 06
06  . [W][W][W][W] .     W = Sanitary White Chassis
05  [W][W][W][W][W][W]
04  [W][W][E][E][W][W]   E = Scanner Eye (Amber Emissive)
03  [W][W][E][E][W][W]
02  [W][W][W][W][W][W]
01  . [J] .  . [J] .     J = Micro Thruster
```

* **Emissive Voxels:**
  * Drop-Pod Nose Telemetry Tip: `X=08..09, Y=08..09, Z=22` (`#38E1C6`)
  * Hatch Status Frame: `X=07..10, Y=15, Z=09..10` (`#F5A623`)
  * Hatch Lock Integrity Failures: `X=04, Y=15, Z=07..11` (`#FF5A5F`)
  * AUD-1T Scanner Lens: `X=03..04, Y=01, Z=03..04` (`#F5A623`)
  * AUD-1T Thruster Plumes: `X=02, Y=03, Z=01` & `X=05, Y=03, Z=01` (`#FFD54F`)

---

## 6. Satellite Relay Mast with Optical Silk Spool

Tall triangular structural lattice tower with steerable telemetry dish, apex cyan beacon, and an accessible field service spool bay.

```
            /O\    [CYAN BEACON]
             |
           // \\   [PARABOLIC DISH]
          //===\\
         //  |  \\
        || [SPOOL]||
        #+===+===+#
```

* **Footprint:** $18 \times 18 \times 32$ voxels ($W \times D \times H$)
* **Color Palette:**
  1. Mast Structural Lattice (Galvanized Steel): `#5A6372`
  2. Mast Footing / Piers (Anchor Concrete): `#30343D`
  3. Parabolic Dish Face (Off-White Coating): `#D8DEE9`
  4. Feed Horn & Struts (Anodized Dark Gray): `#2E3440`
  5. Spool Flange (Hazard Amber): `#F5A623`
  6. Optical Silk Fiber Core (Glow Filament Teal): `#38E1C6` (Emissive)
  7. Apex Beacon (High-Yield Cyan): `#6DFCE6` (Emissive)
  8. Diagnostic Monitor (Out-of-Spec Red): `#FF5A5F` (Emissive)
  9. Cable Conduit (Heavy Black Rubber): `#1A1C20`

### Hero 3/4 Isometric Description
* A soaring triangular mast tapering gracefully from an $18 \times 18$ three-point footing at the base up to a narrow $4 \times 4$ neck at $Z=24$.
* Mounted at $Z=25$ is a directional dish (diameter $10$, tilted $45^\circ$ toward the top-right isometric axis).
* Surmounting the dish is a spire carrying a flashing `#6DFCE6` beacon readable from max zoom.
* At the base between two legs ($X=4..10, Y=2..6, Z=2..7$) sits an integrated open maintenance alcove. Inside, an industrial spool feeds glowing translucent teal optical silk thread upward through guide rings along the tower leg.

---

### Orthographic Grid Blueprints ($18 \times 18 \times 32$)

#### Top View (Overall Profile showing Dish & Base Footing)
```
Y\X 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18
01  .  .  .  .  .  .  .  [P][P][P][P] .  .  .  .  .  .  .  <- Rear Base Pier (P)
02  .  .  .  .  .  .  .  [P][P][P][P] .  .  .  .  .  .  .
03  .  .  .  .  .  .  .  .  [L][L] .  .  .  .  .  .  .  .  <- Lattice Leg (L)
04  .  .  .  .  .  .  .  .  [L][L] .  .  .  .  .  .  .  .
05  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
06  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
07  .  .  .  .  .  .  [D][D][D][D][D][D] .  .  .  .  .  .  <- Dish Perimeter (D)
08  .  .  .  .  .  [D][D][D][D][D][D][D][D] .  .  .  .  .
09  .  .  .  .  [D][D][D][D][F][F][D][D][D][D] .  .  .  .  <- Feed Horn (F)
10  .  .  .  .  [D][D][D][D][F][F][D][D][D][D] .  .  .  .
11  .  .  .  .  .  [D][D][D][D][D][D][D][D] .  .  .  .  .
12  .  .  .  .  .  .  [D][D][D][D][D][D] .  .  .  .  .  .
13  .  .  [L][L] .  .  .  .  .  .  .  .  .  . [L][L] .  .
14  .  .  [L][L] .  .  .  .  .  .  .  .  .  . [L][L] .  .
15  .  [P][P][P][P] . [S][S][S][S][S][S] . [P][P][P][P] .  <- S = Optical Silk Spool Bay
16  .  [P][P][P][P] . [S][O][O][O][O][S] . [P][P][P][P] .  <- O = Silk Thread Spool Core
17  .  [P][P][P][P] . [S][S][S][S][S][S] . [P][P][P][P] .
18  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
```

#### Side View (Looking from $-X$, $Y=1..18, Z=1..32$)
```
Z\Y 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18
32  .  .  .  .  .  .  .  .  [B][B] .  .  .  .  .  .  .  .  <- Apex Beacon (B)
31  .  .  .  .  .  .  .  .  [M][M] .  .  .  .  .  .  .  .  <- Spire Mast (M)
30  .  .  .  .  .  .  .  .  [M][M] .  .  .  .  .  .  .  .
29  .  .  .  .  .  .  .  .  [M][M] [F] .  .  .  .  .  .  .  <- Feed Horn cantilever
28  .  .  .  .  .  .  [D] .  [M][M] .  .  .  .  .  .  .  .  <- Dish top edge (D)
27  .  .  .  .  .  .  . [D] [M][M] .  .  .  .  .  .  .  .
26  .  .  .  .  .  .  .  . [D][M][M] .  .  .  .  .  .  .  .
25  .  .  .  .  .  .  .  .  . [D][M] .  .  .  .  .  .  .  .  <- Dish mount pivot
24  .  .  .  .  .  .  .  .  [L][L][L] .  .  .  .  .  .  .  <- Lattice converges
23  .  .  .  .  .  .  .  . [L] .  . [L] .  .  .  .  .  .  <- Strut X-brace
22  .  .  .  .  .  .  . [L] .  .  .  . [L] .  .  .  .  .
21  .  .  .  .  .  .  . [L] .  .  .  . [L] .  .  .  .  .
20  .  .  .  .  .  . [L] .  .  .  .  .  . [L] .  .  .  .
..  .  .  .  .  .  . [L] .  .  .  .  .  . [L] .  .  .  .
10  .  .  .  . [L] .  .  .  .  .  .  .  .  .  . [L] .  .
09  .  .  .  . [L] .  .  .  .  .  .  .  .  .  . [L] .  .
08  .  .  . [L] .  .  .  .  .  .  .  .  .  .  .  . [L] .
07  .  .  . [L] .  .  .  .  .  .  .  .  . [S][S][S][L] .  <- Top of Spool Bay (S)
06  .  . [L] .  .  .  .  .  .  .  .  .  . [S][O][O][S] .  <- Glowing Silk (O)
05  .  . [L] .  .  .  .  .  .  .  .  .  . [S][O][O][S] .
04  .  [L] .  .  .  .  .  .  .  .  .  .  . [S][S][S][S] .
03  .  [L] .  .  .  .  .  .  .  .  .  .  . [P][P][P][P] .
02  [P][P][P] .  .  .  .  .  .  .  .  .  . [P][P][P][P] .  <- Footing Pier (P)
01  [P][P][P] .  .  .  .  .  .  .  .  .  . [P][P][P][P] .
```

* **Emissive Voxels:**
  * Mast Top Beacon: `X=09..10, Y=09..10, Z=32` (`#6DFCE6`)
  * Optical Silk Spool Core: `X=08..11, Y=16, Z=05..06` (`#38E1C6`)
  * Spool Bay Terminal Diagnostic LED: `X=06, Y=15, Z=07` (`#FF5A5F`)
  * Dish Feed Horn Data Flange: `X=09..10, Y=10, Z=29` (`#F5A623`)

---

## 7. MagicaVoxel Palette Import Index

To map this asset sheet directly to a single 256-color MagicaVoxel palette, assign the core colors to the following palette slots:

| Slot | Hex Code | Role | Material Type | Emit / Power |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `#38E1C6` | In-Tolerance Teal | Emit | Power: `50`, Flux: `2.5` |
| **02** | `#6DFCE6` | Telemetry Cyan (Outdoor) | Emit | Power: `80`, Flux: `4.0` |
| **03** | `#F5A623` | Guard-Band Amber | Emit | Power: `40`, Flux: `2.0` |
| **04** | `#FFA726` | Warm Indoor Light | Emit | Power: `60`, Flux: `3.0` |
| **05** | `#FF5A5F` | Out-of-Spec Red | Emit | Power: `45`, Flux: `2.2` |
| **06** | `#1A1D24` | Slate Shadow (Chassis/Frame) | Diffuse | Rough: `0.8`, Metal: `0.1` |
| **07** | `#C85A2A` | Terracotta Ochre (Rover Hull)| Diffuse | Rough: `0.7`, Metal: `0.0` |
| **08** | `#E65100` | MegaCorp Orange (Drop-Pod) | Diffuse | Rough: `0.4`, Metal: `0.1` |
| **09** | `#A24328` | Terracotta Crust (Rock) | Diffuse | Rough: `0.9`, Metal: `0.0` |
| **10** | `#ECEFF1` | Clean Sanitary White (AUD-1T) | Diffuse | Rough: `0.2`, Metal: `0.0` |
| **11** | `#4D5663` | Cold Steel / Machinery | Metal | Rough: `0.3`, Metal: `0.8` |
| **12** | `#95D5D9` | Terrarium Panes | Glass | Alpha: `0.2`, Refract: `1.3` |
| **13** | `#3A2312` | Coco Peat / Wet Substrate | Diffuse | Rough: `1.0`, Metal: `0.0` |
| **14** | `#1E1714` | Tarantula Velvet Carapace | Diffuse | Rough: `0.9`, Metal: `0.0` |
| **15** | `#E5BE79` | Curly Gold Bristle Tips | Diffuse | Rough: `0.6`, Metal: `0.1` |
| **16** | `#101216` | Tread Rubber / Carbon Black | Diffuse | Rough: `0.9`, Metal: `0.0` |