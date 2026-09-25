#include "visual_gasic_qb_screen.h"

#include "visual_gasic_instance.h"
#include "vg_qb_string_bytes.h"

#include "vg_font8x8_basic.h"

#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <cmath>

using namespace godot;

namespace {

struct QbState {
	bool active = false;
	int mode = 13;
	int width = 0;
	int height = 0;
	int ncolors = 16;
	int color = 15;
	PackedByteArray page[2];
	int active_page = 0;
	int visual_page = 0;
	Color pal[256];
	int64_t pal_raw[256] = {};
	bool pal_set[256] = {};
	bool view_on = false;
	int vx1 = 0;
	int vy1 = 0;
	int vx2 = 0;
	int vy2 = 0;
	bool window_on = false;
	bool window_screen = false;
	double wx1 = 0;
	double wy1 = 0;
	double wx2 = 1;
	double wy2 = 1;
	double gx = 0;
	double gy = 0;
	int text_row = 1;
	int text_col = 1;
	int text_fg = 15;
	int text_bg = 0;
	bool text_armed = false;
	ObjectID beep_id;
	struct Surf {
		int id = 0;
		int w = 0;
		int h = 0;
		int bpp = 32;
		Ref<Image> img;
	};
	struct Snd {
		int id = 0;
		ObjectID player_id;
	};
	Vector<Surf> surfs;
	Vector<Snd> snds;
	int next_img = -1;
	int next_snd = 1;
	int dest_id = 0;
	int source_id = 0;
	int visual_id = 0;
	int disp_w = 0;
	int disp_h = 0;
	int mouse_x = 0;
	int mouse_y = 0;
	int mouse_btn = 0;
	bool mouse_new = false;
	int split_gfx_bottom = -1;
	bool clip_playfield = false;
	Ref<Image> image;
	Ref<ImageTexture> texture;
	ObjectID sprite_id;
	ObjectID sion_id;
	bool dirty = false;
	Vector<uint8_t> key_bytes;
};

HashMap<VisualGasicInstance *, QbState *> g_qb;
Color g_pal[256];
bool g_pal_ready = false;

void ensure_palette() {
	if (g_pal_ready) {
		return;
	}
	const int ega[16][3] = {
		{ 0, 0, 0 }, { 0, 0, 170 }, { 0, 170, 0 }, { 0, 170, 170 },
		{ 170, 0, 0 }, { 170, 0, 170 }, { 170, 85, 0 }, { 170, 170, 170 },
		{ 85, 85, 85 }, { 85, 85, 255 }, { 85, 255, 85 }, { 85, 255, 255 },
		{ 255, 85, 85 }, { 255, 85, 255 }, { 255, 255, 85 }, { 255, 255, 255 }
	};
	for (int i = 0; i < 16; i++) {
		g_pal[i] = Color(ega[i][0] / 255.0f, ega[i][1] / 255.0f, ega[i][2] / 255.0f);
	}
	int n = 16;
	for (int r = 0; r < 6; r++) {
		for (int g = 0; g < 6; g++) {
			for (int b = 0; b < 6; b++) {
				g_pal[n++] = Color(r / 5.0f, g / 5.0f, b / 5.0f);
			}
		}
	}
	for (int i = 232; i < 256; i++) {
		float g = (float)(i - 232) / 23.0f;
		g_pal[i] = Color(g, g, g);
	}
	g_pal_ready = true;
}

struct ModeInfo {
	int w;
	int h;
	int colors;
	int split_gfx_bottom; // Max Y for playfield; -1 = full height (see classic modes 111+)
};

ModeInfo mode_info(int mode) {
	ModeInfo m;
	m.split_gfx_bottom = -1;
	switch (mode) {
		case 0: return { 640, 400, 16, -1 };
		case 1: return { 320, 200, 4, -1 };
		case 2: return { 640, 200, 2, -1 };
		case 7: return { 320, 200, 16, -1 };
		case 8: return { 640, 200, 16, -1 };
		case 9: return { 640, 350, 16, -1 };
		case 12: return { 640, 480, 16, -1 };
		case 13: return { 320, 200, 256, -1 };
		case 14: return { 320, 240, 256, -1 }; // VGA 320x240 (logical buffer)
		// Classic profiles (100+): inspired resolutions, not hardware emulation.
		case 100: return { 160, 200, 16, -1 }; // Tandy / PCjr 160x200x16
		case 101: return { 320, 200, 16, -1 }; // Tandy 320x200x16
		case 102: return { 640, 200, 4, -1 }; // CGA / Tandy 640x200x4
		case 110: return { 320, 192, 256, -1 }; // Atari 8-bit ANTIC-ish playfield
		case 111: return { 320, 200, 256, 159 }; // Atari-style split (gfx top, text band)
		case 112: return { 320, 200, 256, 175 }; // 22-row gfx + 3-row text (24 line feel)
		case 120: return { 256, 192, 16, -1 }; // CoCo 256x192x16
		case 121: return { 128, 96, 4, -1 }; // CoCo semigraphics-ish
		case 130: return { 280, 192, 16, -1 }; // Apple II hi-res inspired
		case 131: return { 140, 192, 16, -1 }; // Apple II lo-res inspired (half width)
		case 140: return { 320, 200, 16, -1 }; // Commodore 320x200x16
		case 150: return { 320, 256, 256, -1 }; // Amiga-ish chunky (single buffer)
		default:
			if (mode >= 100 && mode < 200) {
				return { 320, 200, 256, -1 };
			}
			return { 320, 200, 256, -1 };
	}
}

QbState *find_state(VisualGasicInstance *instance) {
	if (!instance || !g_qb.has(instance)) {
		return nullptr;
	}
	return g_qb[instance];
}

QbState *ensure_state(VisualGasicInstance *instance) {
	if (!instance) {
		return nullptr;
	}
	if (g_qb.has(instance)) {
		return g_qb[instance];
	}
	QbState *s = new QbState();
	g_qb.insert(instance, s);
	return s;
}

Node *owner_node(VisualGasicInstance *instance) {
	if (!instance || !instance->get_owner()) {
		return nullptr;
	}
	return Object::cast_to<Node>(instance->get_owner());
}

void enable_keys(VisualGasicInstance *instance) {
	Node *n = owner_node(instance);
	if (n) {
		n->set_process_input(true);
		n->set_process_unhandled_input(true);
	}
}

// QBasic INKEY$ extended key second byte (CHR$(0) + scan).
static int qb_scan_for_key(Key p_key) {
	switch (p_key) {
		case Key::KEY_UP:
			return 72;
		case Key::KEY_DOWN:
			return 80;
		case Key::KEY_LEFT:
			return 75;
		case Key::KEY_RIGHT:
			return 77;
		case Key::KEY_HOME:
			return 71;
		case Key::KEY_END:
			return 79;
		case Key::KEY_PAGEUP:
			return 73;
		case Key::KEY_PAGEDOWN:
			return 81;
		case Key::KEY_INSERT:
			return 82;
		case Key::KEY_DELETE:
			return 83;
		case Key::KEY_ESCAPE:
			return 27;
		case Key::KEY_SPACE:
			return 32;
		case Key::KEY_TAB:
			return 9;
		case Key::KEY_BACKSPACE:
			return 8;
		case Key::KEY_ENTER:
		case Key::KEY_KP_ENTER:
			return 13;
		default:
			return -1;
	}
}

static void qb_clear_key_queue(QbState *s) {
	if (!s) {
		return;
	}
	s->key_bytes.clear();
}

static void qb_queue_byte(QbState *s, uint8_t p_byte) {
	if (!s) {
		return;
	}
	s->key_bytes.push_back(p_byte);
	if (s->key_bytes.size() > 64) {
		s->key_bytes.remove_at(0);
	}
}

void copy_default_pal(QbState *s) {
	ensure_palette();
	for (int i = 0; i < 256; i++) {
		s->pal[i] = g_pal[i];
	}
	if (s && s->ncolors <= 4 && s->ncolors > 2) {
		s->pal[0] = Color(0, 0, 0, 1);
		s->pal[1] = Color(0, 1, 1, 1);
		s->pal[2] = Color(1, 0, 1, 1);
		s->pal[3] = Color(1, 1, 1, 1);
	}
	if (s) {
		for (int i = 0; i < 256; i++) {
			s->pal_raw[i] = 0;
			s->pal_set[i] = false;
		}
	}
}

Color color_of(QbState *s, int idx) {
	ensure_palette();
	if (idx < 0) {
		idx = 0;
	}
	if (idx > 255) {
		idx = 255;
	}
	if (!s) {
		return g_pal[idx];
	}
	if (s->ncolors <= 2) {
		return idx ? Color(1, 1, 1, 1) : Color(0, 0, 0, 1);
	}
	return s->pal[idx];
}

// QB SCREEN 13 palette long is &HBBGGRR with 0–63 DAC channels (or 0–255).
Color color_from_qb_long(int64_t c) {
	int r = (int)(c & 0xFF);
	int g = (int)((c >> 8) & 0xFF);
	int b = (int)((c >> 16) & 0xFF);
	auto up = [](int v) -> float {
		if (v < 0) {
			v = 0;
		}
		if (v <= 63) {
			return (float)v / 63.0f;
		}
		if (v > 255) {
			v = 255;
		}
		return (float)v / 255.0f;
	};
	return Color(up(r), up(g), up(b), 1);
}

int norm_color(QbState *s, int c) {
	if (c < 0) {
		c = s->color;
	}
	if (s->ncolors <= 0) {
		return 0;
	}
	if (c >= s->ncolors) {
		c = s->ncolors - 1;
	}
	s->color = c;
	return c;
}

int arg_int(const Array &args, int i, int fallback) {
	if (i < 0 || i >= args.size()) {
		return fallback;
	}
	const Variant &v = args[i];
	switch (v.get_type()) {
		case Variant::INT:
			return (int)v;
		case Variant::FLOAT:
			return (int)(double)v;
		default:
			return v.operator int();
	}
}

QbState::Surf *find_surf(QbState *s, int id) {
	if (!s || id >= 0) {
		return nullptr;
	}
	for (int i = 0; i < s->surfs.size(); i++) {
		if (s->surfs[i].id == id) {
			return &s->surfs.ptrw()[i];
		}
	}
	return nullptr;
}

Color color_from_argb(int64_t c) {
	uint32_t u = (uint32_t)c;
	float a = ((u >> 24) & 255) / 255.0f;
	float r = ((u >> 16) & 255) / 255.0f;
	float g = ((u >> 8) & 255) / 255.0f;
	float b = (u & 255) / 255.0f;
	if (a <= 0.0f && (u & 0x00FFFFFFu) != 0) {
		a = 1.0f;
	}
	return Color(r, g, b, a);
}

int64_t argb_from_color(const Color &c) {
	int a = (int)Math::round(c.a * 255.0f);
	int r = (int)Math::round(c.r * 255.0f);
	int g = (int)Math::round(c.g * 255.0f);
	int b = (int)Math::round(c.b * 255.0f);
	if (a < 0) a = 0;
	if (a > 255) a = 255;
	if (r < 0) r = 0;
	if (r > 255) r = 255;
	if (g < 0) g = 0;
	if (g > 255) g = 255;
	if (b < 0) b = 0;
	if (b > 255) b = 255;
	return ((int64_t)a << 24) | ((int64_t)r << 16) | ((int64_t)g << 8) | (int64_t)b;
}

bool dest_is_32(QbState *s) {
	QbState::Surf *sf = find_surf(s, s ? s->dest_id : 0);
	return sf && sf->bpp == 32 && sf->img.is_valid();
}

void bind_dest_size(QbState *s) {
	if (!s) {
		return;
	}
	QbState::Surf *sf = find_surf(s, s->dest_id);
	if (sf) {
		s->width = sf->w;
		s->height = sf->h;
		return;
	}
	if (s->disp_w > 0) {
		s->width = s->disp_w;
		s->height = s->disp_h;
	}
}

bool gfx_playfield_clip(QbState *s, int y) {
	return s && s->clip_playfield && s->split_gfx_bottom >= 0 && y > s->split_gfx_bottom;
}

void refresh_classic_project_settings(QbState *s) {
	if (!s) {
		return;
	}
	ProjectSettings *ps = ProjectSettings::get_singleton();
	if (!ps) {
		s->clip_playfield = false;
		return;
	}
	s->clip_playfield = (bool)ps->get_setting("vg/classic/clip_playfield", true);
}

void put_px32(QbState *s, int x, int y, int64_t col) {
	QbState::Surf *sf = find_surf(s, s->dest_id);
	if (!sf || !sf->img.is_valid()) {
		return;
	}
	if (s->view_on) {
		if (x < s->vx1 || y < s->vy1 || x > s->vx2 || y > s->vy2) {
			return;
		}
	}
	if (x < 0 || y < 0 || x >= sf->w || y >= sf->h) {
		return;
	}
	sf->img->set_pixel(x, y, color_from_argb(col));
	s->dirty = true;
}

int64_t get_px32(QbState *s, int x, int y) {
	int id = s ? s->source_id : 0;
	if (id >= 0) {
		id = s ? s->dest_id : 0;
	}
	QbState::Surf *sf = find_surf(s, id);
	if (!sf || !sf->img.is_valid()) {
		return -1;
	}
	if (x < 0 || y < 0 || x >= sf->w || y >= sf->h) {
		return -1;
	}
	return argb_from_color(sf->img->get_pixel(x, y));
}

void put_px(QbState *s, int x, int y, int col) {
	if (!s || !s->active) {
		return;
	}
	if (dest_is_32(s)) {
		put_px32(s, x, y, (int64_t)(uint32_t)col);
		return;
	}
	if (s->view_on) {
		if (x < s->vx1 || y < s->vy1 || x > s->vx2 || y > s->vy2) {
			return;
		}
	}
	if (x < 0 || y < 0 || x >= s->width || y >= s->height) {
		return;
	}
	int page = s->active_page & 1;
	int i = y * s->width + x;
	if (i < 0 || i >= s->page[page].size()) {
		return;
	}
	s->page[page].set(i, (uint8_t)col);
	if (page == (s->visual_page & 1) && s->image.is_valid()) {
		s->image->set_pixel(x, y, color_of(s, col));
	}
	s->dirty = true;
}

void put_px_gfx(QbState *s, int x, int y, int col) {
	if (gfx_playfield_clip(s, y)) {
		return;
	}
	put_px(s, x, y, col);
}

void put_px32_gfx(QbState *s, int x, int y, int64_t col) {
	if (gfx_playfield_clip(s, y)) {
		return;
	}
	put_px32(s, x, y, col);
}

int get_px(QbState *s, int x, int y) {
	if (!s || !s->active) {
		return -1;
	}
	if (s->source_id < 0 || (s->source_id == 0 && dest_is_32(s))) {
		int64_t c = get_px32(s, x, y);
		return (int)(uint32_t)c;
	}
	if (x < 0 || y < 0 || x >= s->width || y >= s->height) {
		return -1;
	}
	int page = s->active_page & 1;
	int i = y * s->width + x;
	if (i < 0 || i >= s->page[page].size()) {
		return -1;
	}
	return (int)s->page[page][i];
}

void clear_page(QbState *s, int page) {
	if (!s) {
		return;
	}
	page &= 1;
	int n = s->width * s->height;
	s->page[page].resize(n);
	for (int i = 0; i < n; i++) {
		s->page[page].set(i, 0);
	}
}

void sync_visual_image(QbState *s) {
	if (!s || !s->image.is_valid() || s->width < 1) {
		return;
	}
	int page = s->visual_page & 1;
	const PackedByteArray &px = s->page[page];
	int n = s->width * s->height;
	for (int i = 0; i < n; i++) {
		int c = (i < px.size()) ? (int)px[i] : 0;
		s->image->set_pixel(i % s->width, i / s->width, color_of(s, c));
	}
	s->dirty = true;
}

void clear_buffer(QbState *s) {
	if (dest_is_32(s)) {
		QbState::Surf *sf = find_surf(s, s->dest_id);
		if (sf && sf->img.is_valid()) {
			sf->img->fill(Color(0, 0, 0, 1));
		}
		s->dirty = true;
		s->text_row = 1;
		s->text_col = 1;
		s->text_armed = false;
		return;
	}
	clear_page(s, s->active_page);
	if ((s->active_page & 1) == (s->visual_page & 1) && s->image.is_valid()) {
		s->image->fill(Color(0, 0, 0, 1));
	}
	s->color = (s->ncolors > 15) ? 15 : (s->ncolors - 1);
	s->text_fg = s->color;
	s->text_bg = 0;
	s->text_row = 1;
	s->text_col = 1;
	s->text_armed = false;
	s->dirty = true;
}

void layout_sprite(QbState *s, VisualGasicInstance *instance) {
	Node *n = owner_node(instance);
	if (!n || !s->texture.is_valid()) {
		return;
	}
	Sprite2D *sprite = Object::cast_to<Sprite2D>(ObjectDB::get_instance(s->sprite_id));
	if (!sprite) {
		Node *existing = n->find_child("QbScreen", false, false);
		sprite = Object::cast_to<Sprite2D>(existing);
		if (!sprite) {
			sprite = memnew(Sprite2D);
			sprite->set_name("QbScreen");
			sprite->set_centered(false);
			sprite->set_texture_filter(CanvasItem::TEXTURE_FILTER_NEAREST);
			sprite->set_z_as_relative(false);
			sprite->set_z_index(4096);
			n->add_child(sprite);
		}
		s->sprite_id = sprite->get_instance_id();
	}
	sprite->set_visible(true);
	sprite->set_texture(s->texture);
	Viewport *vp = n->get_viewport();
	int lw = s->disp_w > 0 ? s->disp_w : s->width;
	int lh = s->disp_h > 0 ? s->disp_h : s->height;
	if (!vp || lw < 1 || lh < 1) {
		return;
	}
	Rect2 vis = vp->get_visible_rect();
	if (vis.size.x < 1.0f || vis.size.y < 1.0f) {
		return;
	}
	float sx = vis.size.x / (float)lw;
	float sy = vis.size.y / (float)lh;
	float sc = sx < sy ? sx : sy;
	if (sc <= 0.0f) {
		sc = 1.0f;
	}
	sprite->set_scale(Vector2(sc, sc));
	float dw = (float)lw * sc;
	float dh = (float)lh * sc;
	sprite->set_position(Vector2((vis.size.x - dw) * 0.5f, (vis.size.y - dh) * 0.5f));
}

void upload(QbState *s, VisualGasicInstance *instance) {
	if (!s || !s->dirty) {
		return;
	}
	if (s->texture.is_valid() && s->image.is_valid()) {
		s->texture->update(s->image);
	}
	layout_sprite(s, instance);
	s->dirty = false;
}

void draw_line(QbState *s, int x0, int y0, int x1, int y1, int col) {
	int dx = Math::abs(x1 - x0);
	int sx = x0 < x1 ? 1 : -1;
	int dy = -Math::abs(y1 - y0);
	int sy = y0 < y1 ? 1 : -1;
	int err = dx + dy;
	for (int guard = 0; guard < 200000; guard++) {
		put_px_gfx(s, x0, y0, col);
		if (x0 == x1 && y0 == y1) {
			break;
		}
		int e2 = 2 * err;
		if (e2 >= dy) {
			err += dy;
			x0 += sx;
		}
		if (e2 <= dx) {
			err += dx;
			y0 += sy;
		}
	}
}

void draw_box(QbState *s, int x0, int y0, int x1, int y1, int col, bool filled) {
	if (x0 > x1) {
		int t = x0;
		x0 = x1;
		x1 = t;
	}
	if (y0 > y1) {
		int t = y0;
		y0 = y1;
		y1 = t;
	}
	if (filled) {
		for (int y = y0; y <= y1; y++) {
			draw_line(s, x0, y, x1, y, col);
		}
		return;
	}
	draw_line(s, x0, y0, x1, y0, col);
	draw_line(s, x0, y1, x1, y1, col);
	draw_line(s, x0, y0, x0, y1, col);
	draw_line(s, x1, y0, x1, y1, col);
}

void apply_classic_mode_finish(QbState *s, int mode) {
	if (!s) {
		return;
	}
	s->split_gfx_bottom = mode_info(mode).split_gfx_bottom;
	refresh_classic_project_settings(s);
	if (s->split_gfx_bottom < 0) {
		return;
	}
	int y0 = s->split_gfx_bottom + 1;
	if (y0 >= s->height) {
		return;
	}
	for (int y = y0; y < s->height; y++) {
		for (int x = 0; x < s->width; x++) {
			put_px(s, x, y, 0);
		}
	}
	for (int x = 0; x < s->width; x++) {
		put_px(s, x, y0, 14);
	}
}

void draw_circle(QbState *s, int cx, int cy, int r, int col) {
	if (r < 0) {
		return;
	}
	if (r == 0) {
		put_px_gfx(s, cx, cy, col);
		return;
	}
	int x = r;
	int y = 0;
	int err = 1 - x;
	while (x >= y) {
		put_px_gfx(s, cx + x, cy + y, col);
		put_px_gfx(s, cx + y, cy + x, col);
		put_px_gfx(s, cx - y, cy + x, col);
		put_px_gfx(s, cx - x, cy + y, col);
		put_px_gfx(s, cx - x, cy - y, col);
		put_px_gfx(s, cx - y, cy - x, col);
		put_px_gfx(s, cx + y, cy - x, col);
		put_px_gfx(s, cx + x, cy - y, col);
		y++;
		if (err < 0) {
			err += 2 * y + 1;
		} else {
			x--;
			err += 2 * (y - x) + 1;
		}
	}
}

void flood(QbState *s, int x, int y, int paint, int border) {
	int seed = get_px(s, x, y);
	if (seed < 0) {
		return;
	}
	if (border >= 0) {
		if (seed == border || seed == paint) {
			return;
		}
	} else if (seed == paint) {
		return;
	}
	Vector<Vector2i> stack;
	stack.push_back(Vector2i(x, y));
	int guard = 0;
	int limit = s->width * s->height + 8;
	while (stack.size() > 0 && guard < limit) {
		guard++;
		Vector2i p = stack[stack.size() - 1];
		stack.remove_at(stack.size() - 1);
		int c = get_px(s, p.x, p.y);
		if (c < 0) {
			continue;
		}
		if (border >= 0) {
			if (c == border || c == paint) {
				continue;
			}
		} else if (c != seed) {
			continue;
		}
		put_px_gfx(s, p.x, p.y, paint);
		stack.push_back(Vector2i(p.x + 1, p.y));
		stack.push_back(Vector2i(p.x - 1, p.y));
		stack.push_back(Vector2i(p.x, p.y + 1));
		stack.push_back(Vector2i(p.x, p.y - 1));
	}
}

void hide_sprite(QbState *s) {
	if (!s || !s->sprite_id.is_valid()) {
		return;
	}
	Sprite2D *sprite = Object::cast_to<Sprite2D>(ObjectDB::get_instance(s->sprite_id));
	if (sprite) {
		sprite->set_visible(false);
	}
}

void screen_mode(VisualGasicInstance *instance, int mode, int active_page, int visual_page) {
	// SCREEN 0 remains the VG "hide overlay" command (showcase menu).
	if (mode == 0) {
		QbState *s = find_state(instance);
		if (s) {
			s->active = false;
			qb_clear_key_queue(s);
			hide_sprite(s);
		}
		return;
	}
	QbState *s = ensure_state(instance);
	if (!s) {
		return;
	}
	ensure_palette();
	ModeInfo info = mode_info(mode);
	const bool was_active = s->active;
	if (s->active && s->mode == mode && s->width == info.w && s->height == info.h && s->image.is_valid()) {
		if (active_page >= 0) {
			s->active_page = active_page & 1;
		}
		if (visual_page >= 0) {
			s->visual_page = visual_page & 1;
		}
		sync_visual_image(s);
		upload(s, instance);
		return;
	}
	s->active = true;
	if (!was_active) {
		qb_clear_key_queue(s);
	}
	refresh_classic_project_settings(s);
	s->mode = mode;
	s->dest_id = 0;
	s->source_id = 0;
	s->visual_id = 0;
	s->width = info.w;
	s->height = info.h;
	s->disp_w = info.w;
	s->disp_h = info.h;
	s->ncolors = info.colors;
	s->active_page = (active_page >= 0) ? (active_page & 1) : 0;
	s->visual_page = (visual_page >= 0) ? (visual_page & 1) : 0;
	s->view_on = false;
	s->window_on = false;
	s->window_screen = false;
	s->vx1 = 0;
	s->vy1 = 0;
	s->vx2 = info.w - 1;
	s->vy2 = info.h - 1;
	s->gx = 0;
	s->gy = 0;
	copy_default_pal(s);
	s->image = Image::create_empty(info.w, info.h, false, Image::FORMAT_RGBA8);
	s->texture = ImageTexture::create_from_image(s->image);
	clear_page(s, 0);
	clear_page(s, 1);
	clear_buffer(s);
	apply_classic_mode_finish(s, mode);
	Node *n = owner_node(instance);
	if (n) {
		n->set_process(true);
		n->set_process_input(true);
		n->set_process_unhandled_input(true);
	}
	upload(s, instance);
}

Array grab_rect(QbState *s, int x0, int y0, int x1, int y1) {
	if (x0 > x1) {
		int t = x0;
		x0 = x1;
		x1 = t;
	}
	if (y0 > y1) {
		int t = y0;
		y0 = y1;
		y1 = t;
	}
	if (s && s->active) {
		if (x0 < 0) x0 = 0;
		if (y0 < 0) y0 = 0;
		if (x1 >= s->width) x1 = s->width - 1;
		if (y1 >= s->height) y1 = s->height - 1;
	}
	Array out;
	if (!s || !s->active || x1 < x0 || y1 < y0) {
		out.resize(2);
		out[0] = 0;
		out[1] = 0;
		return out;
	}
	int bw = x1 - x0 + 1;
	int bh = y1 - y0 + 1;
	out.resize(2 + bw * bh);
	out[0] = bw;
	out[1] = bh;
	int k = 2;
	for (int y = y0; y <= y1; y++) {
		for (int x = x0; x <= x1; x++) {
			int px = get_px(s, x, y);
			out[k++] = px < 0 ? 0 : px;
		}
	}
	return out;
}

void blit_rect(QbState *s, int dx, int dy, const Array &src, const String &action) {
	if (!s || !s->active || src.size() < 2) {
		return;
	}
	int bw = (int)src[0];
	int bh = (int)src[1];
	if (bw < 0 || bh < 0) {
		return;
	}
	String act = action.to_upper();
	int k = 2;
	for (int y = 0; y < bh; y++) {
		for (int x = 0; x < bw; x++) {
			if (k >= src.size()) {
				return;
			}
			int src_c = (int)src[k++];
			int tx = dx + x;
			int ty = dy + y;
			int dst_c = get_px(s, tx, ty);
			if (dst_c < 0) {
				continue;
			}
			int out_c = src_c;
			if (act == "XOR" || act.is_empty()) {
				out_c = src_c ^ dst_c;
			} else if (act == "AND") {
				out_c = src_c & dst_c;
			} else if (act == "OR") {
				out_c = src_c | dst_c;
			} else if (act == "PRESET") {
				out_c = src_c ^ (s->ncolors - 1);
			} else if (act == "TRANS") {
				if (src_c == 0) {
					continue;
				}
			}
			if (out_c < 0) {
				out_c = 0;
			}
			if (out_c >= s->ncolors) {
				out_c = out_c % s->ncolors;
			}
			put_px(s, tx, ty, out_c);
		}
	}
}

String qb_to_mml(const String &raw) {
	String in = raw.to_lower();
	String out;
	for (int i = 0; i < in.length(); i++) {
		char32_t c = in[i];
		char32_t next = (i + 1 < in.length()) ? (char32_t)in[i + 1] : 0;
		bool rest = (c == 'p') && ((next >= '0' && next <= '9') || next == '.');
		out += rest ? String("r") : String::chr(c);
	}
	return out;
}

void play_mml(VisualGasicInstance *instance, const String &mml) {
	QbState *s = ensure_state(instance);
	if (!s) {
		return;
	}
	if (!ClassDB::class_exists("SiONDriver") || !ClassDB::can_instantiate("SiONDriver")) {
		return;
	}
	Object *driver = s->sion_id.is_valid() ? ObjectDB::get_instance(s->sion_id) : nullptr;
	if (!driver) {
		Node *n = owner_node(instance);
		if (!n) {
			return;
		}
		Variant created = ClassDB::instantiate("SiONDriver");
		driver = (Object *)created;
		Node *dn = Object::cast_to<Node>(driver);
		if (!dn) {
			return;
		}
		dn->set_name("QbPlay");
		n->add_child(dn);
		s->sion_id = dn->get_instance_id();
		driver = dn;
	}
	driver->call("play", qb_to_mml(mml), false);
}

double arg_f64(const Array &args, int i, double fallback) {
	if (i < 0 || i >= args.size()) {
		return fallback;
	}
	return (double)args[i];
}

void map_xy(QbState *s, double x, double y, int &ox, int &oy) {
	if (!s->window_on) {
		ox = (int)Math::floor(x);
		oy = (int)Math::floor(y);
		return;
	}
	double dx = s->wx2 - s->wx1;
	double dy = s->wy2 - s->wy1;
	if (dx == 0.0) {
		dx = 1.0;
	}
	if (dy == 0.0) {
		dy = 1.0;
	}
	int x1 = s->view_on ? s->vx1 : 0;
	int y1 = s->view_on ? s->vy1 : 0;
	int x2 = s->view_on ? s->vx2 : (s->width - 1);
	int y2 = s->view_on ? s->vy2 : (s->height - 1);
	double px = (double)x1 + (x - s->wx1) / dx * (double)(x2 - x1);
	double py = s->window_screen
		? (double)y1 + (y - s->wy1) / dy * (double)(y2 - y1)
		: (double)y2 - (y - s->wy1) / dy * (double)(y2 - y1);
	ox = (int)Math::floor(px);
	oy = (int)Math::floor(py);
}

void resolve_pt(QbState *s, double x, double y, bool step, bool missing, int &ox, int &oy) {
	double ax;
	double ay;
	if (missing) {
		ax = s->gx;
		ay = s->gy;
	} else if (step) {
		ax = s->gx + x;
		ay = s->gy + y;
	} else {
		ax = x;
		ay = y;
	}
	s->gx = ax;
	s->gy = ay;
	map_xy(s, ax, ay, ox, oy);
}

void scroll_region(QbState *s, int x0, int y0, int x1, int y1, int dx, int dy) {
	if (!s || !s->active) {
		return;
	}
	if (x0 > x1) {
		int t = x0;
		x0 = x1;
		x1 = t;
	}
	if (y0 > y1) {
		int t = y0;
		y0 = y1;
		y1 = t;
	}
	int w = x1 - x0 + 1;
	int h = y1 - y0 + 1;
	if (w < 1 || h < 1 || w * h > s->width * s->height) {
		return;
	}
	Vector<int> tmp;
	tmp.resize(w * h);
	for (int y = 0; y < h; y++) {
		for (int x = 0; x < w; x++) {
			int c = get_px(s, x0 + x, y0 + y);
			tmp.set(y * w + x, c < 0 ? 0 : c);
		}
	}
	bool prev = s->view_on;
	s->view_on = false;
	for (int y = 0; y < h; y++) {
		for (int x = 0; x < w; x++) {
			put_px(s, x0 + x, y0 + y, 0);
		}
	}
	for (int y = 0; y < h; y++) {
		for (int x = 0; x < w; x++) {
			int nx = x0 + x + dx;
			int ny = y0 + y + dy;
			if (nx < x0 || ny < y0 || nx > x1 || ny > y1) {
				continue;
			}
			put_px(s, nx, ny, tmp[y * w + x]);
		}
	}
	s->view_on = prev;
}

void fill_disk(QbState *s, int cx, int cy, int rx, int ry, int col) {
	if (rx < 0) {
		rx = -rx;
	}
	if (ry < 1) {
		ry = rx < 1 ? 1 : rx;
	}
	if (rx < 1) {
		put_px(s, cx, cy, col);
		return;
	}
	for (int y = -ry; y <= ry; y++) {
		double ny = (double)y / (double)ry;
		double span = 1.0 - ny * ny;
		if (span < 0.0) {
			continue;
		}
		int dx = (int)Math::round((double)rx * Math::sqrt(span));
		draw_line(s, cx - dx, cy + y, cx + dx, cy + y, col);
	}
}

void draw_circle_ex(QbState *s, int cx, int cy, int rx, int ry, int col, double start, double end, bool filled) {
	if (filled) {
		fill_disk(s, cx, cy, rx, ry, col);
		return;
	}
	if (rx < 0) {
		rx = -rx;
	}
	if (ry < 1) {
		ry = rx;
	}
	bool full = start < -1.0e8 || end < -1.0e8;
	if (full && rx == ry) {
		draw_circle(s, cx, cy, rx, col);
		return;
	}
	bool pie_s = start < 0.0;
	bool pie_e = end < 0.0;
	if (pie_s) {
		start = -start;
	}
	if (pie_e) {
		end = -end;
	}
	auto norm = [](double a) {
		const double pi2 = Math_TAU;
		while (a < 0.0) {
			a += pi2;
		}
		while (a >= pi2) {
			a -= pi2;
		}
		return a;
	};
	int steps = (rx + ry) * 6 + 12;
	if (steps > 4000) {
		steps = 4000;
	}
	double ns = full ? 0.0 : norm(start);
	double ne = full ? 0.0 : norm(end);
	for (int i = 0; i <= steps; i++) {
		double a = (Math_TAU * (double)i) / (double)steps;
		if (!full) {
			double na = norm(a);
			bool inside = (ns <= ne) ? (na >= ns && na <= ne) : (na >= ns || na <= ne);
			if (!inside) {
				continue;
			}
		}
		int x = cx + (int)Math::round(Math::cos(a) * (double)rx);
		int y = cy - (int)Math::round(Math::sin(a) * (double)ry);
		put_px_gfx(s, x, y, col);
	}
	if (!full && pie_s) {
		int x = cx + (int)Math::round(Math::cos(start) * (double)rx);
		int y = cy - (int)Math::round(Math::sin(start) * (double)ry);
		draw_line(s, cx, cy, x, y, col);
	}
	if (!full && pie_e) {
		int x = cx + (int)Math::round(Math::cos(end) * (double)rx);
		int y = cy - (int)Math::round(Math::sin(end) * (double)ry);
		draw_line(s, cx, cy, x, y, col);
	}
}

void draw_glyph(QbState *s, int x, int y, int ch, int fg, int bg) {
	if (ch < 0 || ch > 127) {
		ch = 63;
	}
	const unsigned char *g = font8x8_basic[ch];
	for (int row = 0; row < 8; row++) {
		unsigned char bits = g[row];
		for (int col = 0; col < 8; col++) {
			bool on = (bits & (1 << col)) != 0;
			put_px(s, x + col, y + row, on ? fg : bg);
		}
	}
}

void qb_print_text(QbState *s, const String &text, bool newline) {
	if (!s || !s->active) {
		return;
	}
	int cols = s->width / 8;
	int rows = s->height / 8;
	if (cols < 1) {
		cols = 1;
	}
	if (rows < 1) {
		rows = 1;
	}
	auto scroll_line = [&]() {
		scroll_region(s, 0, 0, s->width - 1, s->height - 1, 0, -8);
		s->text_row = rows;
	};
	for (int i = 0; i < text.length(); i++) {
		int ch = (int)text.unicode_at(i);
		if (ch == 10 || ch == 13) {
			s->text_col = 1;
			s->text_row++;
			if (s->text_row > rows) {
				scroll_line();
			}
			continue;
		}
		if (ch < 32 || ch > 127) {
			ch = 32;
		}
		if (s->text_col > cols) {
			s->text_col = 1;
			s->text_row++;
		}
		if (s->text_row > rows) {
			scroll_line();
		}
		int fg = s->text_fg;
		if (fg < 0) {
			fg = 0;
		}
		if (s->ncolors > 0 && fg >= s->ncolors) {
			fg = s->ncolors - 1;
		}
		int bg = s->text_bg;
		if (bg < 0) {
			bg = 0;
		}
		draw_glyph(s, (s->text_col - 1) * 8, (s->text_row - 1) * 8, ch, fg, bg);
		s->text_col++;
	}
	if (newline) {
		s->text_col = 1;
		s->text_row++;
		if (s->text_row > rows) {
			scroll_line();
		}
	}
}

int read_draw_num(const String &cmd, int &i, int fallback) {
	int n = cmd.length();
	int sign = 1;
	if (i < n && cmd[i] == '+') {
		i++;
	} else if (i < n && cmd[i] == '-') {
		sign = -1;
		i++;
	}
	int v = 0;
	bool any = false;
	while (i < n && cmd[i] >= '0' && cmd[i] <= '9') {
		any = true;
		v = v * 10 + (int)(cmd[i] - '0');
		i++;
	}
	if (!any) {
		return fallback;
	}
	return sign * v;
}

void rot_step(int ang, int ta, int dx, int dy, int scale, int &ox, int &oy) {
	double rad = ((double)((ang & 3) * 90 + ta)) * Math_PI / 180.0;
	double c = Math::cos(rad);
	double sn = Math::sin(rad);
	double x = (double)dx * c + (double)dy * sn;
	double y = -(double)dx * sn + (double)dy * c;
	double sc = (double)scale / 4.0;
	if (sc == 0.0) {
		sc = 1.0;
	}
	ox = (int)Math::round(x * sc);
	oy = (int)Math::round(y * sc);
}

void draw_string(QbState *s, const String &raw) {
	if (!s || !s->active) {
		return;
	}
	String cmd = raw.to_upper();
	int i = 0;
	int n = cmd.length();
	int ang = 0;
	int ta = 0;
	int scale = 4;
	int col = s->color;
	while (i < n) {
		char32_t c = cmd[i];
		if (c == ' ' || c == ';') {
			i++;
			continue;
		}
		bool blank = false;
		bool ret = false;
		if (c == 'B') {
			blank = true;
			i++;
			if (i >= n) {
				break;
			}
			c = cmd[i];
		}
		if (c == 'N') {
			ret = true;
			i++;
			if (i >= n) {
				break;
			}
			c = cmd[i];
		}
		double save_x = s->gx;
		double save_y = s->gy;
		if (c == 'C') {
			i++;
			col = norm_color(s, read_draw_num(cmd, i, s->color));
			continue;
		}
		if (c == 'S') {
			i++;
			scale = read_draw_num(cmd, i, 4);
			continue;
		}
		if (c == 'A') {
			i++;
			ang = read_draw_num(cmd, i, 0);
			continue;
		}
		if (c == 'T' && i + 1 < n && cmd[i + 1] == 'A') {
			i += 2;
			ta = read_draw_num(cmd, i, 0);
			continue;
		}
		if (c == 'P') {
			i++;
			int paint = read_draw_num(cmd, i, col);
			if (i < n && cmd[i] == ',') {
				i++;
			}
			int border = read_draw_num(cmd, i, paint);
			int px, py;
			map_xy(s, s->gx, s->gy, px, py);
			flood(s, px, py, norm_color(s, paint), norm_color(s, border));
			continue;
		}
		int dx = 0;
		int dy = 0;
		bool move = false;
		if (c == 'U' || c == 'D' || c == 'L' || c == 'R' || c == 'E' || c == 'F' || c == 'G' || c == 'H') {
			i++;
			int dist = read_draw_num(cmd, i, 1);
			if (c == 'U') {
				dy = -dist;
			} else if (c == 'D') {
				dy = dist;
			} else if (c == 'L') {
				dx = -dist;
			} else if (c == 'R') {
				dx = dist;
			} else if (c == 'E') {
				dx = dist;
				dy = -dist;
			} else if (c == 'F') {
				dx = dist;
				dy = dist;
			} else if (c == 'G') {
				dx = -dist;
				dy = dist;
			} else if (c == 'H') {
				dx = -dist;
				dy = -dist;
			}
			move = true;
		} else if (c == 'M') {
			i++;
			bool rel = (i < n && (cmd[i] == '+' || cmd[i] == '-'));
			int mx = read_draw_num(cmd, i, 0);
			if (i < n && cmd[i] == ',') {
				i++;
			}
			int my = read_draw_num(cmd, i, 0);
			if (rel) {
				dx = mx;
				dy = my;
			} else {
				int x0, y0, x1, y1;
				map_xy(s, s->gx, s->gy, x0, y0);
				map_xy(s, (double)mx, (double)my, x1, y1);
				if (!blank) {
					draw_line(s, x0, y0, x1, y1, col);
				}
				s->gx = mx;
				s->gy = my;
				if (ret) {
					s->gx = save_x;
					s->gy = save_y;
				}
			}
			move = rel;
		} else {
			i++;
			continue;
		}
		if (!move) {
			continue;
		}
		int sx, sy;
		rot_step(ang, ta, dx, dy, scale, sx, sy);
		int x0, y0, x1, y1;
		map_xy(s, s->gx, s->gy, x0, y0);
		s->gx += (double)sx;
		s->gy += (double)sy;
		map_xy(s, s->gx, s->gy, x1, y1);
		if (!blank) {
			draw_line(s, x0, y0, x1, y1, col);
		}
		if (ret) {
			s->gx = save_x;
			s->gy = save_y;
		}
	}
}

void qb_tone(VisualGasicInstance *instance, int freq, int ticks) {
	if (freq < 37) {
		freq = 37;
	}
	if (freq > 32767) {
		freq = 32767;
	}
	if (ticks < 1) {
		ticks = 1;
	}
	double seconds = (double)ticks / 18.2;
	if (seconds > 1.5) {
		seconds = 1.5;
	}
	const int rate = 22050;
	int n = (int)(rate * seconds);
	if (n < 1) {
		n = 1;
	}
	PackedByteArray pcm;
	pcm.resize(n * 2);
	for (int i = 0; i < n; i++) {
		double sample = Math::sin(Math_TAU * (double)freq * (double)i / (double)rate);
		int v = (int)(sample * 9000.0);
		pcm.set(i * 2, (uint8_t)(v & 0xFF));
		pcm.set(i * 2 + 1, (uint8_t)((v >> 8) & 0xFF));
	}
	Ref<AudioStreamWAV> wav;
	wav.instantiate();
	wav->set_format(AudioStreamWAV::FORMAT_16_BITS);
	wav->set_mix_rate(rate);
	wav->set_stereo(false);
	wav->set_data(pcm);
	QbState *s = ensure_state(instance);
	if (!s) {
		return;
	}
	Node *owner = owner_node(instance);
	if (!owner) {
		return;
	}
	AudioStreamPlayer *pl = Object::cast_to<AudioStreamPlayer>(ObjectDB::get_instance(s->beep_id));
	if (!pl) {
		pl = memnew(AudioStreamPlayer);
		pl->set_name("QbBeep");
		owner->add_child(pl);
		s->beep_id = pl->get_instance_id();
	}
	pl->set_stream(wav);
	pl->play();
}

Array load_pcx_array(const String &path) {
	Array out;
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
	if (f.is_null()) {
		return out;
	}
	int64_t len = f->get_length();
	if (len < 128 || len > 8 * 1024 * 1024) {
		return out;
	}
	PackedByteArray data = f->get_buffer((int)len);
	if (data.size() < 128 || data[0] != 10 || data[2] != 1 || data[3] != 8 || data[65] != 1) {
		return out;
	}
	int xmin = (int)data[4] | ((int)data[5] << 8);
	int ymin = (int)data[6] | ((int)data[7] << 8);
	int xmax = (int)data[8] | ((int)data[9] << 8);
	int ymax = (int)data[10] | ((int)data[11] << 8);
	int bpl = (int)data[66] | ((int)data[67] << 8);
	int w = xmax - xmin + 1;
	int h = ymax - ymin + 1;
	if (w < 1 || h < 1 || bpl < w || w > 2048 || h > 2048) {
		return out;
	}
	int target = bpl * h;
	Vector<uint8_t> raw;
	int i = 128;
	while ((int)raw.size() < target && i < data.size()) {
		uint8_t b = data[i++];
		if ((b & 0xC0) == 0xC0) {
			int cnt = b & 0x3F;
			if (i >= data.size()) {
				break;
			}
			uint8_t v = data[i++];
			for (int k = 0; k < cnt && (int)raw.size() < target; k++) {
				raw.push_back(v);
			}
		} else {
			raw.push_back(b);
		}
	}
	out.resize(2 + w * h);
	out[0] = w;
	out[1] = h;
	int k = 2;
	for (int y = 0; y < h; y++) {
		for (int x = 0; x < w; x++) {
			int src = y * bpl + x;
			out[k++] = (src < (int)raw.size()) ? (int)raw[src] : 0;
		}
	}
	return out;
}

int64_t qb_rgb32(int r, int g, int b, int a) {
	if (r < 0) r = 0;
	if (g < 0) g = 0;
	if (b < 0) b = 0;
	if (a < 0) a = 0;
	if (r > 255) r = 255;
	if (g > 255) g = 255;
	if (b > 255) b = 255;
	if (a > 255) a = 255;
	return ((int64_t)a << 24) | ((int64_t)r << 16) | ((int64_t)g << 8) | (int64_t)b;
}

int qb_newimage(QbState *s, int w, int h, int bpp) {
	if (!s || w < 1 || h < 1) {
		return 0;
	}
	if (w > 4096) w = 4096;
	if (h > 4096) h = 4096;
	QbState::Surf sf;
	sf.id = s->next_img;
	s->next_img--;
	if (s->next_img >= 0) {
		s->next_img = -1;
	}
	sf.w = w;
	sf.h = h;
	sf.bpp = (bpp == 32) ? 32 : 256;
	sf.img = Image::create_empty(w, h, false, Image::FORMAT_RGBA8);
	sf.img->fill(Color(0, 0, 0, 1));
	s->surfs.push_back(sf);
	return sf.id;
}

void qb_freeimage(QbState *s, int id) {
	if (!s) {
		return;
	}
	for (int i = 0; i < s->surfs.size(); i++) {
		if (s->surfs[i].id == id) {
			s->surfs.remove_at(i);
			break;
		}
	}
	if (s->dest_id == id) s->dest_id = 0;
	if (s->source_id == id) s->source_id = 0;
	if (s->visual_id == id) s->visual_id = 0;
}

void screen_image(VisualGasicInstance *instance, int handle) {
	QbState *s = ensure_state(instance);
	QbState::Surf *sf = find_surf(s, handle);
	if (!s || !sf || !sf->img.is_valid()) {
		return;
	}
	ensure_palette();
	s->active = true;
	s->mode = 32;
	s->split_gfx_bottom = -1;
	refresh_classic_project_settings(s);
	s->ncolors = 256;
	s->dest_id = handle;
	s->source_id = handle;
	s->visual_id = handle;
	s->width = sf->w;
	s->height = sf->h;
	s->disp_w = sf->w;
	s->disp_h = sf->h;
	s->image = sf->img;
	s->texture = ImageTexture::create_from_image(s->image);
	s->view_on = false;
	s->window_on = false;
	s->vx1 = 0;
	s->vy1 = 0;
	s->vx2 = sf->w - 1;
	s->vy2 = sf->h - 1;
	s->dirty = true;
	Node *n = owner_node(instance);
	if (n) {
		n->set_process(true);
		n->set_process_input(true);
		n->set_process_unhandled_input(true);
	}
	upload(s, instance);
}

void putimage_at(QbState *s, int dx, int dy, int src_id) {
	QbState::Surf *src = find_surf(s, src_id);
	if (!s || !src || !src->img.is_valid()) {
		return;
	}
	for (int y = 0; y < src->h; y++) {
		for (int x = 0; x < src->w; x++) {
			Color c = src->img->get_pixel(x, y);
			if (dest_is_32(s)) {
				put_px32(s, dx + x, dy + y, argb_from_color(c));
			} else {
				int idx = (int)(c.r * 15.0f);
				if (idx < 0) idx = 0;
				if (idx > 15) idx = 15;
				put_px(s, dx + x, dy + y, idx);
			}
		}
	}
}

int qb_sndopen(VisualGasicInstance *instance, const String &path) {
	QbState *s = ensure_state(instance);
	if (!s || path.is_empty()) {
		return 0;
	}
	Ref<Resource> res = ResourceLoader::get_singleton()->load(path);
	Ref<AudioStream> stream = res;
	if (stream.is_null()) {
		return 0;
	}
	Node *n = owner_node(instance);
	if (!n) {
		return 0;
	}
	AudioStreamPlayer *pl = memnew(AudioStreamPlayer);
	pl->set_name("QbSnd");
	pl->set_stream(stream);
	n->add_child(pl);
	QbState::Snd snd;
	snd.id = s->next_snd++;
	snd.player_id = pl->get_instance_id();
	s->snds.push_back(snd);
	return snd.id;
}

AudioStreamPlayer *snd_player(QbState *s, int id) {
	if (!s) {
		return nullptr;
	}
	for (int i = 0; i < s->snds.size(); i++) {
		if (s->snds[i].id == id) {
			return Object::cast_to<AudioStreamPlayer>(ObjectDB::get_instance(s->snds[i].player_id));
		}
	}
	return nullptr;
}

void map_mouse(QbState *s, const Vector2 &viewport_pos) {
	if (!s || !s->sprite_id.is_valid()) {
		return;
	}
	Sprite2D *sprite = Object::cast_to<Sprite2D>(ObjectDB::get_instance(s->sprite_id));
	if (!sprite) {
		return;
	}
	Vector2 local = sprite->get_global_transform().affine_inverse().xform(viewport_pos);
	s->mouse_x = (int)local.x;
	s->mouse_y = (int)local.y;
	s->mouse_new = true;
}

void apply_palette_entry(QbState *s, int idx, int64_t color_long) {
	if (!s || idx < 0 || idx > 255) {
		return;
	}
	s->pal[idx] = color_from_qb_long(color_long);
	s->pal_raw[idx] = color_long;
	s->pal_set[idx] = true;
	sync_visual_image(s);
}

} // namespace

