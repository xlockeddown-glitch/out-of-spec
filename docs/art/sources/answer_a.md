### GLOBAL PRODUCTION RULES & GODOT 4.7 IMPORT SPEC

* **Coordinate System:** 
  * $X = \text{Width (Left/Right)}$
  * $Y = \text{Depth (Front/Back)}$
  * $Z = \text{Height (Up/Down)}$
  * *Note: Upon `.vox` or `.obj` export to Godot 4.7, map MagicaVoxel $Z$-up to Godot $Y$-up, and MagicaVoxel $Y$-depth to Godot $-Z$ forward.*
* **Scale Metric:** $1\text{ Voxel} = 0.25\text{m}$ ($4\text{ voxels} = 1.0\text{ meter}$). 
* **Camera Readability (40m Isometric):** Minimum functional details (eyes, LEDs, levers) are at least $1\times1$ high-contrast emissive voxels surrounded by a minimum $1\text{-voxel}$ border of dark slate (`#1D222B`) to prevent sub-pixel shimmering at $1920\times1080$.
* **Master Semantic Palette Overrides:**
  * In-Tolerance / Telemetry Cyan: `#38E1C6`
  * Guard-Band / Indoor Warm Amber: `#F5A623`
  * Out-of-Tolerance / Alert Red: `#FF5A5F`
  * Deep Slate Shadow (Ambient Occlusion Base): `#1D222B`

---

### MODEL 1: UPLINK TRACTOR (STANDARD & BRAM’S WIDE-TREAD UPGRADE)

#### Footprint (W × D × H)
* **Variant A (Standard Factory Spec):** $14 \times 24 \times 15\text{ voxels}$ ($3.5\text{m} \times 6.0\text{m} \times 3.75\text{m}$)
* **Variant B (Bram’s Wide-Tread Mod):** $18 \times 24 \times 15\text{ voxels}$ ($4.5\text{m} \times 6.0\text{m} \times 3.75\text{m}$)

#### Color Palette (9 Colors)
| Character | Name | Hex Code | Material Type |
| :--- | :--- | :--- | :--- |
| `.` | Empty Space | N/A | Air / Transparent |
| `#` | Tire Rubber / Deep Shadow | `#1D222B` | Matte Roughness 0.9 |
| `=` | Tread Lug / Chassis Grey | `#333C4D` | Metallic 0.4, Rough 0.7 |
| `T` | Tractor Body Yellow-Gold | `#D99B26` | Matte Paint, Rough 0.6 |
| `H` | Roll-Cage / Grille Iron | `#6B788E` | Metallic 0.8, Rough 0.4 |
| `G` | Cabin Canopy Glass | `#4A6B82` | Glass, Alpha 0.5, IOR 1.45 |
| `C` | Telemetry Cyan (Sat-Link) | `#38E1C6` | **Emissive** (Strength 3.5) |
| `A` | Headlight Amber | `#F5A623` | **Emissive** (Strength 2.5) |
| `R` | Out-of-Spec Warning LED | `#FF5A5F` | **Emissive** (Strength 3.0) |

#### Hero 3/4 Isometric View (Concept Sketch)
```text
              [C]             <-- Sat-Phone Roof Whip & Telemetry Dish
             / | \
          +---------+
         /  G  G  G /|        <-- Angled Roll-Cage with Tinted Glass
        +----------+ |
       / T  T  T  T|G|
  +---+------------+ |        <-- Heavy Engine Cowling
 / T  T  T  T  T  /|H|
+----------------+ |#+===+    <-- Bram's Bolted-On Extended Cattracks
| A [H][H][H] A  | # # = #
+----------------+ # # = #
  # = #      # = # # # = #
  #####      ##### +-----+
```

#### Orthographic Views (Visible Voxel Grid)

