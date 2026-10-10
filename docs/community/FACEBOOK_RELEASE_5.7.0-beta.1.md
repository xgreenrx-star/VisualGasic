# Facebook release announcement

Ready to post: the GitHub release and downloads were published October 10, 2026.

---

VisualGasic 5.7.0 Beta 1 is out!

This is a significant release—not just a new demo. There are core language
fixes, more reliable editor behavior, better sprite editing, Python integration
improvements, and a lot more bug testing behind it.

We tracked down problems with Await, ByRef, dictionaries, enums, typed
collections, error handling, arithmetic, recursion, and script reloads. We also
made the tests stricter: an incomplete run or a wrong answer doesn't get to
count as a pass.

The new showcase is Crystal Caverns, an original Boulder Dash-inspired game
with three caves, falling rocks, crystals, shader effects, and sound.

Its artwork lives right in the BASIC code as DATA statements. You can edit
the numbers as a pixel grid, or paint in the Sprite Editor and write the result
back to the same DATA block. Inline previews show what you're changing.
The cave maps—and even the recipes for the sound effects—are DATA too.
Whenever statements handle the crystal counter, exit unlock, and warning events.

The UI got some much-needed attention as well: readable panel colors, better
sprite help and navigation, sensible dialog sizes, more predictable folding,
and no repeated refresh popup interrupting every keystroke.
Fix Indentation also preserves folded code and Undo instead of breaking statements.

Downloads include Linux and Windows installers, Intel/Apple Silicon Mac setup,
offline bundles, and a Godot Asset Library addon ZIP. The Mac setup is unsigned
and needs Python 3. Store approval is separate from the GitHub release.

It is still a public beta on the way to v6, not a claim that every bug is gone.
Please back up your projects and send us your experiences—especially on Windows
and Mac.

Release notes and downloads:
https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.1

Documentation:
https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.1/docs/DOCS.md

Crystal Caverns source and guide:
https://github.com/xgreenrx-star/VisualGasic/tree/v5.7.0-beta.1/samples/showcases/crystal_caverns

Videos—earlier feature demonstrations:
https://youtu.be/FUw8zgbn_tU
https://youtu.be/ntpOTNflE_M

#VisualGasic #Godot #BASIC #GameDev #PixelArt #OpenSource
