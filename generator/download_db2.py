#!/usr/bin/env python3
"""Download DB2 CSV tables from wago.tools for PvPTip data generation."""

import argparse
import os
import sys
import urllib.request

# tables used by generate_data.py
TABLES = [
    # core spell data
    "SpellEffect",
    "SpellName",
    "SpellClassOptions",
    "SpellLabel",
    "SpellMechanic",
    "SpellMisc",
    "SpellReplacement",
    "SpellLearnSpell",
    # class & spec
    "ChrSpecialization",
    "SpecializationSpells",
    # item & enchantment data
    "ItemEffect",
    "ItemXItemEffect",
    "SpellItemEnchantment",
    # aura & spell metadata
    "SpellAuraOptions",
    "SpellPower",
    "SpellCooldowns",
    "SpellCategories",
    "SpellEquippedItems",
    "SpellShapeshift",
]

DEFAULT_OUTPUT = os.path.join(os.path.dirname(__file__), "..", "..", "db2_raw")


def download_table(table_name, output_dir, build):
    """Download a single DB2 table as CSV from wago.tools."""
    url = f"https://wago.tools/db2/{table_name}/csv?build={build}"
    output_path = os.path.join(output_dir, f"{table_name}.csv")

    req = urllib.request.Request(url, headers={
        "Accept": "text/csv",
        "User-Agent": "PvPTip-DataGen/1.0",
    })
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()
            if data.startswith(b"<!DOCTYPE"):
                print(f"  SKIP {table_name}: got HTML (table may not exist)")
                return False
            with open(output_path, "wb") as f:
                f.write(data)
            lines = data.count(b"\n")
            print(f"  OK   {table_name}: {lines:,} rows")
            return True
    except Exception as e:
        print(f"  FAIL {table_name}: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Download DB2 CSVs from wago.tools")
    parser.add_argument(
        "--build",
        required=True,
        help="WoW build version (e.g. 12.0.1.66838)",
    )
    parser.add_argument(
        "--output",
        default=DEFAULT_OUTPUT,
        help=f"Output directory. Default: {DEFAULT_OUTPUT}",
    )
    parser.add_argument(
        "--tables",
        nargs="+",
        default=TABLES,
        help="Tables to download. Default: all",
    )
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)

    build = args.build
    print(f"Build: {build}")
    print(f"Output: {args.output}")
    print(f"Tables: {len(args.tables)}")
    print()

    ok = 0
    for table in args.tables:
        if download_table(table, args.output, build):
            ok += 1

    print(f"\nDone: {ok}/{len(args.tables)} tables downloaded")
    with open(os.path.join(args.output, "build_info.txt"), "w") as f:
        f.write(f"{build}\n")
    return 0 if ok == len(args.tables) else 1


if __name__ == "__main__":
    sys.exit(main())
