#!/usr/bin/env python3
"""
Generate PvPTip/Data.lua from wago.tools DB2 CSV files.
"""

import argparse
import csv
import math
import os
import sys
from collections import defaultdict

# ---------------------------------------------------------------------------
# effect labels.. to do: fix and add more
# ---------------------------------------------------------------------------

# maps (Effect, EffectAura) > player-facing label.
# EffectAura 0 means "not an aura effect" (direct damage, heal, etc.)
HUMAN_LABELS = {
    # direct effects (EffectAura = 0)
    (2, 0):    "Damage",
    (10, 0):   "Healing",
    (30, 0):   "Resource gen",
    (9, 0):    "Mana burn",
    (31, 0):   "Weapon dmg",
    (98, 0):   "Weapon dmg",
    (64, 0):   "Trigger",
    (67, 0):   "Max HP heal",
    (136, 0):  "% heal",
    (137, 0):  "% resource gen",
    (3, 0):    "Value",
    (28, 0):   "Summon",
    (96, 0):   "Activate rune",
    # Apply Aura effects (Effect = 6, keyed by EffectAura)
    (6, 3):    "DoT",
    (6, 7):    "Charm",
    (6, 8):    "HoT",
    (6, 12):   "Stun",
    (6, 13):   "Root",
    (6, 14):   "Confuse",
    (6, 20):   "Resistance",
    (6, 21):   "Ranged atk speed",
    (6, 23):   "Stealth",
    (6, 24):   "Stealth detect",
    (6, 26):   "Flee",
    (6, 27):   "Charm",
    (6, 30):   "Melee speed",
    (6, 31):   "Attack speed",
    (6, 33):   "Resistance",
    (6, 34):   "Snare",
    (6, 42):   "Proc",
    (6, 43):   "Proc (hit)",
    (6, 47):   "Parry %",
    (6, 50):   "Silence",
    (6, 53):   "Block %",
    (6, 56):   "Dodge %",
    (6, 61):   "Ranged haste",
    (6, 64):   "Slow fall",
    (6, 65):   "Pacify",
    (6, 69):   "Absorb",
    (6, 70):   "Absorb (school)",
    (6, 4):    "Effect",
    (6, 79):   "Dmg done %",
    (6, 80):   "Health regen",
    (6, 85):   "Power regen",
    (6, 87):   "Dmg taken %",
    (6, 89):   "Speed %",
    (6, 99):   "Parry",
    (6, 101):  "Immunity",
    (6, 110):  "Spell immune",
    (6, 118):  "Heal taken %",
    (6, 129):  "Waterbreath",
    (6, 133):  "Melee atk pwr",
    (6, 136):  "Ranged atk pwr",
    (6, 137):  "Stat %",
    (6, 138):  "Crit heal %",
    (6, 142):  "Resist %",
    (6, 148):  "Mastery (blood)",
    (6, 163):  "Swim speed",
    (6, 168):  "Armor pen",
    (6, 172):  "Mounted speed",
    (6, 189):  "All dmg %",
    (6, 191):  "Resist push",
    (6, 193):  "Haste",
    (6, 200):  "Expertise",
    (6, 211):  "Dmg done flat",
    (6, 216):  "Mana shield",
    (6, 218):  "Power cost",
    (6, 219):  "Dmg vs creature",
    (6, 220):  "Crit vs creature",
    (6, 226):  "Periodic effect",
    (6, 231):  "Casting speed",
    (6, 232):  "CC duration",
    (6, 236):  "Melee haste",
    (6, 245):  "Cooldown mod",
    (6, 250):  "Duration mod",
    (6, 260):  "Heal absorb",
    (6, 269):  "Dmg taken flat",
    (6, 270):  "Dmg taken % caster",
    (6, 271):  "Dmg from caster",
    (6, 274):  "Ignore armor",
    (6, 277):  "Redirect threat",
    (6, 283):  "Dmg taken % multi",
    (6, 286):  "Mana regen",
    (6, 290):  "Crit chance",
    (6, 291):  "Crit from caster",
    (6, 293):  "Crit dmg %",
    (6, 306):  "Fly",
    (6, 308):  "Haste (melee)",
    (6, 318):  "Mastery",
    (6, 319):  "Melee speed",
    (6, 339):  "Move speed cap",
    (6, 341):  "Versatility",
    (6, 342):  "Versatility %",
    (6, 343):  "Leech",
    (6, 344):  "Auto attack %",
    (6, 355):  "Dmg done % caster",
    (6, 361):  "Haste (all)",
    (6, 381):  "Absorb % caster",
    (6, 382):  "Absorb % multi",
    (6, 395):  "Versatility dmg",
    (6, 411):  "Heal done %",
    (6, 419):  "Versatility %",
    (6, 422):  "Max HP %",
    (6, 429):  "Pet dmg %",
    (6, 443):  "Crit %",
    (6, 453):  "Crit dmg bonus",
    (6, 454):  "Crit heal bonus",
    (6, 465):  "Max charges",
    (6, 471):  "Versatility %",
    (6, 485):  "Armor %",
    (6, 501):  "Slow",
    (6, 530):  "Ignore speed limit",
    (6, 531):  "Guardian dmg %",
    (6, 537):  "Move speed flat",
    (6, 540):  "Primary stat %",
    (6, 542):  "Crit reduction",
    (6, 643):  "Periodic dmg taken",
    (6, 29):   "Stat mod",
    # apply area aura variants use same labels
    (35, 3):   "DoT",
    (35, 8):   "HoT",
    (35, 69):  "Absorb",
    (35, 4):   "Effect",
    (65, 3):   "DoT",
    (65, 8):   "HoT",
    (65, 69):  "Absorb",
    (65, 4):   "Effect",
    (174, 3):  "DoT",
    (174, 8):  "HoT",
    (174, 69): "Absorb",
}