##### TOP VIEW (X: 18 wide, Y: 24 deep)
*Note: Columns `01-02` and `17-18` represent Bram's Wide-Tread Upgrade (`Variant B`). Omit for `Variant A`.*
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18
Y01 [  .  .  .  .  .  A  H  H  H  H  H  H  A  .  .  .  .  . ] <- Front Grille
Y02 [  .  .  .  .  .  T  T  T  T  T  T  T  T  .  .  .  .  . ]
Y03 [  =  #  #  =  .  T  T  H  H  H  H  T  T  .  =  #  #  = ] <- Front Treads
Y04 [  #  =  =  #  .  T  T  H  H  H  H  T  T  .  #  =  =  # ]
Y05 [  =  #  #  =  =  T  T  T  T  T  T  T  T  =  =  #  #  = ] <- Axle Link
Y06 [  #  =  =  #  .  T  T  T  T  T  T  T  T  .  #  =  =  # ]
Y07 [  =  #  #  =  .  T  T  T  T  T  T  T  T  .  =  #  #  = ]
Y08 [  .  .  .  .  .  T  T  T  T  T  T  T  T  .  .  .  .  . ]
Y09 [  .  .  .  .  .  H  G  G  G  G  G  G  H  .  .  .  .  . ] <- Windshield
Y10 [  .  .  .  .  .  G  T  T  T  T  T  T  G  .  .  .  .  . ]
Y11 [  .  .  .  .  .  G  T  T  C  C  T  T  G  .  .  .  .  . ] <- Roof Sat-Pod
Y12 [  .  .  .  .  .  G  T  T  C  C  T  T  G  .  .  .  .  . ]
Y13 [  =  #  #  =  .  G  T  T  T  T  H  R  G  .  =  #  #  = ] <- Rear Treads
Y14 [  #  =  =  #  .  G  T  T  T  T  H  H  G  .  #  =  =  # ]    & Whip Base
Y15 [  =  #  #  =  .  H  G  G  G  G  G  G  H  .  =  #  #  = ]
Y16 [  #  =  =  #  =  =  T  T  T  T  T  T  =  =  #  =  =  # ]
Y17 [  =  #  #  =  =  =  T  T  T  T  T  T  =  =  =  #  #  = ]
Y18 [  #  =  =  #  .  .  T  T  =  =  T  T  .  .  #  =  =  # ]
Y19 [  =  #  #  =  .  .  T  T  =  =  T  T  .  .  =  #  #  = ]
Y20 [  #  =  =  #  .  .  H  H  H  H  H  H  .  .  #  =  =  # ] <- Rear Hitch
Y21 [  =  #  #  =  .  .  H  =  =  =  =  H  .  .  =  #  #  = ]
Y22 [  .  .  .  .  .  .  .  =  C  C  =  .  .  .  .  .  .  . ] <- Data Hitch
Y23 [  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  . ]
Y24 [  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  . ]
```

##### FRONT VIEW (X: 18 wide, Z: 15 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18
Z15 [  .  .  .  .  .  .  .  .  .  .  .  C  .  .  .  .  .  . ] <- Antenna Tip
Z14 [  .  .  .  .  .  .  .  .  C  C  .  H  .  .  .  .  .  . ] <- Sat Dish
Z13 [  .  .  .  .  .  H  T  T  T  T  T  T  H  .  .  .  .  . ] <- Roof Line
Z12 [  .  .  .  .  .  H  G  G  G  G  G  G  H  .  .  .  .  . ]
Z11 [  .  .  .  .  .  H  G  G  G  G  G  G  H  .  .  .  .  . ]
Z10 [  .  .  .  .  .  H  G  G  C  A  G  G  H  .  .  .  .  . ] <- Dash Glow
Z09 [  .  .  .  .  .  T  T  T  T  T  T  T  T  .  .  .  .  . ] <- Hood Top
Z08 [  .  .  .  .  .  T  A  H  H  H  H  A  T  .  .  .  .  . ] <- Headlights
Z07 [  .  .  .  .  .  T  T  H  =  =  H  T  T  .  .  .  .  . ] <- Front Grille
Z06 [  =  #  #  =  .  T  T  H  =  =  H  T  T  .  =  #  #  = ] <- Tread Top
Z05 [  #  #  #  #  =  =  T  T  T  T  T  T  =  =  #  #  #  # ] <- Axles
Z04 [  #  =  =  #  =  =  =  =  =  =  =  =  =  =  #  =  =  # ]
Z03 [  #  =  =  #  .  .  =  =  #  #  =  =  .  .  #  =  =  # ] <- Undercarriage
Z02 [  #  #  #  #  .  .  .  .  .  .  .  .  .  .  #  #  #  # ]
Z01 [  =  #  #  =  .  .  .  .  .  .  .  .  .  .  =  #  #  = ] <- Ground Contact
```

##### SIDE VIEW (Y: 24 deep, Z: 15 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
Z15 [  .  .  .  .  .  .  .  .  .  .  .  .  C  .  .  .  .  .  .  .  .  .  .  . ]
Z14 [  .  .  .  .  .  .  .  .  .  .  C  C  H  .  .  .  .  .  .  .  .  .  .  . ]
Z13 [  .  .  .  .  .  .  .  .  H  T  T  T  T  T  H  .  .  .  .  .  .  .  .  . ]
Z12 [  .  .  .  .  .  .  .  .  H  G  G  G  G  G  H  .  .  .  .  .  .  .  .  . ]
Z11 [  .  .  .  .  .  .  .  .  H  G  G  G  G  G  H  .  .  .  .  .  .  .  .  . ]
Z10 [  .  .  .  .  .  .  .  .  H  G  C  G  G  R  H  .  .  .  .  .  .  .  .  . ]
Z09 [  .  .  T  T  T  T  T  T  T  T  T  T  T  T  T  T  T  .  .  .  .  .  .  . ]
Z08 [  A  T  T  H  H  T  T  T  T  T  T  T  T  T  T  T  T  T  .  .  .  .  .  . ]
Z07 [  H  T  T  H  H  T  T  T  T  T  T  T  T  T  T  T  T  T  T  .  .  .  .  . ]
Z06 [  H  T  =  #  =  #  =  T  T  T  T  T  =  #  =  #  =  #  =  #  =  .  .  . ]
Z05 [  T  T  #  =  =  =  #  T  =  =  =  =  #  =  =  =  =  =  =  =  #  .  .  . ]
Z04 [  =  =  =  =  #  =  =  =  =  =  =  =  =  =  #  =  =  =  #  =  =  C  .  . ]
Z03 [  .  .  #  =  =  =  #  .  .  .  .  .  #  =  =  =  =  =  =  =  #  =  .  . ]
Z02 [  .  .  =  #  =  #  =  .  .  .  .  .  =  #  =  #  =  #  =  #  =  .  .  . ]
Z01 [  .  .  .  #  #  #  .  .  .  .  .  .  .  #  #  #  #  #  #  #  .  .  .  . ]
```

#### Emissive Voxel Coordinates
* **Roof Sat-Phone Whip Tip (`C` - `#38E1C6`):** `(X:12, Y:13, Z:15)`
* **Roof Sat-Modem Transceiver (`C` - `#38E1C6`):** `(X:09-10, Y:11-12, Z:14)`
* **Cabin Sat-Phone Handset Screen (`C` - `#38E1C6`):** `(X:09, Y:11, Z:10)`
* **Bram's Jury-Rigged Bypass LED (`R` - `#FF5A5F`):** `(X:12, Y:13, Z:10)`
* **Front Headlights (`A` - `#F5A623`):** `(X:06, Y:01, Z:08)` and `(X:13, Y:01, Z:08)`
* **Rear Data-Bus Coupler (`C` - `#38E1C6`):** `(X:09-10, Y:22, Z:04)`

---

### MODEL 2: CURLYHAIR TARANTULA TERRARIUM (*Tliltocatl albopilosus*)

#### Footprint (W × D × H)
* **Total Assembly:** $14 \times 10 \times 12\text{ voxels}$ ($3.5\text{m} \times 2.5\text{m} \times 3.0\text{m}$ — Scaled up as a hero indoor prop for 40m camera readability, or $1:4$ desk detail scale).

#### Color Palette (9 Colors)
| Character | Name | Hex Code | Material Type |
| :--- | :--- | :--- | :--- |
| `.` | Empty Space | N/A | Air / Transparent |
| `#` | Tank Frame / Lamp Dome | `#1D222B` | Matte Metal, Rough 0.8 |
| `G` | Terrarium Glass | `#A3D5E0` | Glass, Alpha 0.25, Rough 0.1 |
| `S` | Coco-Fiber Substrate | `#3B2314` | Matte Earth, Rough 0.95 |
| `B` | Tarantula Carapace Brown | `#261710` | Matte Velvet, Rough 0.9 |
| `W` | Curly Gold-Tipped Bristles | `#D4A359` | Rough 0.7, Sheen 0.5 |
| `M` | Moss / Cork Bark Hide | `#4E6E48` | Matte Organic, Rough 0.85 |
| `A` | Heat Lamp Filament | `#F5A623` | **Emissive** (Strength 4.0) |
| `C` | Hygrometer In-Spec LED | `#38E1C6` | **Emissive** (Strength 3.0) |

#### Hero 3/4 Isometric View (Concept Sketch)
```text
            +----+
           / #  # \          <-- Articulated Heat Lamp Arm
          +--(AA)--+         <-- Warm Amber Bulb (#F5A623)
               |
     +---------#--------+
    / G   G   G   G   G /|
   +-------------------+ |   <-- Black Slate Trim (#1D222B)
   | G               G |#[C] <-- Clipped Hygrometer Pod w/ Cyan LED
   | G    \W/ \W/    G | |
   | G   --W(B)W--   G | |   <-- Curlyhair Tarantula (Brown + Gold Tips)
   | S  S  /W \W  M  S |S|
   +-------------------+ /   <-- Deep Substrate Layer
    ###################+/
```

#### Orthographic Views (Visible Voxel Grid)

##### TOP VIEW (X: 14 wide, Y: 10 deep)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14
Y01 [  #  #  #  #  #  #  #  #  #  #  #  #  #  . ] <- Rear Tank Frame
Y02 [  #  S  S  S  S  S  #  #  S  M  M  S  #  . ]
Y03 [  #  S  W  S  W  S  A  A  M  M  M  S  #  . ] <- Spider Front Legs
Y04 [  #  W  S  B  S  W  A  A  S  M  S  S  #  # ] <- Lamp Dome (Z11) over
Y05 [  #  S  W  B  W  S  S  S  S  S  S  S  #  C ]    Spider & Hygrometer (X14)
Y06 [  #  W  S  W  S  W  S  S  S  S  S  S  #  # ] <- Abdomen w/ Gold Hairs
Y07 [  #  S  W  S  W  S  S  S  S  S  S  S  #  . ]
Y08 [  #  S  S  S  S  S  S  S  S  S  S  S  #  . ]
Y09 [  #  #  #  #  #  #  #  #  #  #  #  #  #  . ] <- Front Tank Frame
Y10 [  .  .  .  .  .  .  .  .  .  .  .  .  .  . ]
```

##### FRONT VIEW (X: 14 wide, Z: 12 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14
Z12 [  .  .  .  .  .  .  #  #  .  .  .  .  .  . ] <- Lamp Clamp Stem
Z11 [  .  .  .  .  .  #  #  #  #  .  .  .  .  . ] <- Lamp Shroud
Z10 [  .  .  .  .  .  #  A  A  #  .  .  .  .  . ] <- Heat Bulb (Emissive)
Z09 [  #  #  #  #  #  #  #  #  #  #  #  #  #  . ] <- Top Mesh Lid
Z08 [  #  G  G  G  G  G  G  G  G  G  G  G  #  # ] <- Clipped Hygrometer
Z07 [  #  G  G  G  G  G  G  G  G  G  G  G  #  C ] <- Telemetry LED (In-Spec)
Z06 [  #  G  G  G  G  G  G  G  G  G  G  G  #  # ]
Z05 [  #  G  W  B  W  G  G  G  M  M  M  G  #  . ] <- Spider & Cork Bark
Z04 [  #  W  B  W  B  W  G  M  M  S  S  M  #  . ] <- Gold-Tipped Legs
Z03 [  #  S  S  S  S  S  S  S  S  S  S  S  #  . ] <- Coco Substrate
Z02 [  #  S  S  S  S  S  S  S  S  S  S  S  #  . ]
Z01 [  #  #  #  #  #  #  #  #  #  #  #  #  #  . ] <- Bottom Tray
```

##### SIDE VIEW (Y: 10 deep, Z: 12 high)
```text
      01 02 03 04 05 06 07 08 09 10
Z12 [  #  #  #  #  #  .  .  .  .  . ] <- Lamp Arm Overhang
Z11 [  #  .  #  #  #  #  .  .  .  . ]
Z10 [  #  .  #  A  A  #  .  .  .  . ] <- Amber Bulb
Z09 [  #  #  #  #  #  #  #  #  #  . ] <- Mesh Lid
Z08 [  #  G  G  G  #  #  #  G  #  . ] <- Hygrometer Profile
Z07 [  #  G  G  G  #  C  #  G  #  . ]
Z06 [  #  G  G  G  #  #  #  G  #  . ]
Z05 [  #  G  M  M  B  W  G  G  #  . ] <- Spider Abdomen (W) & Carapace (B)
Z04 [  #  M  M  W  B  W  W  G  #  . ]
Z03 [  #  S  S  S  S  S  S  S  #  . ]
Z02 [  #  S  S  S  S  S  S  S  #  . ]
Z01 [  #  #  #  #  #  #  #  #  #  . ]
```

#### Emissive Voxel Coordinates
* **Basking Heat Lamp (`A` - `#F5A623`):** `(X:07-08, Y:03-04, Z:10)`
* **Hygrometer Status LED (`C` - `#38E1C6`):** `(X:14, Y:05, Z:07)`

---

### MODEL 3: BRAM (SCRAPYARD MECHANIC) & SCRAPYARD BAY DIORAMA

#### Footprint (W × D × H)
* **Bram (Character Standalone):** $6 \times 4 \times 9\text{ voxels}$ ($1.5\text{m} \times 1.0\text{m} \times 2.25\text{m}$ with heavy boots/hair)
* **Scrapyard Bay Diorama (Including Bram):** $24 \times 20 \times 16\text{ voxels}$ ($6.0\text{m} \times 5.0\text{m} \times 4.0\text{m}$)

#### Color Palette (10 Colors)
| Character | Name | Hex Code | Material Type |
| :--- | :--- | :--- | :--- |
| `.` | Empty Space | N/A | Air / Transparent |
| `#` | Tire Rubber / Grease / Shadow | `#1D222B` | Matte Roughness 0.9 |
| `=` | Concrete Floor / Steel Frame | `#3D4654` | Matte Roughness 0.8 |
| `B` | Rusted I-Beam / Pegboard | `#7A3E26` | Matte Rust, Rough 0.85 |
| `O` | Bram’s Stained Overalls | `#2B4C65` | Matte Cloth, Rough 0.8 |
| `S` | Skin Tone (Oil-Smudged) | `#D99B78` | Subsurface 0.2, Rough 0.6 |
| `H` | Welding Goggles / Heavy Hammer| `#8C9BAE` | Metallic 0.9, Rough 0.3 |
| `A` | Overhead Work Lamp (Warm) | `#F5A623` | **Emissive** (Strength 3.5) |
| `R` | Out-of-Spec Torque Wrench LED | `#FF5A5F` | **Emissive** (Strength 3.0) |
| `C` | Diagnostic Bench Terminal | `#38E1C6` | **Emissive** (Strength 2.5) |

#### Hero 3/4 Isometric View (Concept Sketch)
```text
      +=======================================+
     / B                 [AAA]               B \    <-- Rusted I-Beam Frame
    +===========================================+       & Warm Work Lamp
    | B |  [H]  [R]  |                          |
    | B | (Tool Wall)|       (H)(H)             |   <-- Bram w/ Forehead Goggles
    | B +------------+        (S#)    [H]       |       & Giant Percussive Hammer
    | B | [C][C] ====|       /O#O\=====|        |
    | B | (Workbench)|       |O O|              |
    | ===============================   #####   |
   /  =   =   =   =   =   =   =   =    # === # /    <-- Chunky Rover Tire Stack
  +-----------------------------------  ##### +
```

#### Orthographic Views (Visible Voxel Grid)

##### TOP VIEW (X: 24 wide, Y: 20 deep)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
Y01 [  B  B  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  B  B ] <- Rear Wall
Y02 [  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B ] <- Tool Wall
Y03 [  =  =  =  =  H  =  R  =  H  =  =  =  =  C  C  =  =  =  #  #  #  #  =  = ] <- Workbench
Y04 [  =  =  =  =  =  =  =  =  =  =  =  =  =  C  C  =  =  =  #  =  =  #  =  = ]    & Tire Stack
Y05 [  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  #  =  =  #  =  = ]
Y06 [  =  =  #  #  =  =  =  =  =  =  =  =  =  =  =  =  =  =  #  #  #  #  =  = ]
Y07 [  =  =  #  #  #  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  = ] <- Oil Spill
Y08 [  =  =  =  #  #  =  =  =  =  =  A  A  A  A  =  =  =  =  =  #  #  #  =  = ] <- Overhead
Y09 [  =  =  =  =  =  =  =  =  =  =  A  A  A  A  =  =  =  =  =  #  =  #  =  = ]    Lamp (Z15)
Y10 [  B  =  =  =  =  =  =  =  =  O  S  S  O  H  H  =  =  =  =  #  #  #  =  B ] <- BRAM (X10-15)
Y11 [  B  =  =  =  =  =  =  =  =  O  S  #  O  H  H  =  =  =  =  =  =  =  =  B ]    w/ Big Hammer
Y12 [  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  = ]
Y13 [  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  = ]
Y14 [  =  =  =  =  =  =  =  =  #  #  #  #  =  =  =  =  =  =  =  =  =  =  =  = ] <- Floor Grease
Y15 [  =  =  =  =  =  =  =  =  =  #  #  =  =  =  =  =  =  =  =  =  =  =  =  = ]
Y16 [  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  = ]
Y17 [  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  = ]
Y18 [  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  = ]
Y19 [  B  B  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  B  B ] <- Front Pillars
Y20 [  B  B  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  B  B ]
```

##### FRONT VIEW (X: 24 wide, Z: 16 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
Z16 [  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B ] <- Roof Crossbeam
Z15 [  B  B  =  =  =  =  =  =  =  #  #  #  #  #  #  =  =  =  =  =  =  =  B  B ] <- Lamp Fixture
Z14 [  B  B  .  .  .  .  .  .  .  .  A  A  A  A  .  .  .  .  .  .  .  .  B  B ] <- Warm Lamp
Z13 [  B  B  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  B  B ]
Z12 [  B  B  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  B  B ]
Z11 [  B  B  .  B  B  B  B  B  B  B  B  .  .  .  .  .  .  .  .  .  .  .  B  B ] <- Pegboard Top
Z10 [  B  B  .  B  H  B  R  B  H  B  B  H  H  .  .  .  .  .  .  .  .  .  B  B ] <- Bram's Goggles
Z09 [  B  B  .  B  H  B  R  B  B  B  B  S  S  .  H  H  .  .  #  #  #  #  B  B ] <- Bram's Head &
Z08 [  B  B  .  B  B  B  R  B  B  B  B  S  #  .  H  H  .  .  #  =  =  #  B  B ]    Hammer & Tires
Z07 [  B  B  .  B  B  B  B  B  B  B  S  O  O  S  H  .  .  .  #  #  #  #  B  B ] <- Bram's Torso
Z06 [  B  B  .  =  =  =  =  =  =  =  S  O  #  O  =  =  =  .  #  =  =  #  B  B ] <- Grease Apron
Z05 [  B  B  .  =  =  =  =  =  =  =  O  O  O  O  C  C  =  .  #  #  #  #  B  B ] <- Workbench
Z04 [  B  B  .  =  =  .  .  .  .  =  O  .  .  O  =  =  =  .  #  =  =  #  B  B ] <- Bram's Legs
Z03 [  B  B  .  =  =  .  .  .  .  =  #  .  .  #  .  =  =  .  #  #  #  #  B  B ] <- Steel-Toe Boots
Z02 [  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  = ] <- Concrete Slab
Z01 [  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  # ] <- Foundation
```

##### SIDE VIEW (Y: 20 deep, Z: 16 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20
Z16 [  B  B  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  B  B ]
Z15 [  B  B  .  .  .  .  .  #  #  #  #  .  .  .  .  .  .  .  B  B ]
Z14 [  B  B  .  .  .  .  .  A  A  A  A  .  .  .  .  .  .  .  B  B ] <- Overhead Lamp
Z13 [  B  B  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  B  B ]
Z12 [  B  B  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  B  B ]
Z11 [  B  B  B  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  B  B ]
Z10 [  B  B  R  .  .  .  .  .  .  H  H  .  .  .  .  .  .  .  B  B ] <- Red Torque Wrench (Y03)
Z09 [  B  B  R  #  #  #  .  .  .  S  S  H  .  .  .  .  .  .  B  B ] <- Bram + Sledgehammer
Z08 [  B  B  R  #  =  #  .  .  .  S  #  H  .  .  .  .  .  .  B  B ]
Z07 [  B  B  B  #  #  #  .  .  .  O  O  S  .  .  .  .  .  .  B  B ]
Z06 [  B  B  =  #  =  #  .  #  #  O  #  .  .  .  .  .  .  .  B  B ]
Z05 [  B  B  =  C  C  #  .  #  =  O  O  .  .  .  .  .  .  .  B  B ] <- Bench Terminal (C)
Z04 [  B  B  =  =  =  #  .  #  #  O  O  .  .  .  .  .  .  .  B  B ]
Z03 [  B  B  =  =  =  #  .  #  #  #  #  .  .  .  .  .  .  .  B  B ]
Z02 [  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  =  = ]
Z01 [  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  #  # ]
```

#### Emissive Voxel Coordinates
* **Overhead Shop Light (`A` - `#F5A623`):** `(X:11-14, Y:08-09, Z:14)`
* **Broken Digital Torque Wrench on Pegboard (`R` - `#FF5A5F`):** `(X:07, Y:03, Z:08-10)` *(Blinks red constantly—out of calibration)*
* **Workbench Diagnostic Oscilloscope (`C` - `#38E1C6`):** `(X:14-15, Y:03-04, Z:05)`

---

### MODEL 4: CRYSTAL ORE FISSURE (TERRACOTTA PLATEAU)

#### Footprint (W × D × H)
* **Standard Node:** $8 \times 8 \times 6\text{ voxels}$ ($2.0\text{m} \times 2.0\text{m} \times 1.5\text{m}$)

#### Color Palette (6 Colors)
| Character | Name | Hex Code | Material Type |
| :--- | :--- | :--- | :--- |
| `.` | Empty Space | N/A | Air / Transparent |
| `#` | Deep Fissure Shadow | `#1D222B` | Matte Roughness 1.0 |
| `T` | Terracotta Plateau Clay | `#A8422B` | Matte Clay, Rough 0.9 |
| `R` | Oxidized Rust Crust | `#6E2617` | Matte Rock, Rough 0.95 |
| `Q` | Dark Quartz Base | `#1F7A70` | Glassy Subsurface, Rough 0.3 |
| `C` | Telemetry Cyan Quartz Tip | `#38E1C6` | **Emissive** (Strength 4.0) |

#### Hero 3/4 Isometric View (Concept Sketch)
```text
           [C]
          / C \   [C]
     [C]  | Q |  / Q \      <-- Jagged Cyan Quartz Spires (#38E1C6)
    / Q \ | Q |  | Q |
   +-----##---####----+
  / T  R  # Q  #  R  T \    <-- Cracked Rust-Red Terracotta Crust
 +----------------------+
  \ R  T  T  R  R  T  R /
   +-------------------+
```

#### Orthographic Views (Visible Voxel Grid)

##### TOP VIEW (X: 8 wide, Y: 8 deep)
```text
      01 02 03 04 05 06 07 08
Y01 [  .  T  T  R  R  T  T  . ]
Y02 [  T  R  #  #  Q  R  T  T ]
Y03 [  T  #  C  Q  #  C  R  T ] <- Diagonal Fissure Line
Y04 [  R  #  Q  C  C  #  #  R ] <- Main Central Spire (X04-05, Y04)
Y05 [  R  Q  #  C  C  Q  #  T ]
Y06 [  T  R  C  #  Q  C  R  T ]
Y07 [  T  T  R  #  #  R  T  . ]
Y08 [  .  T  T  R  R  T  .  . ]
```

##### FRONT VIEW (X: 8 wide, Z: 6 high)
```text
      01 02 03 04 05 06 07 08
Z06 [  .  .  .  C  C  .  .  . ] <- Highest Central Crystal Tip
Z05 [  .  .  C  C  C  C  .  . ]
Z04 [  .  .  Q  Q  Q  C  .  . ]
Z03 [  .  R  Q  Q  Q  Q  R  . ] <- Mid-Transition (Dark Quartz)
Z02 [  T  R  #  Q  Q  #  R  T ] <- Fissure Lip
Z01 [  T  T  R  #  #  R  T  T ] <- Plateau Ground Level
```

##### SIDE VIEW (Y: 8 deep, Z: 6 high)
```text
      01 02 03 04 05 06 07 08
Z06 [  .  .  .  C  C  .  .  . ]
Z05 [  .  .  C  C  C  C  .  . ]
Z04 [  .  .  C  Q  Q  Q  .  . ]
Z03 [  .  R  Q  Q  Q  Q  R  . ]
Z02 [  T  R  #  Q  Q  #  R  T ]
Z01 [  T  T  R  #  #  R  T  T ]
```

#### Emissive Voxel Coordinates
* **Primary Spire Peak (`C` - `#38E1C6`):** `(X:04-05, Y:04-05, Z:05-06)`
* **North-West Offshoot Crystal (`C` - `#38E1C6`):** `(X:03, Y:03, Z:04-05)`
* **South-East Offshoot Crystal (`C` - `#38E1C6`):** `(X:06, Y:03, Z:04-05)` and `(X:06, Y:06, Z:05)`
* **South-West Offshoot Crystal (`C` - `#38E1C6`):** `(X:03, Y:06, Z:05)`

---

### MODEL 5: MEGACORP DROP-POD & AUD-1T COMPLIANCE DRONE

#### Footprint (W × D × H)
* **MegaCorp Drop-Pod:** $12 \times 12 \times 16\text{ voxels}$ ($3.0\text{m} \times 3.0\text{m} \times 4.0\text{m}$)
* **AUD-1T Hovering Drone:** $4 \times 4 \times 5\text{ voxels}$ ($1.0\text{m} \times 1.0\text{m} \times 1.25\text{m}$)
* **Combined Scene Footprint:** $18 \times 12 \times 16\text{ voxels}$

#### Color Palette (8 Colors)
| Character | Name | Hex Code | Material Type |
| :--- | :--- | :--- | :--- |
| `.` | Empty Space | N/A | Air / Transparent |
| `#` | Scorched Heatshield / Thruster | `#1D222B` | Matte Char, Rough 0.9 |
| `=` | Structural Titanium Struts | `#4F5D73` | Metallic 0.8, Rough 0.4 |
| `O` | MegaCorp Orbital Orange Hull | `#E85D25` | Glossy Paint, Rough 0.3 |
| `W` | AUD-1T Sterile White Shell | `#F0F4F8` | Glossy Ceramic, Rough 0.15 |
| `A` | Guard-Band Amber (Eye & Hatch) | `#F5A623` | **Emissive** (Strength 3.5) |
| `R` | Drop-Pod Collision Strobe | `#FF5A5F` | **Emissive** (Strength 4.0) |
| `C` | AUD-1T Repulsor Thruster Ring | `#38E1C6` | **Emissive** (Strength 3.0) |

#### Hero 3/4 Isometric View (Concept Sketch)
```text
            [R]
           / = \              <-- Retro-Rocket Nose Cone & Red Strobe
         +-------+
        / O  O  O \
       +-----------+
       | O +---+ O |          <-- MegaCorp Orange Hull (#E85D25)
       | O | A | O |          <-- Glowing Amber Hatch Seam (#F5A623)
       | O | A | O |                      +-----+
      /| O +---+ O |\                    / W W W \
     # | =   =   = | #                  | W [A] W |  <-- AUD-1T Drone
    #  +-----------+  #                  \  [C]  /       (Amber Cyclops Eye)
       # #       # #
```

#### Orthographic Views (Visible Voxel Grid)

##### TOP VIEW (X: 18 wide, Y: 12 deep)
*Drop-Pod occupies `X:01-12`; AUD-1T hovers at `X:15-18, Y:05-08`.*
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18
Y01 [  #  #  .  .  .  =  =  .  .  .  #  #  .  .  .  .  .  . ] <- Landing Struts
Y02 [  #  #  .  O  O  O  O  O  O  .  #  #  .  .  .  .  .  . ]
Y03 [  .  .  O  O  =  =  =  =  O  O  .  .  .  .  .  .  .  . ]
Y04 [  .  O  O  =  =  O  O  =  =  O  O  .  .  .  .  .  .  . ]
Y05 [  .  O  =  =  O  R  R  O  =  =  O  .  .  .  .  W  W  . ] <- Pod Apex (R) &
Y06 [  =  O  =  O  O  R  R  O  O  =  O  =  .  .  W  W  W  W ]    AUD-1T Dome (W)
Y07 [  =  O  =  O  O  R  R  O  O  =  O  =  .  .  W  W  W  W ]
Y08 [  .  O  =  =  O  R  R  O  =  =  O  .  .  .  .  A  A  . ] <- AUD-1T Eye (A)
Y09 [  .  O  O  =  =  O  O  =  =  O  O  .  .  .  .  .  .  . ]
Y10 [  .  .  O  O  A  A  A  A  O  O  .  .  .  .  .  .  .  . ] <- Amber Hatch
Y11 [  #  #  .  O  A  A  A  A  O  .  #  #  .  .  .  .  .  . ]
Y12 [  #  #  .  .  .  A  A  .  .  .  #  #  .  .  .  .  .  . ]
```

##### FRONT VIEW (X: 18 wide, Z: 16 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18
Z16 [  .  .  .  .  .  R  R  .  .  .  .  .  .  .  .  .  .  . ] <- Beacon Tip
Z15 [  .  .  .  .  =  =  =  =  .  .  .  .  .  .  .  .  .  . ] <- Nose Cone
Z14 [  .  .  .  O  O  =  =  O  O  .  .  .  .  .  .  .  .  . ]
Z13 [  .  .  O  O  O  O  O  O  O  O  .  .  .  .  .  .  .  . ]
Z12 [  .  .  O  O  O  O  O  O  O  O  .  .  .  .  .  .  .  . ]
Z11 [  .  O  O  =  =  =  =  =  =  O  O  .  .  .  .  .  .  . ]
Z10 [  .  O  O  =  A  A  A  A  =  O  O  .  .  .  .  W  W  . ] <- AUD-1T Top
Z09 [  .  O  O  =  A  =  =  A  =  O  O  .  .  .  W  W  W  W ]
Z08 [  .  O  O  =  A  =  =  A  =  O  O  .  .  .  W  A  A  W ] <- Scanner Eye
Z07 [  .  O  O  =  A  =  =  A  =  O  O  .  .  .  .  #  #  . ]
Z06 [  .  O  O  =  A  A  A  A  =  O  O  .  .  .  .  C  C  . ] <- Hover Ring
Z05 [  #  #  O  =  =  =  =  =  =  O  #  #  .  .  .  .  .  . ] <- Landing Gear
Z04 [  #  #  O  O  O  O  O  O  O  O  #  #  .  .  .  .  .  . ]
Z03 [  #  .  #  #  #  #  #  #  #  #  .  #  .  .  .  .  .  . ] <- Heat Shield
Z02 [  #  .  .  #  #  .  .  #  #  .  .  #  .  .  .  .  .  . ]
Z01 [  #  #  .  .  .  .  .  .  .  .  #  #  .  .  .  .  .  . ] <- Footpads
```

##### SIDE VIEW (Y: 12 deep, Z: 16 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12
Z16 [  .  .  .  .  .  R  R  .  .  .  .  . ]
Z15 [  .  .  .  .  =  =  =  =  .  .  .  . ]
Z14 [  .  .  .  O  O  =  =  O  O  .  .  . ]
Z13 [  .  .  O  O  O  O  O  O  O  O  .  . ]
Z12 [  .  .  O  O  O  O  O  O  O  O  .  . ]
Z11 [  .  O  O  O  O  O  O  O  O  =  O  . ]
Z10 [  .  O  O  O  O  W  W  O  O  A  =  . ] <- AUD-1T super-imposed (Y05-08)
Z09 [  .  O  O  O  W  W  W  W  O  A  =  . ]
Z08 [  .  O  O  O  W  W  W  A  O  A  =  . ] <- Drone Eye (Y08) & Pod Hatch (Y10)
Z07 [  .  O  O  O  O  #  #  O  O  A  =  . ]
Z06 [  .  O  O  O  O  C  C  O  O  A  =  . ] <- Drone Cyan Thruster (Z06)
Z05 [  #  #  O  O  O  O  O  O  O  =  #  # ]
Z04 [  #  #  O  O  O  O  O  O  O  O  #  # ]
Z03 [  #  .  #  #  #  #  #  #  #  #  .  # ]
Z02 [  #  .  .  #  #  .  .  #  #  .  .  # ]
Z01 [  #  #  .  .  .  .  .  .  .  .  #  # ]
```

#### Emissive Voxel Coordinates
* **Drop-Pod Apex Warning Strobe (`R` - `#FF5A5F`):** `(X:06-07, Y:05-08, Z:16)`
* **Drop-Pod Seal Guard-Band Hatch (`A` - `#F5A623`):**Perimeter ring at `(X:05-08, Y:10-11, Z:06-10)`
* **AUD-1T Compliance Scanner Eye (`A` - `#F5A623`):** `(X:16-17, Y:08, Z:08)`
* **AUD-1T Repulsor Lift Ring (`C` - `#38E1C6`):** `(X:16-17, Y:06-07, Z:06)`

---

### MODEL 6: SATELLITE RELAY MAST WITH OPTICAL SILK SPOOL BAY

#### Footprint (W × D × H)
* **Total Structure:** $16 \times 12 \times 24\text{ voxels}$ ($4.0\text{m} \times 3.0\text{m} \times 6.0\text{m}$)

#### Color Palette (8 Colors)
| Character | Name | Hex Code | Material Type |
| :--- | :--- | :--- | :--- |
| `.` | Empty Space | N/A | Air / Transparent |
| `#` | Heavy Base / Rubber Cable | `#1D222B` | Matte Roughness 0.9 |
| `=` | Galvanized Mast Truss | `#526075` | Metallic 0.7, Rough 0.5 |
| `W` | Parabolic Dish White | `#E1E8F0` | Matte Paint, Rough 0.4 |
| `S` | Optical Silk Spool (Iridescent)| `#D8F0F2` | Sheen 0.9, Rough 0.2, Metallic 0.3 |
| `G` | Spool Flange Gold-Anodized | `#C48F2B` | Metallic 0.9, Rough 0.3 |
| `C` | Telemetry Beacon & Fiber Glow | `#38E1C6` | **Emissive** (Strength 4.0) |
| `A` | Spool Tension Guard-Band LED | `#F5A623` | **Emissive** (Strength 2.5) |

#### Hero 3/4 Isometric View (Concept Sketch)
```text
             [C]               <-- High-Altitude Cyan Telemetry Beacon
              |
             |=|
        \ W  W  W /
       | W  [C]  W |           <-- Parabolic Dish w/ Cyan LNB Receiver
        / W  W  W \
             |=|
             |=|
             |=|
            / = \
       +-------------+---------+
      / =   =   =   /   =   = /|
     +-------------+---------+ |
     | #  [C]  #   | G |S| G | | <-- Side Bay w/ Optical Silk Spool (S)
     | #  # #  #   | G |S| G | |     & Gold Anodized Flanges (G)
     +-------------+---------+ /
      #######################+/
```

#### Orthographic Views (Visible Voxel Grid)

##### TOP VIEW (X: 16 wide, Y: 12 deep)
*Main Mast & Dish occupy `X:01-10`; Side Silk Spool Bay occupies `X:11-16`.*
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16
Y01 [  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  . ]
Y02 [  .  #  #  #  #  #  #  #  #  #  #  #  #  #  #  . ] <- Concrete Pad
Y03 [  .  #  =  =  =  =  =  =  =  =  =  =  =  =  #  . ]
Y04 [  .  #  =  .  W  W  W  W  .  =  #  G  S  S  G  . ] <- Dish Rim (Z14-20) &
Y05 [  .  #  =  W  W  =  =  W  W  =  #  G  S  C  G  . ]    Silk Drum (X12-15)
Y06 [  .  #  =  W  =  C  C  =  W  =  #  G  S  C  G  . ] <- Mast Core (C)
Y07 [  .  #  =  W  =  C  C  =  W  =  #  G  S  S  G  . ]
Y08 [  .  #  =  .  W  =  =  W  .  =  #  =  =  A  =  . ] <- Tension Sensor (A)
Y09 [  .  #  =  =  .  W  W  .  =  =  =  =  =  =  #  . ]
Y10 [  .  #  #  #  #  .  C  .  #  #  #  #  #  #  #  . ] <- Dish Feedhorn (Y10)
Y11 [  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  . ]
Y12 [  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  . ]
```

##### FRONT VIEW (X: 16 wide, Z: 24 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16
Z24 [  .  .  .  .  .  C  C  .  .  .  .  .  .  .  .  . ] <- Omni-Beacon (Cyan)
Z23 [  .  .  .  .  .  C  C  .  .  .  .  .  .  .  .  . ]
Z22 [  .  .  .  .  .  =  =  .  .  .  .  .  .  .  .  . ] <- Upper Mast
Z21 [  .  .  .  .  .  =  =  .  .  .  .  .  .  .  .  . ]
Z20 [  .  .  .  .  W  W  W  W  .  .  .  .  .  .  .  . ] <- Dish Top Lip
Z19 [  .  .  .  W  W  W  W  W  W  .  .  .  .  .  .  . ]
Z18 [  .  .  .  W  W  =  =  W  W  .  .  .  .  .  .  . ]
Z17 [  .  .  .  W  =  C  C  =  W  .  .  .  .  .  .  . ] <- Dish LNB Focus
Z16 [  .  .  .  W  W  =  =  W  W  .  .  .  .  .  .  . ]
Z15 [  .  .  .  W  W  W  W  W  W  .  .  .  .  .  .  . ]
Z14 [  .  .  .  .  W  W  W  W  .  .  .  .  .  .  .  . ] <- Dish Bottom Lip
Z13 [  .  .  .  .  .  =  =  .  .  .  .  .  .  .  .  . ]
Z12 [  .  .  .  .  =  .  .  =  .  .  .  .  .  .  .  . ] <- Open Lattice Tower
Z11 [  .  .  .  .  =  =  =  =  .  .  .  .  .  .  .  . ]
Z10 [  .  .  .  =  .  .  .  .  =  .  .  .  .  .  .  . ]
Z09 [  .  .  .  =  =  =  =  =  =  .  .  .  .  .  .  . ]
Z08 [  .  .  =  =  =  =  =  =  =  =  =  =  =  =  =  . ] <- Bay Roof Frame
Z07 [  .  .  =  #  #  #  #  #  #  =  #  .  .  A  =  . ] <- Bay Tensioner (A)
Z06 [  .  .  =  #  C  C  #  #  #  =  #  G  S  S  G  . ] <- Optical Silk Spool
Z05 [  .  .  =  #  C  C  #  A  #  =  #  G  S  C  G  . ]    with Cyan Fiber Core
Z04 [  .  .  =  #  #  #  #  #  #  =  #  G  S  S  G  . ]
Z03 [  .  .  =  #  #  #  #  #  #  =  #  .  .  .  =  . ]
Z02 [  .  #  #  #  #  #  #  #  #  #  #  #  #  #  #  . ] <- Concrete Plinth
Z01 [  .  #  #  #  #  #  #  #  #  #  #  #  #  #  #  . ]
```

##### SIDE VIEW (Y: 12 deep, Z: 24 high)
```text
      01 02 03 04 05 06 07 08 09 10 11 12
Z24 [  .  .  .  .  .  C  C  .  .  .  .  . ]
Z23 [  .  .  .  .  .  C  C  .  .  .  .  . ]
Z22 [  .  .  .  .  .  =  =  .  .  .  .  . ]
Z21 [  .  .  .  .  .  =  =  .  .  .  .  . ]
Z20 [  .  .  .  .  .  .  W  W  .  .  .  . ]
Z19 [  .  .  .  .  .  W  W  .  .  .  .  . ]
Z18 [  .  .  .  .  .  W  =  .  .  .  .  . ]
Z17 [  .  .  .  .  .  W  =  =  =  C  .  . ] <- LNB Arm extending to Y10
Z16 [  .  .  .  .  .  W  =  .  .  .  .  . ]
Z15 [  .  .  .  .  .  W  W  .  .  .  .  . ]
Z14 [  .  .  .  .  .  .  W  W  .  .  .  . ]
Z13 [  .  .  .  .  .  =  =  .  .  .  .  . ]
Z12 [  .  .  .  .  =  .  .  =  .  .  .  . ]
Z11 [  .  .  .  .  =  =  =  =  .  .  .  . ]
Z10 [  .  .  .  =  .  .  .  .  =  .  .  . ]
Z09 [  .  .  .  =  =  =  =  =  =  .  .  . ]
Z08 [  .  .  =  =  =  =  =  =  =  =  .  . ]
Z07 [  .  .  =  #  .  .  .  A  =  =  .  . ]
Z06 [  .  .  =  #  S  S  S  S  =  =  .  . ] <- Cylindrical Spool Profile
Z05 [  .  .  =  #  S  C  C  S  =  =  .  . ] <- Glowing Optical Silk Core
Z04 [  .  .  =  #  S  S  S  S  =  =  .  . ]
Z03 [  .  .  =  #  #  =  =  #  =  =  .  . ] <- Spool Axle Mount
Z02 [  .  #  #  #  #  #  #  #  #  #  .  . ]
Z01 [  .  #  #  #  #  #  #  #  #  #  .  . ]
```

#### Emissive Voxel Coordinates
* **Masthead Sky-Beacon (`C` - `#38E1C6`):** `(X:06-07, Y:06-07, Z:23-24)`
* **Dish Feedhorn Receiver (`C` - `#38E1C6`):** `(X:06-07, Y:10, Z:17)`
* **Base Cabinet Telemetry Screen (`C` - `#38E1C6`):** `(X:05-06, Y:09, Z:05-06)`
* **Optical Silk Core Luminescence (`C` - `#38E1C6`):** `(X:14, Y:05-06, Z:05)` *(Shines through the wound `#D8F0F2` silk layers)*
* **Spool Feed-Tension Guard-Band LEDs (`A` - `#F5A623`):** `(X:14, Y:08, Z:07)` and `(X:08, Y:09, Z:05)`