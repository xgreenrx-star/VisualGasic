#include "vg_sprite_data_runtime.h"
#include "visual_gasic_vector_canvas.h"
#include <godot_cpp/classes/rendering_server.hpp>

namespace VGSpriteDataRuntime {

// Keep in sync with addons/visual_gasic/vg_sprite_data_palettes.gd
static const char *const NES_HEX[16] = {
	"#7C7C7C", "#0000FC", "#0000BC", "#4428BC", "#940084", "#A80020", "#A81000", "#881400",
	"#503000", "#007800", "#006800", "#005800", "#004058", "#000000", "#BCBCBC", "#0078F8",
};
static const char *const GAMEBOY_HEX[16] = {
	"#0F380F", "#306230", "#8BAC0F", "#9BBC0F", "#000000", "#545454", "#A9A9A9", "#FFFFFF",
	"#7C7C7C", "#0000FC", "#0000BC", "#4428BC", "#940084", "#A80020", "#A81000", "#881400",
};
static const char *const C64_HEX[16] = {
	"#000000", "#FFFFFF", "#880000", "#AAFFEE", "#CC44CC", "#00CC55", "#0000AA", "#EEEE77",
	"#DD8855", "#664400", "#FF7777", "#333333", "#777777", "#AAFF66", "#0088FF", "#BBBBBB",
};
static const char *const CGA_HEX[16] = {
	"#000000", "#0000AA", "#00AA00", "#00AAAA", "#AA0000", "#AA00AA", "#AA5500", "#AAAAAA",
	"#555555", "#5555FF", "#55FF55", "#55FFFF", "#FF5555", "#FF55FF", "#FFFF55", "#FFFFFF",
};

static Color color_from_hex(const char *hex) {
	return Color::html(String(hex));
}

Color palette_color(int palette_id, int index) {
	int idx = index;
	if (idx < 0) {
		idx = 0;
	}
	if (idx > 15) {
		idx = 15;
	}
	switch (palette_id) {
		case 1:
			return color_from_hex(GAMEBOY_HEX[idx]);
		case 2:
			return color_from_hex(C64_HEX[idx]);
		case 3:
			return color_from_hex(CGA_HEX[idx]);
		default:
			return color_from_hex(NES_HEX[idx]);
	}
}

bool parse_header(const Array &raw, int &r_w, int &r_h, int &r_transparent, int &r_palette_id) {
	if (raw.size() < 4) {
		return false;
	}
	r_w = (int)raw[0];
	r_h = (int)raw[1];
	r_transparent = (int)raw[2];
	r_palette_id = (int)raw[3];
	if (r_w < 1 || r_h < 1 || r_w > 32 || r_h > 32) {
		return false;
	}
	if (raw.size() < 4 + r_w * r_h) {
		return false;
	}
	return true;
}

Ref<Image> to_image(const Array &raw) {
	int w = 0, h = 0, transparent = 0, palette_id = 0;
	if (!parse_header(raw, w, h, transparent, palette_id)) {
		return Ref<Image>();
	}
	Ref<Image> img = Image::create_empty(w, h, false, Image::FORMAT_RGBA8);
	if (!img.is_valid()) {
		return img;
	}
	img->fill(Color(0, 0, 0, 0));
	for (int y = 0; y < h; y++) {
		for (int x = 0; x < w; x++) {
			int pi = 4 + y * w + x;
			int idx = (int)raw[pi];
			if (idx == transparent) {
				continue;
			}
			Color c = palette_color(palette_id, idx);
			c.a = 1.0f;
			img->set_pixel(x, y, c);
		}
	}
	return img;
}

static void draw_rect_ci(CanvasItem *ci, const Rect2 &rect, const Color &col) {
	if (!ci) {
		return;
	}
	if (VGVectorCanvas2D *vc = Object::cast_to<VGVectorCanvas2D>((Object *)ci)) {
		vc->DrawRect(rect, 0.0f, col, true, col);
		return;
	}
	RenderingServer *rs = RenderingServer::get_singleton();
	if (rs) {
		rs->canvas_item_add_rect(ci->get_canvas_item(), rect, col, false);
	}
}

int draw(CanvasItem *ci, const Array &raw, float x, float y, float scale) {
	int w = 0, h = 0, transparent = 0, palette_id = 0;
	if (!parse_header(raw, w, h, transparent, palette_id)) {
		return 0;
	}
	if (scale <= 0.0f) {
		scale = 1.0f;
	}
	// Prefer one batched DrawRects call on VGVectorCanvas2D.
	VGVectorCanvas2D *vc = ci ? Object::cast_to<VGVectorCanvas2D>((Object *)ci) : nullptr;
	if (vc) {
		PackedVector2Array rects;
		PackedColorArray colors;
		rects.resize(0);
		colors.resize(0);
		int drawn = 0;
		for (int py = 0; py < h; py++) {
			for (int px = 0; px < w; px++) {
				int idx = (int)raw[4 + py * w + px];
				if (idx == transparent) {
					continue;
				}
				Color c = palette_color(palette_id, idx);
				c.a = 1.0f;
				rects.push_back(Vector2(x + (float)px * scale, y + (float)py * scale));
				rects.push_back(Vector2(scale, scale));
				colors.push_back(c);
				drawn++;
			}
		}
		if (drawn > 0) {
			vc->DrawRects(rects, colors, true);
		}
		return drawn;
	}
	int drawn = 0;
	for (int py = 0; py < h; py++) {
		for (int px = 0; px < w; px++) {
			int idx = (int)raw[4 + py * w + px];
			if (idx == transparent) {
				continue;
			}
			Color c = palette_color(palette_id, idx);
			c.a = 1.0f;
			draw_rect_ci(ci, Rect2(x + (float)px * scale, y + (float)py * scale, scale, scale), c);
			drawn++;
		}
	}
	return drawn;
}

} // namespace VGSpriteDataRuntime