# modifier subtypes for aura types 107 (Flat Modifier), 108 (Pct Modifier), 285 (Flat Modifier 2)
# these describe WHAT property of other spells is being modified.
MODIFIER_SUBTYPES = {
    0:  "Spell power",
    1:  "Duration",
    2:  "Charges",
    3:  "Range",
    5:  "Cost",
    7:  "Crit chance",
    8:  "Pushback",
    10: "Cast time",
    11: "Cooldown",
    14: "Damage",
    15: "Healing",
    16: "GCD",
    17: "Max duration",
    22: "Periodic",
    29: "Crit bonus",
}

# fallback: effect type names for types not in HUMAN_LABELS
EFFECT_NAMES = {
    2: "Damage", 3: "Value", 6: "Aura", 9: "Mana burn", 10: "Healing",
    24: "Create Item", 28: "Summon", 30: "Resource gen", 31: "Weapon dmg",
    32: "Create Item", 35: "Area Aura", 64: "Trigger", 65: "Party Aura",
    67: "Max HP heal", 96: "Activate rune", 98: "Weapon dmg",
    136: "% heal", 137: "% resource gen", 174: "Summon Aura",
}

# fallback: aura type names
AURA_NAMES = {
    3: "DoT", 4: "Passive", 8: "HoT", 12: "Stun", 29: "Stat",
    42: "Proc", 69: "Absorb", 79: "Dmg %", 87: "Dmg taken %",
    107: "Flat mod", 108: "Pct mod", 118: "Heal taken %",
    137: "Stat %", 189: "All dmg %", 193: "Haste", 218: "Power cost",
    219: "Dmg vs creature", 226: "Periodic passive", 232: "CC duration",
    271: "Dmg from caster", 285: "Flat mod", 290: "Crit chance",
    344: "Auto atk %", 429: "Pet dmg %", 465: "Max charges",
    531: "Guardian dmg %", 647: "PvP Modifier", 649: "PvP Modifier (Label)",
}

# SpellClassSet > class family name
CLASS_FAMILIES = {
    3: "Mage", 4: "Warrior", 5: "Warlock", 6: "Priest",
    7: "Druid", 8: "Rogue", 9: "Hunter", 10: "Paladin",
    11: "Shaman", 13: "Monk", 15: "Death Knight", 33: "Demon Hunter",
    53: "Evoker",
}

# ClassID (from ChrSpecialization) > class name
CLASS_NAMES = {
    1: "Warrior", 2: "Paladin", 3: "Hunter", 4: "Rogue",
    5: "Priest", 6: "Death Knight", 7: "Shaman", 8: "Mage",
    9: "Warlock", 10: "Monk", 11: "Druid", 12: "Demon Hunter",
    13: "Evoker",
}

# ClassID > SpellClassSet mapping
CLASS_TO_FAMILY = {
    1: 4, 2: 10, 3: 9, 4: 8, 5: 6, 6: 15, 7: 7, 8: 3,
    9: 5, 10: 13, 11: 7, 12: 33, 13: 53,
}


# ---------------------------------------------------------------------------
# CSV loading
# ---------------------------------------------------------------------------

