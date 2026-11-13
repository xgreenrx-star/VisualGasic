# Gate 1 character shortlist

Stopped after this shortlist. No bar scene, no motion test, and the campaign opening is unchanged. Character source files stay in `/tmp/ash-opening-gate1/` and are not part of the game.

Sheets: `docs/development/ash_meridian_opening/renders/gate1/`

Rendered in Blender 3.4.1 EEVEE, 640², Filmic, 16 samples. Neutral is a grey studio. Backlight is a dark world (`#02040b`) with a cyan rim (`#40d5e0`), an amber rim (`#ffbb65` / `#e78030`), and a small warm practical. Each seated frame is one sitter at a review table, so the shoulder and hand gates can be judged. A two-shot would duplicate the same mesh.

## Casting

Mark is Rocketbox Male Adult 05. Jason is Blender Studio Snow. Business Male 01 is not in the opening.

Jason is Male Adult 04 (black hooded jacket). Male Adult 12 (denim jacket) stays a catalog reference for a later character and is not imported into the opening or the game.

Sheet for Male Adult 05: `renders/gate1/a05_contact_sheet.png`

| | |
|---|---|
| File | `Assets/Avatars/Adults/Male_Adult_05/Export/Male_Adult_05_facial.fbx` |
| Repo | https://github.com/microsoft/Microsoft-Rocketbox |
| License | MIT. Copyright (c) 2020 Microsoft. The copyright and permission notice must stay with any copy. |
| Textures | `m009_body_color.tga`, `m009_head_color.tga`, `m009_opacity_color.tga` |

## Verdict

Snow v2 passes the hairline, seated-shoulder, and readable-hand gates. Male Adult 05 is the accepted Mark inside the Rocketbox set, hair cards included. The Gate 2 still is `renders/gate2/ash_meridian_opening_poker_still_v01.png`.

## 1. Snow v2 — pass, with the limit above

| | |
|---|---|
| Page | https://studio.blender.org/characters/snow/v2/ |
| File | `snow_v02.zip` (105.6 MB), Blender 3.1 file `snow_v02.blend` plus `maps/` |
| Download | https://studio.blender.org/download-source/files/8b/8b8cfa3e2d0781c893d952513152347f/8b8cfa3e2d0781c893d952513152347f.zip |
| License | CC-BY 4.0 — https://creativecommons.org/licenses/by/4.0/ |
| Credit | Snow Rig © Blender Foundation \| studio.blender.org |
| Redistribution | Allowed with that credit |
| Skeleton | `RIG-Snow`, production IK/FK limbs, stretch, hinge, parent switching. Finger IK is off. Wrist and foot masters posed the sit. |
| Face | Layered face controls and shape-key correctives (50 head keys, 32 body keys). This gate only shows the neutral face. |
| Hair | Fitted mesh `GEO-snow_hair_base` with its own textures. The shaved side is sculpted scalp, not a hole under a cap. |

The neck join stays closed even though the head and body are separate meshes. Seated shoulders stay connected, the knees stay inside the jeans, and both hands rest on the table as separate fingers. The shirt hem clips the white review cube. A few eyebrow constraints warn in Blender 3.4; the neutral face still rendered. Snow v3/v4 need Blender 4.1+, which is not installed here, so those files were not opened.

Sheet: `renders/gate1/snow_contact_sheet.png`

## 2. Quaternius Man in Suit — reject

| | |
|---|---|
| File | `man_in_suit.glb` (570 KB) from https://static.poly.pizza/66b57880-bcb0-479a-8d72-5c3e88afaa39.glb |
| Pack | Quaternius animated characters, the February 2019 pack listed as CC0. A fresh fetch of the Poly Pizza and Quaternius pack URLs returned 404, and the GLB has no embedded license text. Confirm the live pack page before copying this file into the repo. |
| Redistribution | CC0 permits it, if that pack listing is still the one this file came from |
| Skeleton | `HumanArmature`, 31 bones. Each hand is `Palm`, `MiddleHand`, one `Fingers` bone, `Thumb1`, `Thumb2`. |
| Face | No shape keys |
| Hair | White hair is painted on the head mesh. There is no floating cap. |

The included sitting clip does sit, and the shoulders do not collapse. The hands are mittens, so they cannot hold a card or read as a relaxed hand on a table. There is no face to speak with. The review table landed by the shin because the clip root is not at the origin used for the other two tests.

Sheet: `renders/gate1/suit_contact_sheet.png`

## 3. Rocketbox Business Male 01 — reject

| | |
|---|---|
| Repo | https://github.com/microsoft/Microsoft-Rocketbox (archived) |
| File | `Business_Male_01_facial.fbx` with `m005_body_color.tga`, `m005_head_color.tga`, `m005_opacity_color.tga` |
| License | MIT. Copyright (c) 2020 Microsoft. The copyright and permission notice must stay with any copy. |
| Redistribution | Allowed under that MIT notice |
| Skeleton | `Bip01`, 80 bones, a full finger chain on both hands (`Bip01 L Finger0`–`Finger4` and the right side) |
| Face | 176 shape keys (visemes, FACS, ARKit) plus jaw, lip, and eye bones |
| Hair | Opacity cards in `m005_opacity_color.tga` |

The hairline close-up shows card shells floating off the scalp, a gap at the temple, and a jagged alpha edge. That is the floating-cap failure. The rig can sit: knees bend, one hand meets the table, fingers stay separate, and the jacket shoulder does not collapse. There is no chair in that still, the other arm hangs, and the crotch cloth stretches. Those are pose and cloth limits. They do not repair the hair.

Sheet: `renders/gate1/rocket_contact_sheet.png`

## Looked at and left off the shortlist

- Rain, the Blender Studio woman on the same pipeline. The scene needs two men, her current file needs Blender 4.1+, and a fourth body would break the three-candidate cap.
- Mixamo. It needs an account, and redistribution of those characters in this repo is not clearly allowed.
- Quaternius modular base characters. Their hairstyles are separate caps, which this gate rejects.
- MakeHuman / MPFB. Already rejected in `character_audition/`. The old poker render `ash_meridian_opening_poker_v01.mp4` was not used as a target.
