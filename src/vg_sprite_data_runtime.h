#ifndef VG_SPRITE_DATA_RUNTIME_H
#define VG_SPRITE_DATA_RUNTIME_H

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/canvas_item.hpp>

using namespace godot;

/// Runtime helpers for labeled *Sprite Data tapes from DataToArray("Label").
/// Tape layout: raw(0)=w, raw(1)=h, raw(2)=transparentIdx, raw(3)=paletteId,
/// then w*h palette indices (0–15) row-major.
namespace VGSpriteDataRuntime {

Color palette_color(int palette_id, int index);
bool parse_header(const Array &raw, int &r_w, int &r_h, int &r_transparent, int &r_palette_id);
Ref<Image> to_image(const Array &raw);
/// Draw opaque pixels via CanvasItem (queues on VGVectorCanvas2D). Returns pixels drawn.
int draw(CanvasItem *ci, const Array &raw, float x, float y, float scale);

} // namespace VGSpriteDataRuntime

#endif // VG_SPRITE_DATA_RUNTIME_H