def load_csv(path):
    """Load a CSV file and return a list of dicts."""
    with open(path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        return list(reader)


# school mask > short school name
SCHOOL_NAMES = {
    1: "Physical", 2: "Holy", 4: "Fire", 8: "Nature",
    16: "Frost", 32: "Shadow", 64: "Arcane",
    # multi-school (pick dominant)
    3: "Holystrike", 5: "Flamestrike", 6: "Radiant",
    9: "Stormstrike", 10: "Holystorm", 12: "Volcanic",
    17: "Froststrike", 20: "Frostfire", 28: "Elemental",
    33: "Shadowstrike", 34: "Twilight", 36: "Shadowflame",
    40: "Plague", 48: "Shadowfrost", 96: "Spellshadow",
    124: "Chromatic", 126: "Magic", 127: "Chaos",
}


# ---------------------------------------------------------------------------
# effect description builder
# ---------------------------------------------------------------------------

def build_effect_description(effect_type, aura_type, misc_value_0,
                             school_mask=0, mechanic_id=0, mechanic_names=None):
    """Return a human-readable label for a spell effect.

    Args:
        effect_type: int from SpellEffect.Effect column
        aura_type: int from SpellEffect.EffectAura column
        misc_value_0: int from SpellEffect.EffectMiscValue_0 column
        school_mask: int from SpellMisc.SchoolMask (for damage/heal school)
        mechanic_id: int from SpellEffect.EffectMechanic column
        mechanic_names: dict from SpellMechanic {id: name}

    Returns:
        str: Human-readable label like "Fire damage", "DoT (bleeding)", etc.
    """
    # modifier auras: describe what property is being modified
    if effect_type in (6, 35, 65, 174) and aura_type in (107, 108, 285):
        subtype = MODIFIER_SUBTYPES.get(misc_value_0)
        if subtype:
            return subtype
        return "Modifier"

    # direct lookup
    key = (effect_type, aura_type)
    label = HUMAN_LABELS.get(key)

    if not label:
        # for Apply Aura with unknown aura type, use aura name
        if effect_type in (6, 35, 65, 174) and aura_type != 0:
            label = AURA_NAMES.get(aura_type, f"Aura #{aura_type}")
        else:
            label = EFFECT_NAMES.get(effect_type, f"Effect #{effect_type}")

    # enrich damage/heal/DoT/HoT labels with school name
    if label in ("Damage", "Weapon dmg") and school_mask > 0:
        school = SCHOOL_NAMES.get(school_mask)
        if school and school != "Physical":
            label = f"{school} {label.lower()}"
    elif label == "DoT" and school_mask > 0:
        school = SCHOOL_NAMES.get(school_mask)
        if school:
            label = f"{school} DoT"

    # append mechanic name for context
    if mechanic_id > 0 and mechanic_names:
        mech_name = mechanic_names.get(mechanic_id)
        if mech_name and mech_name.lower() not in label.lower():
            label = f"{label} ({mech_name})"

    return label


# ---------------------------------------------------------------------------
# data building functions
# ---------------------------------------------------------------------------

def build_mechanic_names(rows):
    """SpellMechanic.csv > {mechanic_id: name}"""
    mechs = {}
    for r in rows:
        mid = int(r["ID"])
        name = r["StateName_lang"]
        if name:
            mechs[mid] = name
    return mechs


def build_spell_schools(rows):
    """SpellMisc.csv > {spell_id: school_mask}"""
    schools = {}
    for r in rows:
        spell_id = int(r["SpellID"])
        mask = int(r["SchoolMask"])
        if mask > 0:
            schools[spell_id] = mask
    return schools


def build_spell_names(rows):
    """SpellName.csv > {spell_id: name}"""
    names = {}
    for r in rows:
        sid = int(r["ID"])
        name = r["Name_lang"]
        if name:
            names[sid] = name
    return names


def build_class_options(rows):
    """SpellClassOptions.csv > {spell_id: {family, masks}}"""
    options = {}
    for r in rows:
        sid = int(r["SpellID"])
        family = int(r["SpellClassSet"])
        masks = [
            int(r["SpellClassMask_0"]),
            int(r["SpellClassMask_1"]),
            int(r["SpellClassMask_2"]),
            int(r["SpellClassMask_3"]),
        ]
        options[sid] = {"family": family, "masks": masks}
    return options


def build_specs(rows):
    """ChrSpecialization.csv > {spec_id: {name, class_id}}"""
    specs = {}
    for r in rows:
        sid = int(r["ID"])
        class_id = int(r["ClassID"])
        name = r["Name_lang"]
        if class_id > 0:  # skip pet specs
            specs[sid] = {"name": name, "class_id": class_id}
    return specs


def build_spec_spells_map(rows):
    """SpecializationSpells.csv > {spec_id: [spell_id, ...]}"""
    mapping = defaultdict(list)
    for r in rows:
        spec_id = int(r["SpecID"])
        spell_id = int(r["SpellID"])
        mapping[spec_id].append(spell_id)
    return dict(mapping)


def build_label_map(rows):
    """SpellLabel.csv > {label_id: [spell_id, ...]}"""
    labels = defaultdict(list)
    for r in rows:
        label_id = int(r["LabelID"])
        spell_id = int(r["SpellID"])
        labels[label_id].append(spell_id)
    return dict(labels)


def filter_pvp_effects(effect_rows):
    """Filter SpellEffect rows to those with PvpMultiplier != 1.0 and DifficultyID == 0."""
    results = []
    for r in effect_rows:
        diff = int(r["DifficultyID"])
        if diff != 0:
            continue
        try:
            pvp_mult = float(r["PvpMultiplier"])
        except (ValueError, KeyError):
            continue
        if abs(pvp_mult - 1.0) > 0.0001:
            results.append(r)
    return results


def filter_mod_aura_effects(effect_rows):
    """Filter SpellEffect rows to EffectAura 647 or 649 (PvP modifier auras)."""
    results = []
    for r in effect_rows:
        diff = int(r["DifficultyID"])
        if diff != 0:
            continue
        aura = int(r["EffectAura"])
        if aura in (647, 649):
            results.append(r)
    return results


def build_spell_context(all_effect_rows):
    """Build a context map of what each spell does based on ALL its effects.

    For spells with generic "Value" or "Effect" PvP-modified effects, we look
    at sibling effects to infer what the generic effect actually controls.

    Returns: {spell_id: [list of (effect_type, aura_type) for all effects]}
    """
    context = defaultdict(list)
    for r in all_effect_rows:
        if int(r["DifficultyID"]) != 0:
            continue
        spell_id = int(r["SpellID"])
        effect_type = int(r["Effect"])
        aura_type = int(r["EffectAura"])
        context[spell_id].append((effect_type, aura_type))
    return dict(context)


# maps a sibling aura type to a contextual label for a generic effect
_CONTEXT_LABELS = {
    3: "DoT value",        # sibling is periodic damage
    8: "HoT value",        # sibling is periodic heal
    12: "Stun value",      # sibling is stun (e.g. Kidney Shot)
    13: "Root value",
    69: "Absorb value",    # sibling is absorb (e.g. Ice Barrier)
    79: "Dmg bonus",       # sibling is damage done %
    87: "Mitigation",      # sibling is damage taken %
    118: "Heal bonus",
    137: "Stat bonus",     # sibling is stat %
    189: "Dmg bonus",
    193: "Haste bonus",
    232: "CC value",
}


def infer_context_label(spell_id, spell_context):
    """try to infer what a generic "Value" or "Effect" entry does based on
    the spell's other effects.

    returns a contextual label or None if no inference is possible.
    """
    siblings = spell_context.get(spell_id, [])
    # look for the most descriptive sibling effect
    for _, aura_type in siblings:
        if aura_type in _CONTEXT_LABELS:
            return _CONTEXT_LABELS[aura_type]
    # check for direct damage/heal siblings
    for eff_type, _ in siblings:
        if eff_type == 2:
            return "Dmg value"
        if eff_type == 10:
            return "Heal value"
    return None


def build_spells_table(pvp_effects, spell_names, class_options, spell_context,
                       spell_schools=None, mechanic_names=None):
    """build the main Spells table from PvP-modified effects.

    returns: {spell_id: {n: name, c: class_family, e: [{i, t, p}, ...]}}
    """
    spell_schools = spell_schools or {}
    mechanic_names = mechanic_names or {}

    spells = {}
    for r in pvp_effects:
        spell_id = int(r["SpellID"])
        effect_idx = int(r["EffectIndex"])
        effect_type = int(r["Effect"])
        aura_type = int(r["EffectAura"])
        misc_val_0 = int(r["EffectMiscValue_0"])
        pvp_mult = float(r["PvpMultiplier"])
        mechanic_id = int(r.get("EffectMechanic", 0))

        # skip EffectAura 647/649 - those go into PvpModAuras table
        if aura_type in (647, 649):
            continue

        school_mask = spell_schools.get(spell_id, 0)
        label = build_effect_description(
            effect_type, aura_type, misc_val_0,
            school_mask=school_mask, mechanic_id=mechanic_id,
            mechanic_names=mechanic_names,
        )

        # for generic labels, try to infer from sibling effects
        if label in ("Value", "Effect"):
            ctx = infer_context_label(spell_id, spell_context)
            if ctx:
                label = ctx

        if spell_id not in spells:
            name = spell_names.get(spell_id, f"Spell #{spell_id}")
            family = class_options.get(spell_id, {}).get("family", 0)
            spells[spell_id] = {"n": name, "c": family, "e": []}

        spells[spell_id]["e"].append({
            "i": effect_idx,
            "t": label,
            "p": pvp_mult,
        })

    # sort effects by index within each spell
    for spell in spells.values():
        spell["e"].sort(key=lambda x: x["i"])

    return spells


# super to do trigger resolution... not working yet
def build_parent_spells(all_effect_rows, spells_table, spell_replacements=None):
    """find parent>child spell relationships via trigger effects and spell replacements.

    trigger effects: Effect=64 (Trigger Spell), 136 (Trigger Missile),
    140 (Trigger Spell With Value).

    spell replacements: SpellReplacement.csv maps old > new spell IDs.
    SpellLearnSpell.csv maps learned spells that override others.

    returns: {parent_spell_id: [child_spell_id, ...]}
    """
    TRIGGER_EFFECTS = {64, 136, 140}
    parents = defaultdict(set)

    for r in all_effect_rows:
        effect_type = int(r["Effect"])
        if effect_type not in TRIGGER_EFFECTS:
            continue
        trigger_spell = int(r.get("EffectTriggerSpell", 0))
        if trigger_spell == 0:
            continue
        if trigger_spell in spells_table:
            parent_id = int(r["SpellID"])
            if parent_id not in spells_table:  # only if parent isn't already tracked
                parents[parent_id].add(trigger_spell)

    # add replacement chains: if spell A replaces spell B and B has PvP data,
    # then A is a parent of B (so hovering the replacement shows the PvP info)
    if spell_replacements:
        for original_id, replacement_id in spell_replacements.items():
            if original_id in spells_table and replacement_id not in spells_table:
                parents[replacement_id].add(original_id)
            elif replacement_id in spells_table and original_id not in spells_table:
                parents[original_id].add(replacement_id)

    return {k: sorted(v) for k, v in parents.items() if v}


def build_mod_auras(mod_aura_effects, spell_names, class_options):
    """build the PvpModAuras table from EffectAura 647/649 effects.

    returns: {spell_id: {n, c, mods: [{value, masks}], labelMods: [{value, label_id}]}}
    """
    auras = {}
    for r in mod_aura_effects:
        spell_id = int(r["SpellID"])
        aura_type = int(r["EffectAura"])
        base_value = float(r["EffectBasePointsF"])
        misc_val_0 = int(r["EffectMiscValue_0"])
        misc_val_1 = int(r["EffectMiscValue_1"])

        if spell_id not in auras:
            name = spell_names.get(spell_id, f"Spell #{spell_id}")
            family = class_options.get(spell_id, {}).get("family", 0)
            auras[spell_id] = {"n": name, "c": family, "mods": [], "labelMods": []}

        if aura_type == 647:
            masks = [
                int(r["EffectSpellClassMask_0"]),
                int(r["EffectSpellClassMask_1"]),
                int(r["EffectSpellClassMask_2"]),
                int(r["EffectSpellClassMask_3"]),
            ]
            # misc_val_0 for 647: 0 = direct, 1 = periodic (typically)
            mod_type = "periodic" if misc_val_0 == 1 else "amount"
            auras[spell_id]["mods"].append({
                "type": mod_type,
                "value": base_value,
                "masks": masks,
            })
        elif aura_type == 649:
            label_id = misc_val_1
            auras[spell_id]["labelMods"].append({
                "value": base_value,
                "label_id": label_id,
            })

    return auras


def masks_match(spell_masks, aura_masks):
    """Check if a spell's class masks intersect with an aura's target masks."""
    for i in range(4):
        # handle signed 32-bit integers from CSV
        sm = spell_masks[i] & 0xFFFFFFFF
        am = aura_masks[i] & 0xFFFFFFFF
        if sm & am:
            return True
    return False


def build_spell_mod_lookup(mod_auras, spells_table, class_options, label_map):
    """Build reverse index: spell_id > [{aura_spell_id, type, value}].

    For each modifier aura, find which spells it affects by mask matching
    (for 647) or label matching (for 649).
    """
    lookup = defaultdict(list)

    for aura_spell_id, aura_data in mod_auras.items():
        aura_family = aura_data["c"]

        # process 647 mods (SpellClassMask-based)
        for mod in aura_data["mods"]:
            aura_masks = mod["masks"]
            mod_type = mod["type"]
            mod_value = mod["value"]

            for spell_id in spells_table:
                spell_opts = class_options.get(spell_id)
                if not spell_opts:
                    continue
                if spell_opts["family"] != aura_family:
                    continue
                if masks_match(spell_opts["masks"], aura_masks):
                    lookup[spell_id].append({
                        "aura": aura_spell_id,
                        "type": mod_type,
                        "value": mod_value,
                    })

        # process 649 mods (label-based)
        for lmod in aura_data["labelMods"]:
            label_id = lmod["label_id"]
            mod_value = lmod["value"]
            target_spells = label_map.get(label_id, [])
            for spell_id in target_spells:
                if spell_id in spells_table:
                    lookup[spell_id].append({
                        "aura": aura_spell_id,
                        "type": "label",
                        "value": mod_value,
                    })

    return dict(lookup)


def build_spell_replacements(rows):
    """SpellReplacement.csv > {original_spell_id: replacement_spell_id}"""
    replacements = {}
    for r in rows:
        original = int(r["SpellID"])
        replacement = int(r["ReplacementSpellID"])
        replacements[original] = replacement
    return replacements


def build_spell_learn_overrides(rows):
    """SpellLearnSpell.csv > {overridden_spell_id: learned_spell_id}

    Only entries with OverridesSpellID > 0 are relevant.
    """
    overrides = {}
    for r in rows:
        overridden = int(r["OverridesSpellID"])
        learned = int(r["LearnSpellID"])
        if overridden > 0:
            overrides[overridden] = learned
    return overrides


# ---------------------------------------------------------------------------
# item & enchantment builders
# ---------------------------------------------------------------------------


def build_item_effects(item_effect_rows, item_x_item_effect_rows):
    """Join ItemEffect + ItemXItemEffect to produce {item_id: [spell_id, ...]}."""
    # map ItemEffectID -> spell_id
    effect_spells = {}
    for r in item_effect_rows:
        effect_id = int(r["ID"])
        spell_id = int(r.get("SpellID", 0))
        if spell_id > 0:
            effect_spells[effect_id] = spell_id

    # map item_id -> [spell_id, ...]
    item_spells = defaultdict(set)
    for r in item_x_item_effect_rows:
        item_id = int(r["ItemID"])
        effect_id = int(r["ItemEffectID"])
        spell_id = effect_spells.get(effect_id)
        if spell_id:
            item_spells[item_id].add(spell_id)

    return {k: sorted(v) for k, v in item_spells.items()}


def build_pvp_item_spells(item_effects, spells_table, parent_spells):
    """Filter item->spell mappings to only items with PvP-relevant spells.

    Returns: {item_id: [spell_id, ...]}
    """
    all_pvp = set(spells_table.keys()) | set(parent_spells.keys())
    result = {}
    for item_id, spell_ids in item_effects.items():
        pvp_spells = [sid for sid in spell_ids if sid in all_pvp]
        if pvp_spells:
            result[item_id] = pvp_spells
    return result


def build_enchantment_spells(enchantment_rows):
    """Extract spell IDs from SpellItemEnchantment effects.

    Enchantments have up to 3 effects (Effect_0, Effect_1, Effect_2).
    Effect type 3 = "Apply Spell" (EffectArg is the spell ID).
    Effect type 1 = "Proc on Hit" (EffectArg is the spell ID).

    Returns: {enchant_id: {n: name, spells: [spell_id, ...]}}
    """
    SPELL_EFFECT_TYPES = {1, 3}  # proc-on-hit, apply-spell
    enchants = {}
    for r in enchantment_rows:
        eid = int(r["ID"])
        name = r.get("Name_lang", f"Enchant #{eid}")
        spells = set()
        for i in range(3):
            etype = int(r.get(f"Effect_{i}", 0))
            earg = int(r.get(f"EffectArg_{i}", 0))
            if etype in SPELL_EFFECT_TYPES and earg > 0:
                spells.add(earg)
        if spells:
            enchants[eid] = {"n": name, "spells": sorted(spells)}
    return enchants


def build_pvp_enchantments(enchantments, spells_table, parent_spells):
    """Filter enchantments to only those with PvP-relevant spells.

    Returns: {enchant_id: {n: name, spells: [spell_id, ...]}}
    """
    all_pvp = set(spells_table.keys()) | set(parent_spells.keys())
    result = {}
    for eid, data in enchantments.items():
        pvp_spells = [sid for sid in data["spells"] if sid in all_pvp]
        if pvp_spells:
            result[eid] = {"n": data["n"], "spells": pvp_spells}
    return result


def build_aura_options(aura_option_rows, spells_table):
    """Extract diminishing returns and dispel type for PvP-relevant spells.

    Returns: {spell_id: {dr: diminish_type, dispel: dispel_type}}
    """
    DR_TYPES = {
        1: "Stun", 2: "Disorient", 3: "Silence", 4: "Incapacitate",
        5: "Root", 6: "Fear", 7: "Knockback",
    }
    DISPEL_TYPES = {
        0: "None", 1: "Magic", 2: "Curse", 3: "Disease",
        4: "Poison", 5: "Stealth", 6: "Invisibility",
        9: "Enrage",
    }
    result = {}
    for r in aura_option_rows:
        spell_id = int(r.get("SpellID", 0))
        if spell_id not in spells_table:
            continue
        dr = int(r.get("DiminishType", 0))
        dispel = int(r.get("DispelType", 0))
        if dr > 0 or dispel > 0:
            entry = {}
            if dr > 0:
                entry["dr"] = DR_TYPES.get(dr, f"DR#{dr}")
            if dispel > 0:
                entry["dispel"] = DISPEL_TYPES.get(dispel, f"Dispel#{dispel}")
            result[spell_id] = entry
    return result


# playable class IDs (filters out Adventurer etc. from ChrSpecialization)
PLAYABLE_CLASS_IDS = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}


