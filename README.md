## PvPTip
  
A World of Warcraft addon that reveals hidden PvP coefficients in tooltips and provides an interface for exploring PvP modifiers across all classes.  
  
Still heavily beta and needs more work! Lots of stuff is still missing or to-do.  
  
## GUI Panel
  
Accessed via `/pvptip`, `/pt`, or the minimap button. Three tabs:  
  
- **Overview**: Detected & modified tooltips (based on your spec, to improve). This is going to miss most things. 
- **Settings**: Tooltip mode, custom colors, enable/disable features.
- **Lookup**: Advanced lookup of all known PvP modifiers parsed from Data.lua across every class. Select your own class to see a full list of active modifiers.

<img width="804" height="591" alt="image" src="https://github.com/user-attachments/assets/efb2c0fc-a99d-41ee-aba2-ad2a9bfed03f" />

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
  

