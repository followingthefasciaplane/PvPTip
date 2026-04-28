
## PvPTip
  
A World of Warcraft addon that reveals hidden PvP coefficients in tooltips and provides an interface for exploring PvP modifiers across all classes.  
  
Still heavily beta and needs more work! Lots of stuff is still missing or to-do.  
  
## GUI Panel
  
Accessed via `/pvptip`, `/pt`, or the minimap button. Three tabs:  
  
- **Overview**: Detected & modified tooltips (based on your spec, to improve). This is going to miss most things. 
- **Settings**: Tooltip mode, custom colors, enable/disable features.
- **Lookup**: Advanced lookup of all known PvP modifiers parsed from Data.lua across every class. Select your own class to see a full list of active modifiers.

<img width="947" height="633" alt="desk1" src="https://github.com/user-attachments/assets/05aa9054-5eb7-4449-a6ad-850ac5076833" />

## Tooltip Mode  
  
PvP coefficient data is injected directly into spell tooltips. Three display modes:  
  
- **Compact** (default): `PvP: Fire damage -15% | Shadow DoT -20%`  
- **Verbose**: Full details with raw multipliers, modifier aura sources, and effective values (work in progress)
- **Minimal**: Just percentages: `PvP: -15% | -20%`

<img width="947" height="633" alt="2" src="https://github.com/user-attachments/assets/78aebfe7-3310-4761-ae5a-f98a8dc4390a" />
<img width="785" height="633" alt="3" src="https://github.com/user-attachments/assets/5ffbc13f-19c6-41ca-bf28-330df5b353cc" />


## To do

- Item tooltips (trinkets, embellishments, enchants, gems)
- Racials, consumables (flasks, potions)
- Tier set PvP coefficient display
- Child spell expansion in tooltips (showing which spells a broader aura coefficient affects)
- Map and translate more effects to human readable labels
- A million other things
  