def build_classes_table(specs):
    """Build Classes table: {class_id: {n: name, s: {spec_id: spec_name}}}

    Only includes playable classes (filters out Adventurer, etc.).
    """
    classes = {}
    for spec_id, spec_data in specs.items():
        cid = spec_data["class_id"]
        if cid not in PLAYABLE_CLASS_IDS:
            continue
        if cid not in classes:
            classes[cid] = {"n": CLASS_NAMES.get(cid, f"Class #{cid}"), "s": {}}
        classes[cid]["s"][spec_id] = spec_data["name"]
    return classes


def build_spec_spells_filtered(spec_spells_map, spells_table, parent_spells):
    """Filter spec>spell mappings to only include spells with PvP data.

    Returns: {spec_id: [spell_id, ...]}
    """
    all_pvp_spells = set(spells_table.keys()) | set(parent_spells.keys())
    result = {}
    for spec_id, spell_ids in spec_spells_map.items():
        pvp_spells = [sid for sid in spell_ids if sid in all_pvp_spells]
        if pvp_spells:
            result[spec_id] = sorted(pvp_spells)
    return result


# ---------------------------------------------------------------------------
# lua output
# ---------------------------------------------------------------------------

def lua_string(s):
    """Escape a string for Lua."""
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def lua_float(val):
    """Format a float for Lua output, trimming unnecessary precision."""
    # round to 5 decimal places to avoid float noise
    rounded = round(val, 5)
    if rounded == int(rounded):
        return str(int(rounded))
    # remove trailing zeros
    return f"{rounded:.5f}".rstrip("0").rstrip(".")


