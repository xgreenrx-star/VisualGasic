#!/usr/bin/env python3
"""Patch Node2D combat-enemy tscn files to use CharacterBody2D + CollisionShape2D.

The bullet (Area2D, collision_mask=1) fires body_entered only when it overlaps
a physics body on layer 1.  These enemies were Node2D (no physics body at all),
so bullets passed through them silently.  Changing root to CharacterBody2D
(collision_layer=1 default, collision_mask=0 so they don't interact with walls)
and adding a CircleShape2D child makes them detectable.
"""

import os
import re

BASE = (
    "/home/Commodore/Documents/VisualGasic/"
    "game_projects/AGCK_Tests/build/BLUE_SCREEN/eras"
)

COMBAT_ENEMIES = [
    # era_1979_ti99
    "era_1979_ti99/actors/Actor_AtariUFO.tscn",
    "era_1979_ti99/actors/Actor_ETCart.tscn",
    # era_1983_msx
    "era_1983_msx/actors/Actor_MSXBat.tscn",
    "era_1983_msx/actors/Actor_MSXImp.tscn",
    "era_1983_msx/actors/Actor_MSXDragon.tscn",
    # era_1984_mac
    "era_1984_mac/actors/Actor_MacBomb.tscn",
    "era_1984_mac/actors/Actor_MacGargoyle.tscn",
    "era_1984_mac/actors/Actor_SadMac.tscn",
    # era_1985_nes
    "era_1985_nes/actors/Actor_NESBulletBill.tscn",
    "era_1985_nes/actors/Actor_NESKoopa.tscn",
    "era_1985_nes/actors/Actor_NESBowser.tscn",
    # era_1985_atarist
    "era_1985_atarist/actors/Actor_STStrafer.tscn",
    "era_1985_atarist/actors/Actor_STRaider.tscn",
    "era_1985_atarist/actors/Actor_STCrash.tscn",
    # era_1993_win31
    "era_1993_win31/actors/Actor_Win31Cursor.tscn",
    "era_1993_win31/actors/Actor_Win31Dialog.tscn",
    "era_1993_win31/actors/Actor_GPFault.tscn",
    # era_1997_mac8
    "era_1997_mac8/actors/Actor_BeachBall.tscn",
    "era_1997_mac8/actors/Actor_Mac8Folder.tscn",
    "era_1997_mac8/actors/Actor_GiantBeachBall.tscn",
    # era_2003_flash
    "era_2003_flash/actors/Actor_FlashBanner.tscn",
    "era_2003_flash/actors/Actor_FlashPopup.tscn",
    "era_2003_flash/actors/Actor_AllYourBase.tscn",
    # era_2011_smilebasic
    "era_2011_smilebasic/actors/Actor_StreetPassCoin.tscn",
    "era_2011_smilebasic/actors/Actor_CodeBug.tscn",
    "era_2011_smilebasic/actors/Actor_StreetpassMob.tscn",
    # era_2026_ai
    "era_2026_ai/actors/Actor_AIDrone.tscn",
    "era_2026_ai/actors/Actor_AISentinel.tscn",
    "era_2026_ai/actors/Actor_HallucinatingGPT.tscn",
]

patched = 0
skipped = 0

for rel in COMBAT_ENEMIES:
    path = os.path.join(BASE, rel)
    if not os.path.exists(path):
        print(f"MISSING: {rel}")
        skipped += 1
        continue

    with open(path) as f:
        src = f.read()

    # Already patched?
    if "CharacterBody2D" in src or "sub_resource" in src:
        print(f"SKIP (already patched): {rel}")
        skipped += 1
        continue

    # Extract actor name from the [node name="X" type="Node2D"] line
    m = re.search(r'\[node name="(\w+)" type="Node2D"\]', src)
    if not m:
        print(f"SKIP (no Node2D root found): {rel}")
        skipped += 1
        continue
    actor_name = m.group(1)

    # Build new content
    new_src = src.replace(
        '[gd_scene load_steps=2 format=3]',
        '[gd_scene load_steps=3 format=3]'
    )
    # Insert sub_resource before the [node ...] line
    new_src = new_src.replace(
        f'[node name="{actor_name}" type="Node2D"]',
        (
            '[sub_resource type="CircleShape2D" id="col_1"]\n'
            'radius = 12.0\n'
            '\n'
            f'[node name="{actor_name}" type="CharacterBody2D"]\n'
            'collision_mask = 0'
        )
    )
    # Append child CollisionShape2D after the script line
    new_src = new_src.rstrip() + (
        '\n\n'
        '[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\n'
        'shape = SubResource("col_1")\n'
    )

    with open(path, 'w') as f:
        f.write(new_src)
    print(f"PATCHED: {rel}")
    patched += 1

print(f"\nDone. {patched} patched, {skipped} skipped.")