namespace VGQbScreen {

bool handle_statement(VisualGasicInstance *instance, const String &method, const Array &args, bool &r_found) {
	String m = method.to_lower();
	if (m == "cls") {
		QbState *s = find_state(instance);
		if (!s || !s->active) {
			return false;
		}
		clear_buffer(s);
		upload(s, instance);
		r_found = true;
		return true;
	}
	if (m == "qbwait") {
		r_found = true;
		return true;
	}
	if (m == "qbbeep") {
		r_found = true;
		qb_tone(instance, 800, 4);
		return true;
	}
	if (m == "qbsound") {
		r_found = true;
		qb_tone(instance, arg_int(args, 0, 800), arg_int(args, 1, 4));
		return true;
	}
	if (m != "qbscreen" && m != "qbpset" && m != "qbline" && m != "qbcircle" && m != "qbpaint" && m != "qbput" && m != "qbplay"
		&& m != "_display" && m != "_dest" && m != "_source" && m != "_freeimage" && m != "_putimage"
		&& m != "_sndplay" && m != "_sndstop" && m != "_sndclose"
		&& m != "qbpalette" && m != "qbpaletteusing" && m != "qbpalettereset" && m != "qbpcopy"
		&& m != "qblocate" && m != "qbcolor" && m != "qbdraw" && m != "qbview" && m != "qbviewreset"
		&& m != "qbwindow" && m != "qbwindowreset" && m != "qbscroll") {
		return false;
	}
	r_found = true;
	QbState *s = find_state(instance);
	if (m == "qbscreen") {
		int mode = arg_int(args, 0, 13);
		if (mode < 0) {
			screen_image(instance, mode);
		} else {
			screen_mode(instance, mode, arg_int(args, 2, -1), arg_int(args, 3, -1));
		}
		return true;
	}
	if (m == "_display") {
		QbState *s = find_state(instance);
		if (s) {
			QbState::Surf *sf = find_surf(s, s->visual_id);
			if (sf && sf->img.is_valid()) {
				s->image = sf->img;
				s->disp_w = sf->w;
				s->disp_h = sf->h;
			}
			s->dirty = true;
			upload(s, instance);
		}
		r_found = true;
		return true;
	}
	if (m == "_dest" || m == "_source" || m == "_freeimage" || m == "_sndplay" || m == "_sndstop" || m == "_sndclose" || m == "_putimage") {
		r_found = true;
		QbState *s = ensure_state(instance);
		if (!s) {
			return true;
		}
		if (m == "_dest") {
			s->dest_id = arg_int(args, 0, 0);
			bind_dest_size(s);
			if (s->dest_id < 0) {
				s->active = true;
			}
			return true;
		}
		if (m == "_source") {
			s->source_id = arg_int(args, 0, 0);
			return true;
		}
		if (m == "_freeimage") {
			qb_freeimage(s, arg_int(args, 0, 0));
			return true;
		}
		if (m == "_putimage") {
			putimage_at(s, arg_int(args, 0, 0), arg_int(args, 1, 0), arg_int(args, 2, 0));
			return true;
		}
		AudioStreamPlayer *pl = snd_player(s, arg_int(args, 0, 0));
		if (m == "_sndplay" && pl) {
			pl->play();
		} else if (m == "_sndstop" && pl) {
			pl->stop();
		} else if (m == "_sndclose") {
			if (pl) {
				pl->queue_free();
			}
			int id = arg_int(args, 0, 0);
			for (int i = 0; i < s->snds.size(); i++) {
				if (s->snds[i].id == id) {
					s->snds.remove_at(i);
					break;
				}
			}
		}
		return true;
	}
	if (m == "qbplay") {
		if (args.size() >= 1) {
			play_mml(instance, String(args[0]));
		}
		return true;
	}
	if (!s || !s->active) {
		return true;
	}
	if (m == "qbpalettereset") {
		copy_default_pal(s);
		sync_visual_image(s);
		return true;
	}
	if (m == "qbpalette" && args.size() >= 2) {
		int64_t col = (int64_t)args[1];
		if (args.size() >= 4) {
			int r = arg_int(args, 1, 0) & 255;
			int g = arg_int(args, 2, 0) & 255;
			int b = arg_int(args, 3, 0) & 255;
			col = (int64_t)r | ((int64_t)g << 8) | ((int64_t)b << 16);
		}
		apply_palette_entry(s, arg_int(args, 0, 0), col);
		return true;
	}
	if (m == "qbpaletteusing" && args.size() >= 1) {
		Variant src = args[0];
		if (src.get_type() == Variant::ARRAY) {
			Array arr = src;
			for (int i = 0; i < arr.size() && i < 256; i++) {
				apply_palette_entry(s, i, (int64_t)arr[i]);
			}
		} else if (src.get_type() == Variant::PACKED_INT32_ARRAY) {
			PackedInt32Array arr = src;
			for (int i = 0; i < arr.size() && i < 256; i++) {
				apply_palette_entry(s, i, (int64_t)arr[i]);
			}
		} else if (src.get_type() == Variant::PACKED_INT64_ARRAY) {
			PackedInt64Array arr = src;
			for (int i = 0; i < arr.size() && i < 256; i++) {
				apply_palette_entry(s, i, arr[i]);
			}
		}
		return true;
	}
	if (m == "qbpcopy") {
		int src = arg_int(args, 0, 0) & 1;
		int dst = arg_int(args, 1, s->visual_page) & 1;
		s->page[dst] = s->page[src];
		if (dst == (s->visual_page & 1)) {
			sync_visual_image(s);
		}
		return true;
	}
	if (m == "qblocate") {
		int row = arg_int(args, 0, s->text_row);
		int col = arg_int(args, 1, s->text_col);
		if (row < 1) {
			row = 1;
		}
		if (col < 1) {
			col = 1;
		}
		s->text_row = row;
		s->text_col = col;
		s->text_armed = true;
		return true;
	}
	if (m == "qbcolor") {
		s->text_fg = arg_int(args, 0, s->text_fg);
		if (args.size() >= 2) {
			s->text_bg = arg_int(args, 1, s->text_bg);
		}
		s->color = s->text_fg;
		s->text_armed = true;
		return true;
	}
	if (m == "qbdraw" && args.size() >= 1) {
		draw_string(s, String(args[0]));
		return true;
	}
	if (m == "qbviewreset") {
		s->view_on = false;
		return true;
	}
	if (m == "qbview" && args.size() >= 4) {
		s->view_on = true;
		s->vx1 = arg_int(args, 0, 0);
		s->vy1 = arg_int(args, 1, 0);
		s->vx2 = arg_int(args, 2, s->width - 1);
		s->vy2 = arg_int(args, 3, s->height - 1);
		if (args.size() >= 5 && arg_int(args, 4, -1) >= 0) {
			int col = norm_color(s, arg_int(args, 4, -1));
			draw_box(s, s->vx1, s->vy1, s->vx2, s->vy2, col, true);
		}
		return true;
	}
	if (m == "qbwindowreset") {
		s->window_on = false;
		return true;
	}
	if (m == "qbwindow" && args.size() >= 4) {
		s->window_on = true;
		s->window_screen = arg_int(args, 4, 0) != 0;
		s->wx1 = arg_f64(args, 0, 0);
		s->wy1 = arg_f64(args, 1, 0);
		s->wx2 = arg_f64(args, 2, 1);
		s->wy2 = arg_f64(args, 3, 1);
		return true;
	}
	if (m == "qbscroll") {
		int x0 = 0;
		int y0 = 0;
		int x1 = s->width - 1;
		int y1 = s->height - 1;
		int dx = 0;
		int dy = 0;
		if (args.size() >= 6) {
			x0 = arg_int(args, 0, 0);
			y0 = arg_int(args, 1, 0);
			x1 = arg_int(args, 2, x1);
			y1 = arg_int(args, 3, y1);
			dx = arg_int(args, 4, 0);
			dy = arg_int(args, 5, 0);
		} else {
			dx = arg_int(args, 0, 0);
			dy = arg_int(args, 1, 0);
		}
		scroll_region(s, x0, y0, x1, y1, dx, dy);
		return true;
	}
	if (m == "qbpset" && args.size() >= 2) {
		int x, y;
		bool step = arg_int(args, 3, 0) != 0;
		resolve_pt(s, arg_f64(args, 0, 0), arg_f64(args, 1, 0), step, false, x, y);
		if (dest_is_32(s)) {
			int64_t col = (args.size() >= 3) ? (int64_t)args[2] : (int64_t)0xFFFFFFFF;
			put_px32_gfx(s, x, y, col);
		} else {
			put_px_gfx(s, x, y, norm_color(s, arg_int(args, 2, -1)));
		}
		return true;
	}
	if (m == "qbline" && args.size() >= 4) {
		int col = dest_is_32(s) ? (int)(uint32_t)((args.size() >= 5) ? (int64_t)args[4] : (int64_t)0xFFFFFFFF) : norm_color(s, arg_int(args, 4, -1));
		String style = args.size() >= 6 ? String(args[5]).to_upper() : String("");
		int flags = arg_int(args, 6, 0);
		int x0, y0, x1, y1;
		resolve_pt(s, arg_f64(args, 0, 0), arg_f64(args, 1, 0), (flags & 1) != 0, (flags & 4) != 0, x0, y0);
		resolve_pt(s, arg_f64(args, 2, 0), arg_f64(args, 3, 0), (flags & 2) != 0, false, x1, y1);
		if (style == "BF") {
			draw_box(s, x0, y0, x1, y1, col, true);
		} else if (style == "B") {
			draw_box(s, x0, y0, x1, y1, col, false);
		} else {
			draw_line(s, x0, y0, x1, y1, col);
		}
		return true;
	}
	if (m == "qbcircle" && args.size() >= 3) {
		int col = norm_color(s, arg_int(args, 3, -1));
		double start = (args.size() >= 5) ? arg_f64(args, 4, -1.0e9) : -1.0e9;
		double end = (args.size() >= 6) ? arg_f64(args, 5, -1.0e9) : -1.0e9;
		double aspect = (args.size() >= 7) ? arg_f64(args, 6, 0) : 0;
		bool filled = arg_int(args, 7, 0) != 0;
		int rx = arg_int(args, 2, 0);
		int ry = rx;
		if (aspect > 0.01) {
			ry = (int)Math::round((double)rx * aspect);
			if (ry < 1) {
				ry = 1;
			}
		}
		int cx, cy;
		resolve_pt(s, arg_f64(args, 0, 0), arg_f64(args, 1, 0), false, false, cx, cy);
		draw_circle_ex(s, cx, cy, rx, ry, col, start, end, filled);
		return true;
	}
	if (m == "qbpaint" && args.size() >= 2) {
		int col = norm_color(s, arg_int(args, 2, -1));
		int border = arg_int(args, 3, -1);
		int x, y;
		resolve_pt(s, arg_f64(args, 0, 0), arg_f64(args, 1, 0), false, false, x, y);
		flood(s, x, y, col, border);
		return true;
	}
	if (m == "qbput" && args.size() >= 3 && args[2].get_type() == Variant::ARRAY) {
		String action = args.size() >= 4 ? String(args[3]) : String("XOR");
		int x, y;
		resolve_pt(s, arg_f64(args, 0, 0), arg_f64(args, 1, 0), false, false, x, y);
		blit_rect(s, x, y, args[2], action);
		return true;
	}
	return true;
}

bool handle_expr(VisualGasicInstance *instance, const String &method, const Array &args, Variant &r_ret, bool &r_handled) {
	String m = method.to_lower();
	if (m == "inkey" || m == "inkey$") {
		if (args.size() != 0) {
			return false;
		}
		enable_keys(instance);
		r_handled = true;
		QbState *s = find_state(instance);
		if (!s || s->key_bytes.is_empty()) {
			r_ret = String("");
			return true;
		}
		r_ret = VGStringBytes::from_byte((int)s->key_bytes[0]);
		s->key_bytes.remove_at(0);
		return true;
	}
	if (m == "point" && args.size() == 2) {
		r_handled = true;
		QbState *s = find_state(instance);
		if (s && (s->source_id < 0 || dest_is_32(s))) {
			r_ret = get_px32(s, (int)args[0], (int)args[1]);
		} else {
			r_ret = (int64_t)get_px(s, (int)args[0], (int)args[1]);
		}
		return true;
	}
	if ((m == "screenmode" || m == "gfxwidth" || m == "gfxheight" || m == "gfxplayfieldbottom") && args.size() == 0) {
		r_handled = true;
		QbState *s = find_state(instance);
		if (!s || !s->active) {
			r_ret = (int64_t)0;
			return true;
		}
		if (m == "screenmode") {
			if (s->dest_id < 0) {
				r_ret = (int64_t)s->dest_id;
			} else {
				r_ret = (int64_t)s->mode;
			}
		} else if (m == "gfxwidth") {
			int w = s->disp_w > 0 ? s->disp_w : s->width;
			r_ret = (int64_t)w;
		} else if (m == "gfxheight") {
			int h = s->disp_h > 0 ? s->disp_h : s->height;
			r_ret = (int64_t)h;
		} else {
			if (s->split_gfx_bottom >= 0) {
				r_ret = (int64_t)s->split_gfx_bottom;
			} else {
				int h = s->disp_h > 0 ? s->disp_h : s->height;
				r_ret = (int64_t)(h > 0 ? h - 1 : 0);
			}
		}
		return true;
	}
	if (m == "_newimage" && args.size() >= 2) {
		r_handled = true;
		QbState *s = ensure_state(instance);
		r_ret = (int64_t)qb_newimage(s, arg_int(args, 0, 1), arg_int(args, 1, 1), arg_int(args, 2, 32));
		return true;
	}
	if (m == "_loadimage" && args.size() == 1) {
		r_handled = true;
		QbState *s = ensure_state(instance);
		Ref<Image> im = Image::create_empty(1, 1, false, Image::FORMAT_RGBA8);
		Error err = im->load(String(args[0]));
		if (err != OK) {
			r_ret = (int64_t)0;
			return true;
		}
		int id = qb_newimage(s, im->get_width(), im->get_height(), 32);
		QbState::Surf *sf = find_surf(s, id);
		if (sf) {
			sf->img = im;
			if (sf->img->get_format() != Image::FORMAT_RGBA8) {
				sf->img->convert(Image::FORMAT_RGBA8);
			}
		}
		r_ret = (int64_t)id;
		return true;
	}
	if ((m == "_rgb32" && args.size() >= 3) || (m == "_rgba32" && args.size() >= 4)) {
		r_handled = true;
		int a = (m == "_rgba32") ? arg_int(args, 3, 255) : 255;
		r_ret = qb_rgb32(arg_int(args, 0, 0), arg_int(args, 1, 0), arg_int(args, 2, 0), a);
		return true;
	}
	if (m == "_desktopwidth" || m == "_desktopheight") {
		r_handled = true;
		Vector2i sz = DisplayServer::get_singleton()->screen_get_size();
		if (sz.x < 1 || sz.y < 1) {
			Node *n = owner_node(instance);
			Viewport *vp = n ? n->get_viewport() : nullptr;
			if (vp) {
				Rect2 vis = vp->get_visible_rect();
				sz = Vector2i((int)vis.size.x, (int)vis.size.y);
			}
		}
		if (sz.x < 1) sz.x = 640;
		if (sz.y < 1) sz.y = 480;
		r_ret = (int64_t)((m == "_desktopwidth") ? sz.x : sz.y);
		return true;
	}
	if ((m == "_width" || m == "_height") && args.size() <= 1) {
		r_handled = true;
		QbState *s = find_state(instance);
		int id = args.size() == 1 ? arg_int(args, 0, 0) : 0;
		QbState::Surf *sf = find_surf(s, id);
		if (sf) {
			r_ret = (int64_t)((m == "_width") ? sf->w : sf->h);
		} else if (s && s->active) {
			int w = s->disp_w > 0 ? s->disp_w : s->width;
			int h = s->disp_h > 0 ? s->disp_h : s->height;
			r_ret = (int64_t)((m == "_width") ? w : h);
		} else {
			r_ret = (int64_t)0;
		}
		return true;
	}
	if (m == "_mousex" || m == "_mousey") {
		r_handled = true;
		QbState *s = find_state(instance);
		r_ret = (int64_t)(s ? ((m == "_mousex") ? s->mouse_x : s->mouse_y) : 0);
		return true;
	}
	if (m == "_mousebutton" && args.size() == 1) {
		r_handled = true;
		QbState *s = find_state(instance);
		int n = arg_int(args, 0, 1);
		int bit = 0;
		if (n == 1) bit = 1;
		else if (n == 2) bit = 2;
		else if (n == 3) bit = 4;
		r_ret = (int64_t)((s && (s->mouse_btn & bit)) ? -1 : 0);
		return true;
	}
	if (m == "_mouseinput" && args.size() == 0) {
		r_handled = true;
		QbState *s = find_state(instance);
		if (s && s->mouse_new) {
			s->mouse_new = false;
			r_ret = (int64_t)-1;
		} else {
			r_ret = (int64_t)0;
		}
		return true;
	}
	if (m == "_sndopen" && args.size() == 1) {
		r_handled = true;
		r_ret = (int64_t)qb_sndopen(instance, String(args[0]));
		return true;
	}
	if (m == "_sndplaying" && args.size() == 1) {
		r_handled = true;
		QbState *s = find_state(instance);
		AudioStreamPlayer *pl = snd_player(s, arg_int(args, 0, 0));
		r_ret = (int64_t)((pl && pl->is_playing()) ? -1 : 0);
		return true;
	}
	if (m == "qbget" && args.size() >= 4) {
		r_handled = true;
		QbState *s = find_state(instance);
		int x0, y0, x1, y1;
		if (s && s->active) {
			resolve_pt(s, arg_f64(args, 0, 0), arg_f64(args, 1, 0), false, false, x0, y0);
			resolve_pt(s, arg_f64(args, 2, 0), arg_f64(args, 3, 0), false, false, x1, y1);
		} else {
			x0 = arg_int(args, 0, 0);
			y0 = arg_int(args, 1, 0);
			x1 = arg_int(args, 2, 0);
			y1 = arg_int(args, 3, 0);
		}
		r_ret = grab_rect(s, x0, y0, x1, y1);
		return true;
	}
	if (m == "csrlin" && args.size() == 0) {
		r_handled = true;
		QbState *s = find_state(instance);
		r_ret = (int64_t)(s ? s->text_row : 1);
		return true;
	}
	if (m == "pos" && args.size() == 1) {
		r_handled = true;
		QbState *s = find_state(instance);
		r_ret = (int64_t)(s ? s->text_col : 1);
		return true;
	}
	if (m == "palettecolor" && args.size() == 1) {
		r_handled = true;
		QbState *s = find_state(instance);
		int idx = arg_int(args, 0, 0);
		if (!s || idx < 0 || idx > 255 || !s->pal_set[idx]) {
			r_ret = (int64_t)0;
		} else {
			r_ret = s->pal_raw[idx];
		}
		return true;
	}
	if ((m == "loadpcx") && args.size() == 1) {
		r_handled = true;
		r_ret = load_pcx_array(String(args[0]));
		return true;
	}
	return false;
}

void note_input(VisualGasicInstance *instance, const Variant &event) {
	if (event.get_type() != Variant::OBJECT) {
		return;
	}
	Object *obj = (Object *)event;
	InputEventMouseMotion *mm = Object::cast_to<InputEventMouseMotion>(obj);
	InputEventMouseButton *mb = Object::cast_to<InputEventMouseButton>(obj);
	if (mm || mb) {
		QbState *s = find_state(instance);
		if (!s || !s->active) {
			return;
		}
		Vector2 pos = mm ? mm->get_position() : mb->get_position();
		map_mouse(s, pos);
		if (mb) {
			int bit = 0;
			if (mb->get_button_index() == MouseButton::MOUSE_BUTTON_LEFT) bit = 1;
			else if (mb->get_button_index() == MouseButton::MOUSE_BUTTON_RIGHT) bit = 2;
			else if (mb->get_button_index() == MouseButton::MOUSE_BUTTON_MIDDLE) bit = 4;
			if (bit) {
				if (mb->is_pressed()) s->mouse_btn |= bit;
				else s->mouse_btn &= ~bit;
			}
			s->mouse_new = true;
		}
		return;
	}
	InputEventKey *key = Object::cast_to<InputEventKey>(obj);
	if (!key || !key->is_pressed()) {
		return;
	}
	QbState *s = find_state(instance);
	if (!s || !s->active) {
		return;
	}
	Key kc = key->get_keycode();
	if (kc == Key::KEY_NONE) {
		kc = key->get_physical_keycode();
	}
	int scan = qb_scan_for_key(kc);
	if (scan >= 0) {
		// Arrows: allow OS key-repeat for held thrust. Other extended keys: edge only.
		if (key->is_echo() && scan != 72 && scan != 80 && scan != 75 && scan != 77) {
			return;
		}
		if (scan == 72 || scan == 80 || scan == 75 || scan == 77) {
			qb_queue_byte(s, 0);
			qb_queue_byte(s, (uint8_t)scan);
			return;
		}
		if (key->is_echo()) {
			return;
		}
		if (scan == 27 || scan == 8 || scan == 13 || scan == 9 || scan == 32) {
			qb_queue_byte(s, (uint8_t)scan);
			return;
		}
		qb_queue_byte(s, 0);
		qb_queue_byte(s, (uint8_t)scan);
		return;
	}
	if (key->is_echo()) {
		return;
	}
	int unicode = (int)key->get_unicode();
	if (unicode <= 0 || unicode > 255) {
		return;
	}
	qb_queue_byte(s, (uint8_t)unicode);
}

void present(VisualGasicInstance *instance) {
	QbState *s = find_state(instance);
	if (!s) {
		return;
	}
	upload(s, instance);
}

void dispose(VisualGasicInstance *instance) {
	if (!instance || !g_qb.has(instance)) {
		return;
	}
	QbState *s = g_qb[instance];
	g_qb.erase(instance);
	if (s->sprite_id.is_valid()) {
		Object *sp = ObjectDB::get_instance(s->sprite_id);
		if (sp) {
			Node *nd = Object::cast_to<Node>(sp);
			if (nd) {
				nd->queue_free();
			}
		}
	}
	if (s->sion_id.is_valid()) {
		Object *dr = ObjectDB::get_instance(s->sion_id);
		if (dr) {
			Node *nd = Object::cast_to<Node>(dr);
			if (nd) {
				nd->queue_free();
			}
		}
	}
	for (int i = 0; i < s->snds.size(); i++) {
		Object *pl = ObjectDB::get_instance(s->snds[i].player_id);
		Node *nd = Object::cast_to<Node>(pl);
		if (nd) {
			nd->queue_free();
		}
	}
	if (s->beep_id.is_valid()) {
		Object *bp = ObjectDB::get_instance(s->beep_id);
		if (bp) {
			Node *nd = Object::cast_to<Node>(bp);
			if (nd) {
				nd->queue_free();
			}
		}
	}
	delete s;
}

void note_console_print(VisualGasicInstance *instance, const godot::String &text, bool newline) {
	QbState *s = find_state(instance);
	if (!s || !s->active || !s->text_armed) {
		return;
	}
	qb_print_text(s, text, newline);
}

} // namespace VGQbScreen