def write_data_lua(path, spells, parents, mod_auras, mod_lookup,
                   classes, spec_spells, build_version, spell_replacements=None,
                   item_spells=None, enchant_spells=None, aura_options=None):
    """Write all data tables to Data.lua."""
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- PvPTip Data.lua — AUTO-GENERATED, DO NOT EDIT\n")
        f.write(f'-- Build: {build_version}\n')
        f.write(f'-- Spells: {len(spells)}, Mod Auras: {len(mod_auras)}, ')
        f.write(f'Parents: {len(parents)}\n\n')
        f.write("PvPTipData = PvPTipData or {}\n\n")

        # build version
        f.write(f'PvPTipData.Build = "{lua_string(build_version)}"\n\n')

        # spells table
        f.write(f"PvPTipData.Spells = {{\n")
        for spell_id in sorted(spells.keys()):
            spell = spells[spell_id]
            name = lua_string(spell["n"])
            family = spell["c"]
            effects_parts = []
            for eff in spell["e"]:
                t = lua_string(eff["t"])
                p = eff["p"]
                effects_parts.append(f'{{i={eff["i"]},t="{t}",p={lua_float(p)}}}')
            effects_str = ",".join(effects_parts)
            f.write(f'  [{spell_id}]={{n="{name}",c={family},e={{{effects_str}}}}},\n')
        f.write("}\n\n")

        # SpellParents table
        f.write(f"PvPTipData.SpellParents = {{\n")
        for parent_id in sorted(parents.keys()):
            children = parents[parent_id]
            children_str = ",".join(str(c) for c in children)
            f.write(f"  [{parent_id}]={{{children_str}}},\n")
        f.write("}\n\n")

        # PvpModAuras table
        f.write(f"PvPTipData.PvpModAuras = {{\n")
        for aura_id in sorted(mod_auras.keys()):
            aura = mod_auras[aura_id]
            name = lua_string(aura["n"])
            family = aura["c"]
            # mods
            mods_parts = []
            for mod in aura["mods"]:
                masks_str = ",".join(str(m) for m in mod["masks"])
                mods_parts.append(
                    f'{{type="{mod["type"]}",value={lua_float(mod["value"])},masks={{{masks_str}}}}}'
                )
            mods_str = ",".join(mods_parts)
            # labelMods
            lmods_parts = []
            for lm in aura["labelMods"]:
                lmods_parts.append(f'{{value={lua_float(lm["value"])},labelID={lm["label_id"]}}}')
            lmods_str = ",".join(lmods_parts)

            f.write(f'  [{aura_id}]={{n="{name}",c={family},'
                    f'mods={{{mods_str}}},labelMods={{{lmods_str}}}}},\n')
        f.write("}\n\n")

        # SpellModLookup table
        f.write(f"PvPTipData.SpellModLookup = {{\n")
        for spell_id in sorted(mod_lookup.keys()):
            entries = mod_lookup[spell_id]
            parts = []
            for e in entries:
                parts.append(f'{{{e["aura"]},"{e["type"]}",{lua_float(e["value"])}}}')
            entries_str = ",".join(parts)
            f.write(f"  [{spell_id}]={{{entries_str}}},\n")
        f.write("}\n\n")

        # SpellReplacements table (original > replacement, for runtime override resolution)
        if spell_replacements:
            # only emit replacements where at least one side has PvP data
            all_pvp = set(spells.keys()) | set(parents.keys())
            relevant = {k: v for k, v in spell_replacements.items()
                        if k in all_pvp or v in all_pvp}
            if relevant:
                f.write(f"PvPTipData.SpellReplacements = {{\n")
                for orig in sorted(relevant.keys()):
                    f.write(f"  [{orig}]={relevant[orig]},\n")
                f.write("}\n\n")

        # classes table
        f.write("PvPTipData.Classes = {\n")
        for cid in sorted(classes.keys()):
            cls = classes[cid]
            name = lua_string(cls["n"])
            specs_parts = []
            for sid in sorted(cls["s"].keys()):
                sname = lua_string(cls["s"][sid])
                specs_parts.append(f'[{sid}]="{sname}"')
            specs_str = ",".join(specs_parts)
            f.write(f'  [{cid}]={{n="{name}",s={{{specs_str}}}}},\n')
        f.write("}\n\n")

        # SpecSpells table
        f.write("PvPTipData.SpecSpells = {\n")
        for spec_id in sorted(spec_spells.keys()):
            spells_list = spec_spells[spec_id]
            spells_str = ",".join(str(s) for s in spells_list)
            f.write(f"  [{spec_id}]={{{spells_str}}},\n")
        f.write("}\n\n")

        # ItemSpells table (item_id -> list of PvP-relevant spell IDs)
        if item_spells:
            f.write(f"PvPTipData.ItemSpells = {{\n")
            for item_id in sorted(item_spells.keys()):
                spell_ids = item_spells[item_id]
                spells_str = ",".join(str(s) for s in spell_ids)
                f.write(f"  [{item_id}]={{{spells_str}}},\n")
            f.write("}\n\n")

        # EnchantSpells table (enchant_id -> {n=name, spells={...}})
        if enchant_spells:
            f.write(f"PvPTipData.EnchantSpells = {{\n")
            for eid in sorted(enchant_spells.keys()):
                data = enchant_spells[eid]
                name = lua_string(data["n"])
                spells_str = ",".join(str(s) for s in data["spells"])
                f.write(f'  [{eid}]={{n="{name}",spells={{{spells_str}}}}},\n')
            f.write("}\n\n")

        # AuraOptions table (spell_id -> {dr=type, dispel=type})
        if aura_options:
            f.write(f"PvPTipData.AuraOptions = {{\n")
            for spell_id in sorted(aura_options.keys()):
                opts = aura_options[spell_id]
                parts = []
                if "dr" in opts:
                    parts.append(f'dr="{lua_string(opts["dr"])}"')
                if "dispel" in opts:
                    parts.append(f'dispel="{lua_string(opts["dispel"])}"')
                f.write(f"  [{spell_id}]={{{','.join(parts)}}},\n")
            f.write("}\n")

    return True


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate PvPTip Data.lua from DB2 CSVs"
    )
    parser.add_argument(
        "--db2",
        default=os.path.join(os.path.dirname(__file__), "..", "..", "db2_raw"),
        help="Path to db2_raw/ directory containing CSVs",
    )
    parser.add_argument(
        "--output",
        default=os.path.join(os.path.dirname(__file__), "..", "Data.lua"),
        help="Output path for Data.lua",
    )
    args = parser.parse_args()

    db2 = args.db2

    # read build version (first line only - download_all_db2.py adds stats on subsequent lines)
    build_file = os.path.join(db2, "build_info.txt")
    if os.path.exists(build_file):
        with open(build_file) as f:
            build_version = f.readline().strip()
    else:
        build_version = "unknown"

    print(f"Build: {build_version}")
    print(f"DB2 path: {db2}")
    print(f"Output: {args.output}")
    print()

    # Load CSVs
    print("Loading CSVs...")
    effect_rows = load_csv(os.path.join(db2, "SpellEffect.csv"))
    print(f"  SpellEffect: {len(effect_rows):,} rows")

    name_rows = load_csv(os.path.join(db2, "SpellName.csv"))
    spell_names = build_spell_names(name_rows)
    print(f"  SpellName: {len(spell_names):,} names")

    class_opt_rows = load_csv(os.path.join(db2, "SpellClassOptions.csv"))
    class_options = build_class_options(class_opt_rows)
    print(f"  SpellClassOptions: {len(class_options):,} entries")

    spec_rows = load_csv(os.path.join(db2, "ChrSpecialization.csv"))
    specs = build_specs(spec_rows)
    print(f"  ChrSpecialization: {len(specs):,} specs")

    spec_spell_rows = load_csv(os.path.join(db2, "SpecializationSpells.csv"))
    spec_spells_map = build_spec_spells_map(spec_spell_rows)
    print(f"  SpecializationSpells: {len(spec_spell_rows):,} mappings")

    label_rows = load_csv(os.path.join(db2, "SpellLabel.csv"))
    label_map = build_label_map(label_rows)
    print(f"  SpellLabel: {len(label_map):,} labels")

    # load SpellMechanic (mechanic ID > name like "stunned", "bleeding")
    mechanic_path = os.path.join(db2, "SpellMechanic.csv")
    mechanic_names = {}
    if os.path.exists(mechanic_path):
        mech_rows = load_csv(mechanic_path)
        mechanic_names = build_mechanic_names(mech_rows)
        print(f"  SpellMechanic: {len(mechanic_names):,} mechanics")

    # load SpellMisc (spell ID > school mask)
    misc_path = os.path.join(db2, "SpellMisc.csv")
    spell_schools = {}
    if os.path.exists(misc_path):
        misc_rows = load_csv(misc_path)
        spell_schools = build_spell_schools(misc_rows)
        print(f"  SpellMisc: {len(spell_schools):,} spells with school masks")

    # load SpellReplacement (spell override chains)
    replacement_path = os.path.join(db2, "SpellReplacement.csv")
    spell_replacements = {}
    if os.path.exists(replacement_path):
        repl_rows = load_csv(replacement_path)
        spell_replacements = build_spell_replacements(repl_rows)
        print(f"  SpellReplacement: {len(spell_replacements):,} replacements")

    # load SpellLearnSpell (spell learn/override chains)
    learn_path = os.path.join(db2, "SpellLearnSpell.csv")
    spell_learn_overrides = {}
    if os.path.exists(learn_path):
        learn_rows = load_csv(learn_path)
        spell_learn_overrides = build_spell_learn_overrides(learn_rows)
        print(f"  SpellLearnSpell: {len(spell_learn_overrides):,} overrides")

    # load item & enchantment tables
    item_effect_rows = []
    item_effect_path = os.path.join(db2, "ItemEffect.csv")
    if os.path.exists(item_effect_path):
        item_effect_rows = load_csv(item_effect_path)
        print(f"  ItemEffect: {len(item_effect_rows):,} rows")

    item_x_rows = []
    item_x_path = os.path.join(db2, "ItemXItemEffect.csv")
    if os.path.exists(item_x_path):
        item_x_rows = load_csv(item_x_path)
        print(f"  ItemXItemEffect: {len(item_x_rows):,} rows")

    enchant_rows = []
    enchant_path = os.path.join(db2, "SpellItemEnchantment.csv")
    if os.path.exists(enchant_path):
        enchant_rows = load_csv(enchant_path)
        print(f"  SpellItemEnchantment: {len(enchant_rows):,} rows")

    aura_opt_rows = []
    aura_opt_path = os.path.join(db2, "SpellAuraOptions.csv")
    if os.path.exists(aura_opt_path):
        aura_opt_rows = load_csv(aura_opt_path)
        print(f"  SpellAuraOptions: {len(aura_opt_rows):,} rows")

    # filter PvP effects
    print("\nProcessing...")
    pvp_effects = filter_pvp_effects(effect_rows)
    print(f"  PvP-modified effects: {len(pvp_effects):,}")

    mod_aura_effects = filter_mod_aura_effects(effect_rows)
    print(f"  Modifier aura effects (647/649): {len(mod_aura_effects):,}")

    # build spell context map (all effects, for inferring generic labels)
    spell_context = build_spell_context(effect_rows)
    print(f"  Spell context map: {len(spell_context):,} spells")

    # build tables
    spells = build_spells_table(pvp_effects, spell_names, class_options, spell_context,
                                spell_schools, mechanic_names)
    print(f"  Spells with PvP coefficients: {len(spells):,}")

    # merge spell replacements and learn overrides for parent resolution
    combined_replacements = dict(spell_replacements)
    for overridden, learned in spell_learn_overrides.items():
        if overridden not in combined_replacements:
            combined_replacements[overridden] = learned

    parents = build_parent_spells(effect_rows, spells, combined_replacements)
    print(f"  Parent spells: {len(parents):,}")

    mod_auras = build_mod_auras(mod_aura_effects, spell_names, class_options)
    print(f"  PvP modifier auras: {len(mod_auras):,}")

    mod_lookup = build_spell_mod_lookup(mod_auras, spells, class_options, label_map)
    print(f"  Spells with modifier aura entries: {len(mod_lookup):,}")

    classes = build_classes_table(specs)
    print(f"  Classes: {len(classes):,}")

    spec_spells = build_spec_spells_filtered(spec_spells_map, spells, parents)
    print(f"  Specs with PvP spells: {len(spec_spells):,}")

    # build item & enchantment tables
    item_spells = {}
    if item_effect_rows and item_x_rows:
        all_item_effects = build_item_effects(item_effect_rows, item_x_rows)
        item_spells = build_pvp_item_spells(all_item_effects, spells, parents)
        print(f"  Items with PvP-relevant spells: {len(item_spells):,}")

    enchant_spells = {}
    if enchant_rows:
        all_enchants = build_enchantment_spells(enchant_rows)
        enchant_spells = build_pvp_enchantments(all_enchants, spells, parents)
        print(f"  Enchantments with PvP-relevant spells: {len(enchant_spells):,}")

    aura_options = {}
    if aura_opt_rows:
        aura_options = build_aura_options(aura_opt_rows, spells)
        print(f"  Spells with DR/dispel data: {len(aura_options):,}")

    # write output
    print(f"\nWriting {args.output}...")
    write_data_lua(args.output, spells, parents, mod_auras, mod_lookup,
                   classes, spec_spells, build_version, combined_replacements,
                   item_spells=item_spells, enchant_spells=enchant_spells,
                   aura_options=aura_options)

    # stats
    total_effects = sum(len(s["e"]) for s in spells.values())
    buffs = sum(1 for s in spells.values() for e in s["e"] if e["p"] > 1.0)
    nerfs = sum(1 for s in spells.values() for e in s["e"] if e["p"] < 1.0)
    print(f"\nDone!")
    print(f"  Total effects: {total_effects:,} ({buffs:,} buffs, {nerfs:,} nerfs)")
    size_kb = os.path.getsize(args.output) / 1024
    print(f"  File size: {size_kb:.0f} KB")

    return 0


if __name__ == "__main__":
    sys.exit(main())
