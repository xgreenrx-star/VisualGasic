@tool
extends RefCounted
## Indexed palette lookup for labeled Data sprite blocks (v1: 16-color subsets).

const PALETTE_NAMES: PackedStringArray = ["NES", "GameBoy", "C64", "CGA"]

const _RAW := {
	"NES": [
		"#7C7C7C", "#0000FC", "#0000BC", "#4428BC", "#940084", "#A80020", "#A81000",
		"#881400", "#503000", "#007800", "#006800", "#005800", "#004058", "#000000",
		"#BCBCBC", "#0078F8",
	],
	"GameBoy": ["#0F380F", "#306230", "#8BAC0F", "#9BBC0F", "#000000", "#545454", "#A9A9A9", "#FFFFFF",
		"#7C7C7C", "#0000FC", "#0000BC", "#4428BC", "#940084", "#A80020", "#A81000", "#881400"],
	"C64": [
		"#000000", "#FFFFFF", "#880000", "#AAFFEE", "#CC44CC", "#00CC55",
		"#0000AA", "#EEEE77", "#DD8855", "#664400", "#FF7777", "#333333",
		"#777777", "#AAFF66", "#0088FF", "#BBBBBB",
	],
	"CGA": [
		"#000000", "#0000AA", "#00AA00", "#00AAAA", "#AA0000", "#AA00AA", "#AA5500", "#AAAAAA",
		"#555555", "#5555FF", "#55FF55", "#55FFFF", "#FF5555", "#FF55FF", "#FFFF55", "#FFFFFF",
	],
}


static func palette_name_for_id(palette_id: int) -> String:
	var idx := clampi(palette_id, 0, PALETTE_NAMES.size() - 1)
	return PALETTE_NAMES[idx]


static func colors_for_id(palette_id: int) -> Array:
	var name := palette_name_for_id(palette_id)
	var hexes: Array = _RAW.get(name, _RAW["NES"])
	var out: Array = []
	for i in hexes.size():
		out.append(Color.html(hexes[i]))
	return out


static func color_for_index(palette_id: int, index: int) -> Color:
	var cols := colors_for_id(palette_id)
	if cols.is_empty():
		return Color.MAGENTA
	var idx := clampi(index, 0, cols.size() - 1)
	return cols[idx]
