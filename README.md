## PvPTip
  
A World of Warcraft addon that reveals hidden PvP coefficients in tooltips and provides an interface for exploring PvP modifiers across all classes.  
  
Still heavily beta and needs more work! Lots of stuff is still missing or to-do.  
  


## GUI Panel
  
Accessed via `/pvptip`, `/pt`, or the minimap button. Three tabs:  
  
- **Overview**: Detected & modified tooltips (based on your spec, to improve). This is going to miss most things. 
- **Settings**: Tooltip mode, custom colors, enable/disable features.
- **Lookup**: Advanced lookup of all known PvP modifiers parsed from Data.lua across every class. Select your own class to see a full list of active modifiers.

<img width="1283" height="638" alt="Advanced tab" src="https://github.com/user-attachments/assets/657f8c04-c814-4320-b0fc-52cdb82d4c81" />

## Tooltip Mode  
  
PvP coefficient data is injected directly into spell tooltips. Three display modes:  
  
- **Compact** (default): `PvP: Fire damage -15% | Shadow DoT -20%`  
- **Verbose**: Full details with raw multipliers, modifier aura sources, and effective values (work in progress)
- **Minimal**: Just percentages: `PvP: -15% | -20%`

<img width="790" height="867" alt="Spellbook" src="https://github.com/user-attachments/assets/6cb59e01-cc7d-47d2-ad04-1609e080a73e" />
<img width="438" height="376" alt="Talent tree" src="https://github.com/user-attachments/assets/4baa7325-a038-4ebd-9047-52dd760e65aa" />

## To do

- Item tooltips (trinkets, embellishments, enchants, gems)
- Racials, consumables (flasks, potions)
- Tier set PvP coefficient display
- Child spell expansion in tooltips (showing which spells a broader aura coefficient affects)
- Map and translate more effects to human readable labels
- A million other things
  
## Updating / Changing Data For Different Builds
  
Unfortunately, this data can only be extracted from the client and cannot be found via the API. This means that updates will have to be done manually.  
  
There are two Python scripts in the `generator` directory:  
  
1. `download_db2.py` 
- This downloads the necessary DB2 files as CSV from [wago.tools](https://wago.tools) to generate `Data.lua`.
- Has a required `--build` argument to specify which build of WoW you are targetting. 
- Usage: `python3 download_db2.py --build 12.0.1.66838`
  
2. `generate_data.py`
- This will parse the downloaded CSV files and output a new `Data.lua` to replace the existing one.
- Usage: `python3 PvPTip/tools/generate_data.py --db2 db2_raw --output PvPTip/Data.lua` where `db2_raw` is the directory containing CSV files.
  
## Parsing Effect Data
  
Raw DB2 data is translated into player-facing descriptions. This is a manual process and there are many missing entries. I will continue to add more support over time.  

Here's a small snippet of some example labels that are already implemented:  
  
| Raw DB2 | PvPTip Shows |
|---------|-------------|
| Effect=2, SchoolMask=4, PvpMult=1.068 | **Fire damage +7%** |
| Effect=6, Aura=3, SchoolMask=1, Mechanic=15 | **Physical DoT (bleeding) -15%** |
| Effect=6, Aura=69, PvpMult=0.6 | **Absorb value -40%** |
| Effect=6, Aura=108, MiscVal=0, PvpMult=0.5 | **Spell power -50%** |
| Effect=3 (Dummy), sibling=Stun | **Stun value -38%** |
  
Labels are enriched with:
- **School names** from SpellMisc (Fire, Shadow, Frost, Nature, Arcane, Holy, Chaos)
- **Mechanic names** from SpellMechanic (bleeding, stunned, silenced, rooted, etc.)
- **Sibling-context inference** for generic effects (Dummy/Passive > inferred from other effects on the same spell, work in progress)

## Three Layer Effective Multipliers
  
PvPTip computes effective multipliers from three sources:  
  
1. **Layer 1 — Base coefficient**: `SpellEffect.PvpMultiplier` per effect (4,471 modified effects across 3,323 spells)   
2. **Layer 2 — Modifier auras** (EffectAura 647): Class passives, tier sets, and talents that modify PvP multipliers via SpellClassMask targeting
   
3. **Layer 3 — Label-based modifiers** (EffectAura 649): Surgical PvP adjustments targeting spells by SpellLabel ID  
   
**Formula**: `effective = base_pvp_mult * (1 + sum(layer2_values)/100 + sum(layer3_values)/100)`  

## License

The Unlicense
