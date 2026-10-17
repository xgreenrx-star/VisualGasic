# Facebook release announcement

Ready to paste. GitHub downloads go live when the v5.7.0-beta.2 release is
published.

---

VisualGasic 5.7.0 Beta 2 is out. This one is a bug-fix release.

A local variable that shared a function's name used to make the call fail
with "Object variable not set". That call now says the name is ambiguous,
which is what VB6 does. Reading `.r` on a Color variable named `color` works
again. Typed array returns, a city warp that sat there for many seconds,
re-entrant Whenever callbacks, and a few editor save/palette bugs are fixed too.

There is also VM speed work. A full city build that started around five times
GDScript's instruction count is down to about 2.7 times. It is not faster than
GDScript yet. Older microbenchmark wins are still just microbenchmarks.

Ash Meridian Part 1's cities, including a new Backlight Yard, are in the
examples download.

Releases will slow down from here. We are out of funds and will concentrate
on other projects. We will still put out the occasional release and bug fix.
We still hope to reach a stable v6.0 by the end of the year or early next
year. If you have a specific bug or a feature request, please send it. Those
will be reviewed, and they are welcome.

Downloads: Linux and Windows installers, an unsigned Intel/Apple Silicon Mac
setup, offline bundles, and a Godot Asset Library addon ZIP. Back up your
project and replace the whole addon. The store listing may lag until it is
approved.

Release notes and downloads:
https://github.com/xgreenrx-star/VisualGasic/releases/tag/v5.7.0-beta.2

Report a bug or request a feature:
https://github.com/xgreenrx-star/VisualGasic/issues

Documentation:
https://github.com/xgreenrx-star/VisualGasic/blob/v5.7.0-beta.2/docs/DOCS.md

Website:
https://xgreenrx-star.github.io/VisualGasic/

#VisualGasic #Godot #BASIC #GameDev #OpenSource
