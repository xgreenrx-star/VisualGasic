import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

// Offline original art source. Generated scenes have no runtime scripts.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../assets/trace_vault');
const res = 'res://assets/trace_vault';
const outputs = new Map();
const assets = [];
const n = v => {
	if (!Number.isFinite(v)) throw new Error(`Nonfinite model coordinate: ${v}`);
	return Number(v.toFixed(6));
};
const vec = p => `Vector3(${p.map(n).join(', ')})`;
const emit = (name, text) => outputs.set(name, Buffer.from(text));
const palette = {
	armor: ['0.12, 0.16, 0.21', 0.65],
	facet: ['0.24, 0.31, 0.39', 0.5],
	dark: ['0.012, 0.021, 0.035', 0.3],
	glass: ['0.025, 0.12, 0.16', 0.65],
	cyan: ['0.14, 0.85, 0.92', 0.15, true],
	amber: ['1, 0.49, 0.12', 0.15, true],
	red: ['1, 0.075, 0.12', 0.15, true],
	white: ['0.65, 0.92, 1', 0.1, true],
	violet: ['0.28, 0.16, 0.4', 0.2],
	depth: ['0.075, 0.1, 0.15', 0.05],
	depth_light: ['0.14, 0.24, 0.29', 0.0, true],
	// Matte rock for the two banks: no sheen from the pink rim light, so the far
	// bank does not read as a glossy floor at eye level.
	bank_rock: ['0.014, 0.018, 0.028', 0.0, false, 1.0],
	// Program suit: pale fabric, skin and dark trim for the human FEB.
	suit: ['0.78, 0.82, 0.86', 0.1, false, 0.38],
	suit_dark: ['0.035, 0.045, 0.06', 0.3, false, 0.45],
	skin: ['0.74, 0.56, 0.46', 0.0, false, 0.72],
	hair: ['0.05, 0.04, 0.035', 0.0, false, 0.8],
};
for (const [id, [color, metal, lit, rough]] of Object.entries(palette)) {
	emit(`materials/${id}.tres`, `[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(${color}, 1)
metallic = ${metal}
roughness = ${rough ?? 0.64}
${rough !== undefined ? 'metallic_specular = 0.05\n' : ''}${lit ? `shading_mode = 0\nemission_enabled = true\nemission = Color(${color}, 1)\nemission_energy_multiplier = 1.1` : ''}
`);
}
emit('materials/abyss_haze.tres', `[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="${res}/abyss_haze.gdshader" id="haze"]

[resource]
shader = ExtResource("haze")
`);

emit('materials/abyss_floor.tres', `[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="${res}/abyss_floor.gdshader" id="floor"]

[resource]
shader = ExtResource("floor")
`);
for (const [id, props] of [
	['trace_floor', 'shader_parameter/minor_cell = 1.0\nshader_parameter/major_cell = 5.0\nshader_parameter/minor_strength = 0.14\nshader_parameter/line_energy = 2.2'],
	['trace_wall', 'shader_parameter/minor_cell = 0.5\nshader_parameter/major_cell = 2.0\nshader_parameter/minor_strength = 0.1\nshader_parameter/line_energy = 1.6\nshader_parameter/base_color = Color(0.012, 0.02, 0.034, 1)'],
]) emit(`materials/${id}.tres`, `[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="${res}/trace_panel.gdshader" id="panel"]

[resource]
shader = ExtResource("panel")
${props}
`);
emit('materials/pod_glass.tres', `[gd_resource type="StandardMaterial3D" format=3]

[resource]
transparency = 1
cull_mode = 2
albedo_color = Color(0.55, 0.85, 1, 0.16)
metallic = 0.2
roughness = 0.08
emission_enabled = true
emission = Color(0.1, 0.45, 0.6, 1)
emission_energy_multiplier = 0.25
rim_enabled = true
rim = 0.6
`);
// Soft round puff for the stasis fog particles; fades via the emitter colour ramp.
emit('materials/fog_puff.tres', `[gd_resource type="StandardMaterial3D" load_steps=3 format=3]

[sub_resource type="Gradient" id="g"]
offsets = PackedFloat32Array(0, 1)
colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)

[sub_resource type="GradientTexture2D" id="t"]
gradient = SubResource("g")
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(1, 0.5)

[resource]
transparency = 1
shading_mode = 0
cull_mode = 2
vertex_color_use_as_albedo = true
albedo_color = Color(0.72, 0.92, 1, 0.42)
albedo_texture = SubResource("t")
billboard_mode = 3
`);
// Additive light columns for relays/docks; the controller swaps the material to show state.
for (const [id, color] of [['beacon_cyan', '0.2, 0.9, 1'], ['beacon_white', '0.85, 0.95, 1'], ['beacon_amber', '1, 0.55, 0.15'], ['beacon_dim', '0.12, 0.22, 0.28']]) emit(`materials/${id}.tres`, `[gd_resource type="StandardMaterial3D" load_steps=3 format=3]

[sub_resource type="Gradient" id="g"]
offsets = PackedFloat32Array(0, 0.7, 1)
colors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 0.35, 1, 1, 1, 0.7)

[sub_resource type="GradientTexture2D" id="t"]
gradient = SubResource("g")
width = 4
height = 64
fill_from = Vector2(0, 0)
fill_to = Vector2(0, 1)

[resource]
transparency = 1
blend_mode = 1
shading_mode = 0
cull_mode = 2
albedo_color = Color(${color}, 0.4)
albedo_texture = SubResource("t")
disable_fog = true
`);
emit('materials/trace_sky.tres', `[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="${res}/trace_sky.gdshader" id="sky"]

[resource]
shader = ExtResource("sky")
`);

class Scene {
	constructor(id, type = 'Node3D') {
		this.id = id;
		this.ext = new Map();
		this.sub = [];
		this.nodes = [];
		this.cache = new Map();
		this.markers = [];
		this.pieces = 0;
		this.node(id, type, null, type === 'CharacterBody3D' ? 'collision_layer = 2\ncollision_mask = 1' : '');
	}
	node(name, type, parent = '.', props = '', instance = '') {
		this.nodes.push(`[node name="${name}"${type ? ` type="${type}"` : ''}${parent === null ? '' : ` parent="${parent}"`}${instance ? ` instance=ExtResource("${instance}")` : ''}]\n${props}`);
		return parent === '.' || parent === null ? name : `${parent}/${name}`;
	}
	resource(type, resourcePath) {
		const key = `${type}:${resourcePath}`;
		if (!this.ext.has(key)) this.ext.set(key, { id: `e${this.ext.size}`, type, path: resourcePath });
		return this.ext.get(key).id;
	}
	subresource(type, props) {
		const key = `${type}:${props}`;
		if (!this.cache.has(key)) {
			const id = `s${this.sub.length}`;
			this.sub.push(`[sub_resource type="${type}" id="${id}"]\n${props}`);
			this.cache.set(key, id);
		}
		return this.cache.get(key);
	}
	group(name, parent = '.', position = [0, 0, 0], extra = '') {
		return this.node(name, 'Node3D', parent, `position = ${vec(position)}\n${extra}`);
	}
	marker(name, position, parent = '.', extra = '') {
		const nodePath = this.node(name, 'Marker3D', parent, `position = ${vec(position)}\n${extra}`);
		this.markers.push(nodePath);
		return nodePath;
	}
	mesh(name, type, props, position, material, parent = '.', rotation = [0, 0, 0]) {
		const mat = this.resource('Material', `${res}/materials/${material}.tres`);
		const mesh = this.subresource(type, props);
		this.pieces++;
		this.node(name, 'MeshInstance3D', parent, `position = ${vec(position)}\nrotation_degrees = ${vec(rotation)}\nmesh = SubResource("${mesh}")\nmaterial_override = ExtResource("${mat}")\ncast_shadow = 0`);
	}
	box(name, position, size, mat = 'armor', parent = '.', rotation = [0, 0, 0]) {
		this.mesh(name, 'BoxMesh', `size = ${vec(size)}`, position, mat, parent, rotation);
	}
	cylinder(name, position, radius, height, mat = 'armor', parent = '.', rotation = [0, 0, 0], top = radius) {
		this.mesh(name, 'CylinderMesh', `top_radius = ${top}\nbottom_radius = ${radius}\nheight = ${height}\nradial_segments = 24\nrings = 1`, position, mat, parent, rotation);
	}
	sphere(name, position, radius, mat, parent = '.', rotation = [0, 0, 0], height = radius * 2, hemi = false) {
		this.mesh(name, 'SphereMesh', `radius = ${radius}\nheight = ${height}\nradial_segments = 20\nrings = 10${hemi ? '\nis_hemisphere = true' : ''}`, position, mat, parent, rotation);
	}
	capsule(name, position, radius, height, mat, parent = '.', rotation = [0, 0, 0]) {
		this.mesh(name, 'CapsuleMesh', `radius = ${radius}\nheight = ${height}\nradial_segments = 16\nrings = 4`, position, mat, parent, rotation);
	}
	// Glowing edge bars around an axis-aligned box; `edges` filters 'top', 'bottom', 'vertical'.
	outline(prefix, position, size, mat = 'cyan', parent = '.', t = 0.035, edges = ['top', 'bottom', 'vertical']) {
		const [x, y, z] = position;
		const [w, h, d] = size.map(v => v * 0.5);
		for (const [key, ys] of [['top', [h]], ['bottom', [-h]]]) {
			if (!edges.includes(key)) continue;
			for (const dy of ys) for (const sz of [-1, 1]) this.box(`${prefix}_${key}X${sz}`, [x, y + dy, z + sz * d], [size[0] + t, t, t], mat, parent);
			for (const dy of ys) for (const sx of [-1, 1]) this.box(`${prefix}_${key}Z${sx}`, [x + sx * w, y + dy, z], [t, t, size[2] + t], mat, parent);
		}
		if (edges.includes('vertical')) for (const sx of [-1, 1]) for (const sz of [-1, 1]) this.box(`${prefix}_V${sx}_${sz}`, [x + sx * w, y, z + sz * d], [t, size[1] + t, t], mat, parent);
	}
	light(name, position, color, energy, range, parent = '.') {
		this.node(name, 'OmniLight3D', parent, `position = ${vec(position)}\nlight_color = Color(${color}, 1)\nlight_energy = ${energy}\nomni_range = ${range}\nshadow_enabled = false`);
	}
	torus(name, position, inner, outer, mat, parent = '.', rotation = [0, 0, 0]) {
		this.mesh(name, 'TorusMesh', `inner_radius = ${inner}\nouter_radius = ${outer}\nrings = 24\nring_segments = 8`, position, mat, parent, rotation);
	}
	body(name, position, size, parent = '.', layer = 1) {
		const body = this.node(name, 'StaticBody3D', parent, `position = ${vec(position)}\ncollision_layer = ${layer}\ncollision_mask = 0`);
		const shape = this.subresource('BoxShape3D', `size = ${vec(size)}`);
		this.node('Collision', 'CollisionShape3D', body, `shape = SubResource("${shape}")`);
	}
	instance(name, file, position = [0, 0, 0], parent = '.', rotation = [0, 0, 0]) {
		const id = this.resource('PackedScene', `${res}/scenes/${file}.tscn`);
		return this.node(name, '', parent, `position = ${vec(position)}\nrotation_degrees = ${vec(rotation)}`, id);
	}
	label(name, text, position, size = 36, parent = '.', opts = {}) {
		const { billboard = 1, rotation = [0, 0, 0], color = '0.45, 0.85, 0.92' } = opts;
		this.node(name, 'Label3D', parent, `position = ${vec(position)}\nrotation_degrees = ${vec(rotation)}\ntext = "${text}"\nfont_size = ${size}\npixel_size = 0.006\nmodulate = Color(${color}, 1)\nno_depth_test = false\nbillboard = ${billboard}`);
	}
	save(dimensions, role) {
		const text = `[gd_scene load_steps=${1 + this.ext.size + this.sub.length} format=3]\n\n${[
			...[...this.ext.values()].map(r => `[ext_resource type="${r.type}" path="${r.path}" id="${r.id}"]`),
			...this.sub, ...this.nodes,
		].join('\n\n')}\n`;
		emit(`scenes/${this.id}.tscn`, text);
		assets.push({ id: this.id, scene: `${res}/scenes/${this.id}.tscn`, role, nominal_dimensions: dimensions, markers: this.markers, mesh_instances: this.pieces, sha256: crypto.createHash('sha256').update(text).digest('hex') });
	}
}

// Narcean script. Numerals reuse the HUD's ten stroke glyphs (backlight_exploration_hud.vg `glyph`).
// Words are not a letter cipher: each upper-case word hashes (FNV-1a 32) to a run of stroke cells under a shared top bar.
const GLYPH_PATHS = [[[0, 0], [7, 6], [14, 0]], [[0, 18], [7, 12], [14, 18]], [[0, 2], [0, 16]], [[14, 2], [14, 16]], [[3, 9], [11, 9]], [[7, -3], [7, 21]]];
const NUMERAL_PATTERNS = [15, 21, 38, 56, 41, 26, 52, 35, 29, 51];
function narceanHash(word) {
	let h = 0x811c9dc5;
	for (const ch of word.toUpperCase()) h = Math.imul(h ^ ch.charCodeAt(0), 0x01000193) >>> 0;
	return h;
}
function narceanWordCells(word) {
	const h = narceanHash(word), cells = [];
	for (let i = 0; i < Math.max(1, Math.ceil(word.length / 2)); i++) cells.push(((h >>> ((i * 5) % 27)) & 63) || 42);
	return cells;
}
const NUMBER_WORDS = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];
// Draws `script` (words and digit runs) as thin emissive bars in the local XY plane, readable from +Z, centred on `position`.
// Returns the drawn width in metres. `unit` is metres per glyph unit (a cell is 14 x 18 units).
function narceanStrokes(s, parent, script, unit, mat = 'cyan') {
	const tokens = script.toUpperCase().split(/[^A-Z0-9]+/).filter(Boolean);
	const runs = tokens.map(t => /^[0-9]+$/.test(t) ? { numeral: true, cells: [...t].map(d => NUMERAL_PATTERNS[+d]) } : { numeral: false, cells: narceanWordCells(t) });
	const cellW = 18, wordGap = 12;
	const total = runs.reduce((w, r) => w + r.cells.length * cellW - 4, 0) + wordGap * (runs.length - 1);
	const t = Math.max(1.7 * unit, 0.004);
	let x0 = -total / 2, seg = 0;
	const bar = (a, b) => {
		const ax = (x0 + a[0]) * unit, ay = (9 - a[1]) * unit, bx = (x0 + b[0]) * unit, by = (9 - b[1]) * unit;
		const len = Math.hypot(bx - ax, by - ay);
		s.box(`S${seg++}`, [(ax + bx) / 2, (ay + by) / 2, 0], [len + t, t, t * 0.6], mat, parent, [0, 0, Math.atan2(by - ay, bx - ax) * 180 / Math.PI]);
	};
	for (const run of runs) {
		const runW = run.cells.length * cellW - 4;
		if (!run.numeral) bar([0, -3], [runW, -3]);
		run.cells.forEach((pattern, ci) => {
			const ox = ci * cellW;
			GLYPH_PATHS.forEach((pathPts, pi) => {
				if (!(pattern & (1 << pi))) return;
				for (let k = 1; k < pathPts.length; k++) bar([ox + pathPts[k - 1][0], pathPts[k - 1][1]], [ox + pathPts[k][0], pathPts[k][1]]);
			});
		});
		x0 += runW + wordGap;
	}
	return total * unit;
}
// A Narcean sign: `Script` strokes plus an English `Gloss` that only the translator (interface) or the FEB (high) reveals.
function narceanSign(s, name, script, gloss, position, opts = {}) {
	const { kind = 'interface', unit = 0.01, rotation = [0, 0, 0], mat = 'cyan', parent = '.', glossSize = 40 } = opts;
	const root = s.node(name, 'Node3D', parent, `position = ${vec(position)}\nrotation_degrees = ${vec(rotation)}\nmetadata/text_kind = "${kind}"\nmetadata/script = "${script}"\nmetadata/gloss = "${gloss}"`);
	const strokes = s.group('Script', root);
	narceanStrokes(s, strokes, script, unit, mat);
	const glossY = -(14 + glossSize * 0.55 / 2) * unit;
	s.node('Gloss', 'Label3D', root, `position = ${vec([0, glossY, 0.01])}\ntext = "${gloss}"\nfont_size = ${glossSize}\npixel_size = ${n(unit * 0.55)}\nmodulate = Color(0.55, 0.97, 1, 1)\noutline_size = 6\nno_depth_test = false\nbillboard = 0\nvisible = false`);
	return root;
}

function cycle(id, security = false) {
	const s = new Scene(id, 'CharacterBody3D');
	const light = security ? 'red' : 'cyan';
	s.group('VisualRoot');
	const shape = s.subresource('BoxShape3D', 'size = Vector3(1.12, 1.25, 4.1)');
	s.node('HullCollision', 'CollisionShape3D', '.', `position = Vector3(0, 0.65, 0)\nshape = SubResource("${shape}")`);
	// Overlapping tapered drums and panel wedges form an enclosed single-track body.
	s.cylinder('LowerChassis', [0, 0.68, 0], 0.58, 2.45, 'armor', 'VisualRoot', [90, 0, 0], 0.48);
	s.box('Keel', [0, 0.34, 0], [0.66, 0.18, 2.4], 'facet', 'VisualRoot');
	s.box('Spine', [0, 0.93, 0.12], [0.84, 0.46, 2.15], 'armor', 'VisualRoot');
	s.box('NoseWedge', [0, 0.86, -1.28], [0.84, 0.22, 1.27], 'facet', 'VisualRoot', [-15, 0, 0]);
	s.box('TailWedge', [0, 0.94, 1.18], [0.88, 0.3, 1.12], 'armor', 'VisualRoot', [14, 0, 0]);
	for (const [name, z] of [['Front', -1.38], ['Rear', 1.35]]) {
		const pivot = s.group(`${name}WheelPivot`, 'VisualRoot', [0, 0.51, z]);
		s.cylinder('Tread', [0, 0, 0], 0.51, 0.55, 'dark', pivot, [0, 0, 90]);
		for (const side of [-1, 1]) {
			s.cylinder(`Drum${side}`, [side * 0.29, 0, 0], 0.42, 0.045, 'facet', pivot, [0, 0, 90]);
			s.torus(`Rim${side}`, [side * 0.32, 0, 0], 0.37, 0.39, light, pivot, [0, 0, 90]);
			s.cylinder(`Hub${side}`, [side * 0.34, 0, 0], 0.19, 0.05, 'armor', pivot, [0, 0, 90]);
			s.cylinder(`Lock${side}`, [side * 0.375, 0, 0], 0.055, 0.025, 'amber', pivot, [0, 0, 90]);
			for (let a = 0; a < 4; a++) {
				const angle = a * Math.PI / 2;
				s.box(`WheelTab${side}_${a}`, [side * 0.35, Math.cos(angle) * 0.3, Math.sin(angle) * 0.3], [0.025, 0.06, 0.07], 'armor', pivot, [a * 90, 0, 0]);
			}
		}
	}
	const canopy = s.group('CanopyPivot', 'VisualRoot', [0, 1.14, 0.65]);
	s.box('Capsule', [0, 0.12, -0.55], [0.78, 0.36, 1.25], 'armor', canopy);
	s.box('Windshield', [0, 0.17, -1.2], [0.72, 0.32, 0.04], security ? 'armor' : 'glass', canopy, [-30, 0, 0]);
	s.box('Roof', [0, 0.32, -0.5], [0.76, 0.05, 1.0], 'facet', canopy);
	for (const side of [-1, 1]) {
		s.box(`Window${side}`, [side * 0.402, 0.14, -0.55], [0.025, 0.25, 0.9], security ? 'dark' : 'glass', canopy);
		s.box(`CanopySeam${side}`, [side * 0.41, 0.29, -0.52], [0.018, 0.018, 1.0], light, canopy);
		s.box(`SideHousing${side}`, [side * 0.49, 0.72, 0], [0.22, 0.38, 1.38], 'armor', 'VisualRoot');
		s.box(`LowerSeam${side}`, [side * 0.61, 0.51, 0], [0.025, 0.025, 1.32], light, 'VisualRoot');
		for (let i = 0; i < 6; i++) s.box(`Vent${side}_${i}`, [side * 0.607, 0.76, -0.45 + i * 0.16], [0.022, 0.11, 0.045], 'facet', 'VisualRoot', [0, 0, -15 * side]);
		s.box(`ServiceLatch${side}`, [side * 0.62, 0.9, -0.53], [0.03, 0.17, 0.09], 'amber', 'VisualRoot', [0, 0, -12 * side]);
		s.box(`Fork${side}`, [side * 0.38, 0.72, -1.38], [0.09, 0.45, 0.16], 'facet', 'VisualRoot', [-22, 0, 0]);
		s.box(`TailLight${side}`, [side * 0.26, 1.04, 1.75], [0.12, 0.05, 0.04], light, 'VisualRoot');
	}
	s.box('WorkLamp', [0.24, 0.94, -1.94], [0.23, 0.11, 0.07], 'white', 'VisualRoot', [-15, 0, 0]);
	s.cylinder('OffsetSensor', [-0.22, 0.94, -1.94], 0.09, 0.1, 'dark', 'VisualRoot', [90, 0, 0]);
	s.box('Projector', [0, 0.7, 1.94], [0.42, 0.46, 0.23], 'facet', 'VisualRoot');
	for (const x of [-0.12, 0.12]) s.box(`EmitterSlit${x}`, [x, 0.72, 2.065], [0.035, 0.34, 0.012], light, 'VisualRoot');
	s.marker('TraceEmitter', [0, 0.1, 2.1]);
	s.marker('Seat', [0, 0.66, 0.2]);
	s.marker('ExitPoint', [1.4, 0, 0.2]);
	s.marker('CameraTarget', [0, 1.05, -0.2]);
	s.save([1.35, 1.55, 4.2], 'Movable cycle. Wheel/canopy pivots are under VisualRoot; emitter and collision do not bank.');
}
cycle('trace_cycle');
cycle('security_cycle', true);

emit('materials/windscreen_glass.tres', `[gd_resource type="StandardMaterial3D" format=3]

[resource]
transparency = 1
shading_mode = 0
cull_mode = 2
albedo_color = Color(0.32, 0.82, 1, 0.075)
`);
{
	// Rider-eye frame: origin is the cycle CameraTarget, -Z is forward. Mount on a cockpit-only render layer.
	const s = new Scene('trace_cockpit');
	const arc = (prefix, cx, cy, z, r, from, to, count, thick, mat, parent) => {
		for (let i = 0; i < count; i++) {
			const a0 = (from + (to - from) * i / count) * Math.PI / 180;
			const a1 = (from + (to - from) * (i + 1) / count) * Math.PI / 180;
			const x0 = cx + Math.cos(a0) * r, y0 = cy + Math.sin(a0) * r;
			const x1 = cx + Math.cos(a1) * r, y1 = cy + Math.sin(a1) * r;
			const len = Math.hypot(x1 - x0, y1 - y0) + thick * 0.6;
			const deg = Math.atan2(y1 - y0, x1 - x0) * 180 / Math.PI;
			s.box(`${prefix}${i}`, [(x0 + x1) / 2, (y0 + y1) / 2, z], [len, thick, thick], mat, parent, [0, 0, deg]);
		}
	};
	// Tall clear bike screen, raked back toward the rider from its base on the binnacle cowl.
	const screen = s.group('Windscreen', '.', [0, -0.36, -0.9], 'rotation_degrees = Vector3(16, 0, 0)');
	s.cylinder('Glass', [0, 0, 0], 0.5, 0.004, 'windscreen_glass', screen, [90, 0, 0]);
	arc('Rim', 0, 0, 0.004, 0.5, 26, 154, 16, 0.022, 'armor', screen);
	arc('RimLight', 0, 0, 0.018, 0.488, 30, 150, 14, 0.008, 'cyan', screen);
	for (const side of [-1, 1]) {
		s.box(`ScreenMount${side}`, [side * 0.43, 0.2, 0.03], [0.045, 0.12, 0.05], 'facet', screen, [0, 0, side * 32]);
		s.box(`ScreenBolt${side}`, [side * 0.43, 0.2, 0.06], [0.018, 0.018, 0.012], 'amber', screen);
	}
	const hud = s.group('HudAnchor', screen, [0, 0.37, 0.03]);
	s.torus('Reticle', [0, 0.05, 0], 0.016, 0.02, 'cyan', hud, [90, 0, 0]);
	for (const side of [-1, 1]) s.box(`ReticleTick${side}`, [side * 0.042, 0.05, 0], [0.026, 0.003, 0.003], 'cyan', hud);
	s.box('HorizonBar', [0, -0.02, 0], [0.34, 0.0025, 0.002], 'cyan', hud);
	const hudText = (name, pos, align) => s.node(name, 'Label3D', hud, `position = ${vec(pos)}\ntext = " "\nfont_size = 30\npixel_size = 0.0006\nmodulate = Color(0.55, 0.95, 1, 0.92)\noutline_size = 0\nhorizontal_alignment = ${align}\nno_depth_test = true\nfixed_size = false\nshaded = false`);
	hudText('HudSpeed', [-0.2, 0.0, 0], 0);
	hudText('HudTrace', [0.2, 0.0, 0], 2);
	hudText('HudHint', [0, -0.06, 0], 1);
	// Fairing cowl and central binnacle sit under the 2D instrument cluster; slim side fairings frame the lower corners.
	s.box('Cowl', [0, -0.33, -0.84], [0.92, 0.07, 0.3], 'armor', '.', [-8, 0, 0]);
	s.box('CowlLip', [0, -0.295, -0.71], [0.86, 0.018, 0.03], 'cyan');
	for (const side of [-1, 1]) {
		s.box(`CowlWing${side}`, [side * 0.56, -0.33, -0.5], [0.16, 0.04, 0.34], 'facet', '.', [-4, side * 18, side * 14]);
		s.box(`WingSeam${side}`, [side * 0.5, -0.305, -0.5], [0.01, 0.01, 0.3], 'cyan', '.', [-4, side * 18, side * 14]);
	}
	const binnacle = s.group('Binnacle', '.', [0, -0.4, -0.62], 'rotation_degrees = Vector3(-38, 0, 0)');
	s.box('Housing', [0, 0, 0.012], [0.56, 0.2, 0.05], 'armor', binnacle);
	s.box('BinnacleScreen', [0, 0, -0.016], [0.5, 0.16, 0.008], 'dark', binnacle);
	s.box('BezelTop', [0, 0.088, -0.022], [0.52, 0.008, 0.008], 'cyan', binnacle);
	s.box('BezelBottom', [0, -0.088, -0.022], [0.52, 0.008, 0.008], 'cyan', binnacle);
	s.marker('ExteriorScreen', [-0.36, -0.42, -0.58]);
	s.marker('TacticalScreen', [0.36, -0.42, -0.58]);
	// Handlebars run out from the clamp (hidden by the cluster) to grips in the lower screen corners.
	const rod = (name, a, b, radius, mat) => {
		const d = b.map((v, i) => v - a[i]);
		const len = Math.hypot(...d);
		const phi = Math.acos(d[1] / len), theta = Math.atan2(d[2], -d[0]);
		s.cylinder(name, a.map((v, i) => (v + b[i]) / 2), radius, len, mat, '.', [0, theta * 180 / Math.PI, phi * 180 / Math.PI]);
	};
	const lerp = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
	s.box('TopClamp', [0, -0.37, -0.62], [0.24, 0.05, 0.1], 'facet');
	for (const side of [-1, 1]) {
		const x = side;
		const clamp = [x * 0.1, -0.35, -0.6], gA = [x * 0.4, -0.3, -0.62], gB = [x * 0.58, -0.285, -0.56];
		const dir = gB.map((v, i) => v - gA[i]);
		rod(`Riser${side}`, [x * 0.1, -0.42, -0.63], clamp, 0.024, 'facet');
		rod(`Bar${side}`, clamp, gA, 0.017, 'armor');
		rod(`Grip${side}`, gA, gB, 0.026, 'dark');
		for (let i = 1; i < 4; i++) {
			const c = lerp(gA, gB, i / 4);
			rod(`GripRib${side}_${i}`, c, c.map((v, k) => v + dir[k] * 0.015), 0.029, 'facet');
		}
		rod(`BarEnd${side}`, gB, gB.map((v, k) => v + dir[k] * 0.08), 0.03, 'cyan');
		const pod = s.group(`ControlPod${side}`, '.', [x * 0.37, -0.29, -0.635]);
		s.box('Body', [0, 0, 0], [0.07, 0.05, 0.06], 'facet', pod);
		s.box('Switch', [0, 0.03, 0.01], [0.028, 0.012, 0.028], side < 0 ? 'amber' : 'cyan', pod);
		rod(`Lever${side}`, [x * 0.39, -0.32, -0.655], [x * 0.57, -0.31, -0.585], 0.008, 'facet');
	}
	s.marker('RiderEye', [0, 0, 0]);
	s.save([1.3, 0.6, 0.6], 'First-person bike cockpit art. Parent to cycle CameraTarget; put on a render layer only the riding camera sees. HUD Label3D text is controller-owned.');
}

{
	const s = new Scene('cycle_cradle');
	s.box('Base', [0, -0.2, 0], [4.8, 0.4, 6.6]);
	s.body('DeckCollision', [0, -0.2, 0], [4.8, 0.4, 6.6]);
	for (const side of [-1, 1]) {
		s.box(`Side${side}`, [side * 2.1, 0.28, 0], [0.45, 0.56, 5.8], 'facet');
		s.body(`SideCollision${side}`, [side * 2.1, 0.28, 0], [0.45, 0.56, 5.8]);
		s.box(`Guide${side}`, [side * 1.35, 0.015, 0], [0.045, 0.03, 5.5], 'cyan');
		const clamp = s.group(side < 0 ? 'ClampLeft' : 'ClampRight', '.', [side * 1.2, 0.1, 0.8]);
		s.box('Arm', [0, 0.25, 0], [0.25, 0.5, 0.75], 'facet', clamp);
		s.box('Pad', [-side * 0.22, 0.4, 0], [0.35, 0.2, 0.5], 'amber', clamp);
	}
	s.box('ConsoleBase', [2.65, 0.65, -1.4], [0.7, 1.3, 0.65], 'armor');
	s.box('ConsoleScreen', [2.65, 1.33, -1.4], [0.58, 0.04, 0.4], 'cyan', '.', [18, 0, 0]);
	for (let i = 0; i < 5; i++) s.box(`Key${i}`, [2.43 + i * 0.11, 1.33, -1.08], [0.06, 0.03, 0.06], 'amber');
	s.marker('DockPose', [0, 0, 0]);
	s.marker('ApproachStart', [0, 0, -13], '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.marker('ApproachEnd', [0, 0, -3], '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.marker('ExitPoint', [1.5, 0, 0]);
	s.marker('Console', [2.65, 1.35, -1.4]);
	s.save([6, 1.5, 6.6], 'Open approach is -Z; drive +Z to DockPose, then rotate to -Z before launch. No automatic docking logic.');
}
{
	// Trace-On relay: the mast sinks into its well when a rider holds the lit lane (local +/-Z), then the cycle crosses the pad.
	const s = new Scene('relay_pylon');
	s.cylinder('HandshakePad', [0, 0.03, 0], 1.95, 0.06, 'armor');
	s.torus('PadRing', [0, 0.075, 0], 1.72, 1.86, 'cyan');
	s.cylinder('MastWell', [0, 0.065, 0], 1.05, 0.02, 'dark');
	for (const x of [-1, 1]) s.box(`PadLaneMark${x}`, [x * 1.35, 0.075, 0], [0.08, 0.02, 1.1], 'amber');
	const mast = s.group('Mast');
	s.cylinder('Foot', [0, 0.18, 0], 1.0, 0.36, 'armor', mast, [0, 0, 0], 0.85);
	s.body('BaseCollision', [0, 0.25, 0], [1.8, 0.5, 1.8], mast);
	s.box('Column', [0, 2.1, 0], [0.9, 3.5, 0.9], 'facet', mast);
	s.body('ColumnCollision', [0, 2, 0], [0.9, 3.5, 0.9], mast);
	for (const x of [-0.5, 0.5]) for (const z of [-0.46, 0.46]) s.box(`Seam${x}_${z}`, [x, 2.1, z], [0.05, 2.9, 0.035], 'cyan', mast);
	s.cylinder('Crown', [0, 4.0, 0], 0.9, 0.35, 'armor', mast);
	s.torus('StatusLamp', [0, 4.2, 0], 0.62, 0.73, 'amber', mast);
	s.marker('StatusAnchor', [0, 4.4, 0], mast);
	// Lit approach lane on both ends: edge rails plus chevrons pointing at the pad.
	const lane = s.group('Lane');
	for (const end of [-1, 1]) {
		for (const x of [-1.8, 1.8]) s.box(`Rail${end}_${x}`, [x, 0.02, end * 13], [0.06, 0.03, 22], 'cyan', lane);
		for (const k of [5, 10, 15, 20]) {
			for (const x of [-1, 1]) {
				const dx = x * 0.62, dz = end * 0.55, len = Math.hypot(dx, dz);
				const deg = Math.atan2(-dz, dx) * 180 / Math.PI;
				s.box(`Chevron${end}_${k}_${x}`, [dx / 2, 0.025, end * k + dz / 2], [len, 0.025, 0.1], 'amber', lane, [0, deg, 0]);
			}
		}
	}
	s.marker('LinkSocket', [0, 0.2, 0]);
	s.save([3.9, 4.3, 44], 'Trace-On relay. Lane is local +/-Z. Controller lowers Mast and disables Mast/*Collision when the rider holds the lane; LinkSocket is the pad centre.');
}
{
	const s = new Scene('greg');
	s.group('VisualRoot');
	s.box('Pelvis', [0, 1.08, 0], [0.65, 0.32, 0.44], 'armor', 'VisualRoot');
	s.cylinder('Waist', [0, 1.29, 0], 0.19, 0.2, 'dark', 'VisualRoot');
	s.cylinder('Thorax', [0, 1.69, 0], 0.49, 0.7, 'armor', 'VisualRoot', [0, 0, 0], 0.37);
	for (const side of [-1, 1]) {
		s.box(`ChestPlate${side}`, [side * 0.22, 1.78, -0.32], [0.32, 0.46, 0.1], 'facet', 'VisualRoot', [0, 0, -side * 10]);
		s.box(`ChestChannel${side}`, [side * 0.22, 1.8, -0.38], [0.025, 0.27, 0.02], 'cyan', 'VisualRoot');
		s.cylinder(`Hip${side}`, [side * 0.23, 0.99, 0], 0.17, 0.19, 'dark', 'VisualRoot', [0, 0, 90]);
		s.box(`Thigh${side}`, [side * 0.24, 0.78, 0], [0.28, 0.4, 0.32], 'facet', 'VisualRoot', [0, 0, side * 5]);
		s.cylinder(`Knee${side}`, [side * 0.26, 0.54, -0.03], 0.15, 0.3, 'dark', 'VisualRoot', [0, 0, 90]);
		s.box(`Shin${side}`, [side * 0.27, 0.32, 0], [0.29, 0.38, 0.33], 'armor', 'VisualRoot', [-5, 0, 0]);
		s.box(`ShinChannel${side}`, [side * 0.27, 0.33, -0.18], [0.025, 0.24, 0.018], 'cyan', 'VisualRoot');
		s.box(`Foot${side}`, [side * 0.28, 0.07, -0.12], [0.36, 0.14, 0.62], 'facet', 'VisualRoot');
	}
	s.cylinder('Neck', [0, 2.12, 0], 0.12, 0.18, 'dark', 'VisualRoot');
	const head = s.group('HeadPivot', 'VisualRoot', [0, 2.22, 0]);
	s.cylinder('HeadArmor', [0, 0.18, 0], 0.24, 0.43, 'facet', head, [0, 0, 0], 0.19);
	s.box('VisorRecess', [0, 0.2, -0.212], [0.31, 0.09, 0.07], 'dark', head);
	s.box('OpticalBand', [0, 0.21, -0.253], [0.28, 0.025, 0.015], 'amber', head);
	s.box('Jaw', [0, 0.02, -0.04], [0.25, 0.1, 0.23], 'armor', head);
	for (const [name, side] of [['ServiceArmPivot', -1], ['ThermalArmPivot', 1]]) {
		const arm = s.group(name, 'VisualRoot', [side * 0.5, 1.98, 0]);
		s.cylinder('Shoulder', [0, -0.04, 0], 0.22, 0.23, 'dark', arm, [0, 0, 90]);
		s.box('Pauldron', [side * 0.09, -0.1, 0], [0.32, 0.28, 0.4], 'facet', arm, [0, 0, side * 10]);
		s.box('UpperArm', [side * 0.1, -0.33, 0], [0.22, 0.35, 0.25], 'armor', arm, [0, 0, side * 8]);
		s.cylinder('Elbow', [side * 0.14, -0.56, 0], 0.13, 0.25, 'dark', arm, [0, 0, 90]);
		s.box('Forearm', [side * 0.15, -0.76, -0.03], [side < 0 ? 0.22 : 0.34, 0.38, 0.31], 'facet', arm);
		if (side < 0) {
			for (let i = 0; i < 3; i++) s.box(`Finger${i}`, [-0.24 + i * 0.075, -1.04, -0.06], [0.05, 0.18, 0.09], 'armor', arm, [i * 7, 0, 0]);
			s.box('Thumb', [-0.02, -0.98, -0.14], [0.07, 0.13, 0.08], 'facet', arm, [0, 0, 30]);
		} else {
			for (let i = 0; i < 4; i++) s.box(`HeatSink${i}`, [0.16, -0.63 - i * 0.07, -0.196], [0.22, 0.022, 0.03], 'armor', arm);
			s.box('ThermalPort', [0.15, -0.98, -0.03], [0.21, 0.025, 0.18], 'amber', arm);
			s.marker('ThermalSocket', [0.15, -1.01, -0.03], arm);
		}
	}
	s.marker('CameraTarget', [0, 1.8, 0]);
	s.save([1.65, 2.65, 0.72], 'Greg: heavy service robot reserved for a later part. Same pivot rig as the old FEB stand-in; not used by the Trace Cycle scene.');
}
{
	// FEB: a human program in a pale Trace suit with cyan circuit lines. Front is -Z.
	const s = new Scene('feb');
	s.group('VisualRoot');
	const V = 'VisualRoot';
	for (const side of [-1, 1]) {
		const x = side * 0.1;
		s.capsule(`Thigh${side}`, [x, 0.71, 0], 0.075, 0.46, 'suit', V);
		s.sphere(`Knee${side}`, [x, 0.49, -0.01], 0.065, 'suit_dark', V);
		s.capsule(`Shin${side}`, [x, 0.28, 0], 0.06, 0.44, 'suit', V);
		s.box(`Boot${side}`, [x, 0.045, -0.035], [0.11, 0.09, 0.26], 'suit_dark', V);
		s.box(`BootLine${side}`, [x, 0.092, -0.035], [0.112, 0.008, 0.262], 'cyan', V);
		s.box(`ThighLine${side}`, [x + side * 0.022, 0.72, -0.072], [0.01, 0.34, 0.01], 'cyan', V);
		s.box(`ShinLine${side}`, [x + side * 0.018, 0.29, -0.058], [0.01, 0.3, 0.01], 'cyan', V);
		s.box(`OuterLegLine${side}`, [x + side * 0.074, 0.5, 0], [0.01, 0.8, 0.012], 'cyan', V);
	}
	s.cylinder('Hips', [0, 0.93, 0], 0.15, 0.17, 'suit', V, [0, 0, 0], 0.125);
	s.box('HipLine', [0, 0.9, -0.14], [0.2, 0.01, 0.01], 'cyan', V);
	s.cylinder('Waist', [0, 1.08, 0], 0.115, 0.22, 'suit', V, [0, 0, 0], 0.13);
	s.torus('Belt', [0, 1.0, 0], 0.118, 0.134, 'cyan', V);
	s.capsule('Chest', [0, 1.31, 0], 0.155, 0.48, 'suit', V);
	s.capsule('Shoulders', [0, 1.49, 0], 0.08, 0.44, 'suit', V, [0, 0, 90]);
	s.box('Collar', [0, 1.54, 0], [0.16, 0.04, 0.13], 'suit_dark', V);
	for (const side of [-1, 1]) {
		s.box(`ChestV${side}`, [side * 0.055, 1.37, -0.148], [0.012, 0.22, 0.01], 'cyan', V, [0, 0, side * 24]);
		s.box(`RibLine${side}`, [side * 0.12, 1.24, -0.105], [0.01, 0.2, 0.01], 'cyan', V, [0, side * 30, 0]);
	}
	s.box('SternumLine', [0, 1.18, -0.148], [0.012, 0.18, 0.01], 'cyan', V);
	s.cylinder('ChestCore', [0, 1.27, -0.152], 0.028, 0.012, 'white', V, [90, 0, 0]);
	s.cylinder('BackDisc', [0, 1.36, 0.16], 0.1, 0.02, 'suit_dark', V, [90, 0, 0]);
	s.torus('BackDiscRing', [0, 1.36, 0.172], 0.078, 0.098, 'cyan', V, [90, 0, 0]);
	s.cylinder('Neck', [0, 1.6, 0], 0.048, 0.12, 'skin', V);
	const head = s.group('HeadPivot', V, [0, 1.64, 0]);
	s.sphere('Skull', [0, 0.11, 0.005], 0.1, 'skin', head, [0, 0, 0], 0.24);
	s.sphere('Helmet', [0, 0.125, 0.012], 0.108, 'suit', head, [0, 0, 0], 0.108, true);
	s.torus('HelmetBrim', [0, 0.128, 0.012], 0.104, 0.114, 'cyan', head);
	s.box('HelmetRidge', [0, 0.232, 0.01], [0.02, 0.022, 0.2], 'suit_dark', head);
	s.box('RidgeLine', [0, 0.244, 0.01], [0.006, 0.006, 0.19], 'cyan', head);
	for (const side of [-1, 1]) {
		s.box(`EarGuard${side}`, [side * 0.1, 0.1, 0.015], [0.022, 0.09, 0.07], 'suit', head);
		s.box(`EarLine${side}`, [side * 0.112, 0.1, 0.015], [0.004, 0.06, 0.04], 'cyan', head);
		s.box(`Eye${side}`, [side * 0.034, 0.112, -0.094], [0.026, 0.009, 0.008], 'hair', head);
		s.box(`Brow${side}`, [side * 0.034, 0.13, -0.096], [0.03, 0.007, 0.01], 'hair', head);
	}
	s.box('Nose', [0, 0.088, -0.103], [0.018, 0.04, 0.02], 'skin', head, [-10, 0, 0]);
	s.box('Mouth', [0, 0.046, -0.094], [0.036, 0.006, 0.008], 'hair', head);
	s.box('Jaw', [0, 0.03, -0.035], [0.12, 0.05, 0.11], 'skin', head);
	for (const [name, side] of [['ServiceArmPivot', -1], ['ThermalArmPivot', 1]]) {
		const arm = s.group(name, V, [side * 0.22, 1.49, 0]);
		s.torus('ShoulderRing', [side * 0.01, 0, 0], 0.062, 0.082, 'cyan', arm, [0, 0, 90]);
		s.capsule('UpperArm', [side * 0.02, -0.17, 0], 0.055, 0.32, 'suit', arm, [0, 0, side * 4]);
		s.capsule('Forearm', [side * 0.035, -0.45, -0.01], 0.047, 0.3, 'suit', arm);
		s.box('ArmLine', [side * 0.083, -0.3, 0], [0.008, 0.5, 0.01], 'cyan', arm);
		s.box('Glove', [side * 0.035, -0.65, -0.01], [0.055, 0.11, 0.075], 'suit_dark', arm);
		s.torus('Cuff', [side * 0.035, -0.58, -0.01], 0.05, 0.064, side < 0 ? 'cyan' : 'amber', arm);
		if (side > 0) s.marker('ThermalSocket', [0.035, -0.62, -0.01], arm);
	}
	s.marker('CameraTarget', [0, 1.5, 0]);
	s.save([0.56, 1.88, 0.34], 'Human FEB in a Trace suit. Awakening rig only: HeadPivot and two independent arm pivots; no locomotion skeleton or gameplay collision.');
}
{
	const s = new Scene('stasis_cradle');
	s.cylinder('Base', [0, 0.16, 0], 1.5, 0.32, 'armor', '.', [0, 0, 0], 1.35);
	s.body('BaseCollision', [0, 0.16, 0], [2.4, 0.32, 2.4]);
	s.box('BackSpine', [0, 1.9, 0.75], [1.9, 3.4, 0.42], 'armor');
	s.body('BackCollision', [0, 1.9, 0.75], [1.9, 3.4, 0.42]);
	s.box('Crown', [0, 3.65, 0], [2.7, 0.35, 2.0], 'facet');
	for (const side of [-1, 1]) {
		s.box(`Post${side}`, [side * 1.16, 1.9, 0], [0.22, 3.4, 0.4], 'facet');
		s.box(`ColdSeam${side}`, [side * 1.04, 1.9, -0.23], [0.035, 3.1, 0.035], 'cyan');
		s.body(`PostCollision${side}`, [side * 1.16, 1.9, 0], [0.22, 3.4, 0.4]);
	}
	// Glass stasis capsule. Front lids hinge at the sides and swing outward.
	const R = 0.6, zc = -0.04, y0 = 0.52, y1 = 2.5, H = y1 - y0, yc = (y0 + y1) / 2;
	const cap = s.group('Capsule');
	const arc = (prefix, from, to, count, hinge, parent) => {
		const step = (to - from) / count;
		for (let i = 0; i < count; i++) {
			const t = (from + step * (i + 0.5)) * Math.PI / 180;
			const p = [R * Math.cos(t) - hinge[0], yc, zc - R * Math.sin(t) - hinge[2]];
			const w = 2 * R * Math.sin(Math.abs(step) * Math.PI / 360) + 0.012;
			s.box(`${prefix}${i}`, p, [w, H, 0.022], 'pod_glass', parent, [0, (t * 180 / Math.PI) + 90, 0]);
		}
	};
	arc('BackShell', 180, 360, 8, [0, 0, 0], cap);
	s.cylinder('Plinth', [0, y0 - 0.1, zc], R + 0.08, 0.2, 'armor', cap);
	s.torus('PlinthLight', [0, y0 + 0.01, zc], R - 0.01, R + 0.05, 'cyan', cap);
	s.cylinder('Cap', [0, y1 + 0.11, zc], R + 0.08, 0.22, 'armor', cap);
	s.cylinder('Dome', [0, y1 + 0.36, zc], R + 0.08, 0.28, 'facet', cap, [0, 0, 0], 0.32);
	s.torus('CapLight', [0, y1 - 0.01, zc], R - 0.01, R + 0.05, 'cyan', cap);
	s.cylinder('FrostCore', [0, y1 + 0.005, zc], R - 0.04, 0.02, 'white', cap);
	for (const [name, side, from, to] of [['LidLeft', -1, 90, 180], ['LidRight', 1, 0, 90]]) {
		const hinge = [side * R, 0, zc];
		const lid = s.group(name, cap, hinge);
		arc('Pane', from, to, 4, hinge, lid);
		s.cylinder('Hinge', [0, yc, 0], 0.035, H + 0.1, 'facet', lid);
		// Half of the crack seam rides on each lid edge (front centre, before opening).
		s.box('Seam', [-side * R, yc, -R - 0.004], [0.01, H - 0.04, 0.01], 'white', lid);
		s.box('Handle', [-side * R * (1 - 0.707 * 1.05), yc, -R * 0.707 * 1.05], [0.04, 0.5, 0.03], 'facet', lid, [0, side * 45, 0]);
	}
	// Fog emitters stay idle until the controller sets `emitting` when the coupler is pulled.
	const fogGroup = s.group('Fog', cap);
	const fogMat = s.resource('Material', `${res}/materials/fog_puff.tres`);
	const quad = s.subresource('QuadMesh', 'size = Vector2(0.55, 0.55)');
	const ramp = s.subresource('Gradient', 'offsets = PackedFloat32Array(0, 0.2, 0.7, 1)\ncolors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 0.8, 1, 1, 1, 0.35, 1, 1, 1, 0)');
	const grow = s.subresource('Curve', '_data = [Vector2(0, 0.45), 0.0, 0.0, 0, 0, Vector2(1, 1), 0.0, 0.0, 0, 0]\npoint_count = 2');
	for (const [name, pos, extents, amount, dir] of [
		['CrackFog', [0, yc, zc - R - 0.03], [0.02, H * 0.45, 0.02], 34, [0, -0.25, -1]],
		['BaseFogLeft', [-0.8, 0.35, -0.55], [0.18, 0.04, 0.12], 16, [-0.4, 0, -1]],
		['BaseFogRight', [0.8, 0.35, -0.55], [0.18, 0.04, 0.12], 16, [0.4, 0, -1]],
	]) {
		s.node(name, 'CPUParticles3D', fogGroup, `position = ${vec(pos)}\nmaterial_override = ExtResource("${fogMat}")\ncast_shadow = 0\nemitting = false\namount = ${amount}\nlifetime = 4.0\nmesh = SubResource("${quad}")\nemission_shape = 3\nemission_box_extents = ${vec(extents)}\ndirection = ${vec(dir)}\nspread = 30.0\ngravity = Vector3(0, -0.12, 0)\ninitial_velocity_min = 0.12\ninitial_velocity_max = 0.4\ndamping_min = 0.05\ndamping_max = 0.12\nscale_amount_min = 0.7\nscale_amount_max = 1.6\nscale_amount_curve = SubResource("${grow}")\ncolor_ramp = SubResource("${ramp}")`);
	}
	s.group('ClampPivots');
	for (const side of [-1, 1]) for (const [part, y] of [['Upper', 2.2], ['Lower', 1.0]]) {
		const p = s.group(`${part}${side < 0 ? 'Left' : 'Right'}`, 'ClampPivots', [side * 1.05, y, -0.32]);
		s.box('Arm', [-side * 0.2, 0, 0], [0.45, 0.13, 0.22], 'facet', p);
		s.box('Contact', [-side * 0.43, 0, -0.04], [0.08, 0.23, 0.12], 'amber', p);
	}
	s.group('VentSockets');
	s.marker('Left', [-0.8, 0.35, -0.55], 'VentSockets');
	s.marker('Right', [0.8, 0.35, -0.55], 'VentSockets');
	s.marker('FigureMount', [0, 0.32, 0]);
	s.marker('CouplerSocket', [1.85, 1.2, -0.83], '.', 'rotation_degrees = Vector3(-90, 0, 0)');
	s.marker('WarningPanel', [0, 3.95, -0.1]);
	s.box('SocketHousing', [1.85, 0.8, -0.4], [0.65, 1.6, 0.65], 'armor');
	s.body('SocketCollision', [1.85, 0.8, -0.4], [0.65, 1.6, 0.65]);
	s.box('SocketTrim', [1.85, 1.2, -0.74], [0.44, 0.42, 0.04], 'amber');
	s.cylinder('SocketRecess', [1.85, 1.2, -0.79], 0.16, 0.06, 'dark', '.', [90, 0, 0]);
	s.save([4.0, 3.9, 3], 'Standby cradle with a glass stasis capsule. Insert FEB at FigureMount. Capsule/LidLeft and Capsule/LidRight pivot on Y at the side hinges; Capsule/Fog/* are idle CPUParticles3D emitters. Clamp rotations are independent. Collision unchanged.');
}
{
	const s = new Scene('power_coupler');
	s.cylinder('Cartridge', [0, 0.22, 0], 0.14, 0.44, 'facet');
	for (const y of [0.04, 0.13, 0.31, 0.4]) s.torus(`Ring${y}`, [0, y, 0], 0.13, 0.165, 'amber');
	s.box('Handle', [0, 0.5, 0], [0.3, 0.09, 0.1], 'armor');
	s.marker('Grip', [0, 0.5, 0]);
	s.save([0.34, 0.55, 0.34], 'Removable coupler prop; inventory/pickup logic belongs to controller.');
}
{
	const s = new Scene('core_bank');
	s.box('Cabinet', [0, 0.6, 0], [2.3, 1.2, 0.8], 'armor');
	s.body('CabinetCollision', [0, 0.6, 0], [2.3, 1.2, 0.8]);
	for (let i = 0; i < 3; i++) {
		const p = s.group(`Core${i}`, '.', [(i - 1) * 0.65, 0.85, -0.46]);
		s.cylinder('Shell', [0, 0, 0], 0.16, 0.62, 'facet', p);
		for (const y of [-0.23, 0.23]) s.torus(`Band${y}`, [0, y, 0], 0.155, 0.175, 'cyan', p);
		s.marker('Pickup', [0, 0.15, -0.25], p);
	}
	s.save([2.3, 1.2, 1.0], 'Three separately hideable core props; finite collection must be controlled in VG.');
}
{
	const s = new Scene('vault_room');
	s.box('Floor', [0, -0.25, 0], [18, 0.5, 26], 'dark');
	s.body('FloorCollision', [0, -0.25, 0], [18, 0.5, 26]);
	s.box('Ceiling', [0, 6.4, 0], [18, 0.4, 26], 'armor');
	s.body('CeilingCollision', [0, 6.4, 0], [18, 0.4, 26]);
	for (const side of [-1, 1]) {
		s.box(`Wall${side}`, [side * 9, 3, 0], [0.5, 6, 26], 'armor');
		s.body(`WallCollision${side}`, [side * 9, 3, 0], [0.5, 6, 26]);
		for (let i = 0; i < 7; i++) {
			const z = -11 + i * 3.5;
			s.box(`Rib${side}_${i}`, [side * 8.6, 3, z], [0.45, 6, 0.3], 'facet');
			s.box(`RibSeam${side}_${i}`, [side * 8.33, 3.2, z], [0.025, 4.8, 0.035], 'cyan');
			s.box(`RoofRib${side}_${i}`, [side * 4.6, 6.1, z], [8, 0.25, 0.3], 'facet', '.', [0, 0, side * 3]);
		}
		s.box(`FloorGuide${side}`, [side * 2.2, 0.015, 0], [0.04, 0.025, 23], 'amber');
		s.box(`FrontPanel${side}`, [side * 5.6, 3, 13], [6.8, 6, 0.5], 'armor');
		s.body(`FrontCollision${side}`, [side * 5.6, 3, 13], [6.8, 6, 0.5]);
	}
	s.box('BackWall', [0, 3, -13], [18, 6, 0.5], 'armor');
	s.body('BackCollision', [0, 3, -13], [18, 6, 0.5]);
	s.box('Lintel', [0, 5.25, 13], [4.4, 1.5, 0.5], 'facet');
	s.body('LintelCollision', [0, 5.25, 13], [4.4, 1.5, 0.5]);
	s.box('ServiceConsole', [3.9, 0.65, -5.8], [1.25, 1.3, 0.8], 'facet');
	s.box('ServiceScreen', [3.9, 1.35, -5.8], [1.1, 0.06, 0.65], 'amber', '.', [15, 0, 0]);
	s.body('ConsoleCollision', [3.9, 0.65, -5.8], [1.25, 1.3, 0.8]);
	for (const x of [-2.1, 2.1]) s.box(`DoorSeam${x}`, [x, 2.2, 12.7], [0.07, 4.4, 0.07], 'cyan');
	s.marker('Entrance', [0, 0, 11.5]);
	s.marker('Exit', [0, 0, 14.5]);
	s.marker('Console', [3.9, 1.4, -5.4]);
	s.marker('CoreBank', [-4.5, 0, -7.0], '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.marker('StasisMount', [0, 0, -9.5], '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.save([18.5, 6.6, 26.5], 'Authored vault shell. Open 4.4m entrance at +Z; straight clear escape aisle. Props inserted separately at markers.');
}

function lighting(s) {
	const env = s.subresource('Environment', 'background_mode = 1\nbackground_color = Color(0.016, 0.013, 0.033, 1)\nambient_light_source = 3\nambient_light_color = Color(0.45, 0.59, 0.75, 1)\nambient_light_energy = 0.8\ntonemap_mode = 0');
	s.node('Environment', 'WorldEnvironment', '.', `environment = SubResource("${env}")`);
	s.node('Key', 'DirectionalLight3D', '.', 'rotation_degrees = Vector3(-42, -28, 0)\nlight_color = Color(0.6, 0.78, 1, 1)\nlight_energy = 1.6');
	s.node('Rim', 'DirectionalLight3D', '.', 'rotation_degrees = Vector3(-24, 135, 0)\nlight_color = Color(0.65, 0.28, 0.42, 1)\nlight_energy = 1.0');
}
{
	// Trace-styled landing: black grid panels, glowing edges, open lift cabin with controls.
	// Collision bodies are unchanged; every addition is visual only.
	const s = new Scene('deep_lift_lobby');
	s.box('Landing', [0, -0.25, 0], [10, 0.5, 10], 'trace_floor');
	s.body('LandingCollision', [0, -0.25, 0], [10, 0.5, 10]);
	s.outline('LandingEdge', [0, -0.25, 0], [10, 0.5, 10], 'cyan', '.', 0.05, ['top']);
	for (const side of [-1, 1]) {
		s.box(`Wall${side}`, [side * 5, 2, 0], [0.4, 4, 10], 'trace_wall');
		s.body(`WallCollision${side}`, [side * 5, 2, 0], [0.4, 4, 10]);
		s.outline(`WallEdge${side}`, [side * 5, 2, 0], [0.4, 4, 10], 'cyan', '.', 0.045, ['top', 'vertical']);
		s.box(`WallBand${side}`, [side * 4.79, 1.0, 0], [0.02, 0.05, 9.6], 'cyan');
		s.box(`Guide${side}`, [side * 1.7, 0.015, 2.6], [0.05, 0.025, 4.6], 'amber');
		s.box(`Front${side}`, [side * 3.4, 2, 5], [3.2, 4, 0.4], 'trace_wall');
		s.body(`FrontCollision${side}`, [side * 3.4, 2, 5], [3.2, 4, 0.4]);
		s.outline(`FrontEdge${side}`, [side * 3.4, 2, 5], [3.2, 4, 0.4], 'cyan', '.', 0.045, ['top', 'vertical']);
		s.box(`FrontBand${side}`, [side * 3.4, 1.0, 5.21], [3.0, 0.05, 0.02], 'cyan');
		s.box(`PortalJamb${side}`, [side * 1.86, 2.0, 5.23], [0.06, 4.0, 0.06], 'white');
	}
	s.box('Lintel', [0, 3.8, 5], [3.6, 0.4, 0.4], 'trace_wall');
	s.box('PortalHead', [0, 3.58, 5.23], [3.78, 0.06, 0.06], 'white');
	s.box('Back', [0, 2, -5], [10, 4, 0.4], 'trace_wall');
	s.body('BackCollision', [0, 2, -5], [10, 4, 0.4]);
	s.outline('BackEdge', [0, 2, -5], [10, 4, 0.4], 'cyan', '.', 0.045, ['top']);
	// Lift shaft head rising behind the landing: the landmark seen from the far dock.
	s.box('ShaftHead', [0, 4.6, -4.4], [4.4, 1.6, 1.2], 'trace_wall');
	s.outline('ShaftEdge', [0, 4.6, -4.4], [4.4, 1.6, 1.2], 'cyan', '.', 0.05);
	s.box('ShaftChevron', [0, 4.6, -3.79], [1.6, 0.18, 0.02], 'amber');
	narceanSign(s, 'Sign', 'DEEP SERVICE ISOLATION 04', 'DEEP SERVICE / ISOLATION 04', [0, 4.72, -3.77], { unit: 0.0135, glossSize: 40 });
	const cabin = s.group('Cabin');
	s.box('LiftDeck', [0, 0.05, -2.2], [3.5, 0.1, 4.5], 'trace_floor', cabin);
	s.body('CabinCollision', [0, 0.05, -2.2], [3.5, 0.1, 4.5], cabin);
	s.box('DeckRing', [0, 0.105, -2.2], [3.2, 0.01, 4.2], 'cyan', cabin);
	s.box('DeckInset', [0, 0.108, -2.2], [3.1, 0.01, 4.1], 'dark', cabin);
	for (const side of [-1, 1]) {
		s.box(`Rail${side}`, [side * 1.8, 1.7, -2.2], [0.12, 3.4, 4.5], 'trace_wall', cabin);
		s.box(`Signal${side}`, [side * 1.72, 1.9, 0.05], [0.04, 2.5, 0.04], 'cyan', cabin);
		for (const z of [-0.6, -2.2, -3.8]) s.box(`WallStrip${side}_${z}`, [side * 1.735, 1.85, z], [0.012, 3.0, 0.035], 'cyan', cabin);
		s.cylinder(`Handrail${side}`, [side * 1.6, 0.98, -2.2], 0.025, 3.9, 'facet', cabin, [90, 0, 0]);
		for (const z of [-0.6, -3.8]) s.box(`RailBracket${side}_${z}`, [side * 1.67, 0.98, z], [0.13, 0.03, 0.03], 'armor', cabin);
		// Door leaves parked in their pockets beside the opening.
		s.box(`DoorLeaf${side}`, [side * 1.6, 1.7, 0.12], [0.75, 3.3, 0.06], 'trace_wall', cabin);
		s.box(`DoorEdge${side}`, [side * 1.225, 1.7, 0.155], [0.025, 3.3, 0.02], 'cyan', cabin);
	}
	s.box('CabinBack', [0, 1.75, -4.47], [3.48, 3.3, 0.06], 'trace_wall', cabin);
	s.box('CabinBackGlow', [0, 1.75, -4.43], [1.2, 2.6, 0.01], 'violet', cabin);
	s.box('CabinBackFrame', [0, 1.75, -4.425], [1.3, 2.7, 0.006], 'cyan', cabin);
	s.box('Ceiling', [0, 3.45, -2.2], [3.72, 0.1, 4.6], 'armor', cabin);
	s.box('CeilingLight', [0, 3.39, -2.2], [1.6, 0.02, 3.0], 'white', cabin);
	s.light('CabinLight', [0, 2.9, -2.2], '0.55, 0.85, 1', 1.4, 5.5, cabin);
	// Interior control panel on the right wall, facing the rider.
	const panel = s.group('ControlPanel', cabin, [1.7, 1.3, -0.9]);
	s.box('Plate', [0, 0, 0], [0.05, 0.8, 0.46], 'armor', panel);
	for (const sy of [-1, 1]) s.box(`FrameH${sy}`, [-0.028, sy * 0.4, 0], [0.006, 0.014, 0.47], 'cyan', panel);
	for (const sz of [-1, 1]) s.box(`FrameV${sz}`, [-0.028, 0, sz * 0.23], [0.006, 0.8, 0.014], 'cyan', panel);
	s.box('Screen', [-0.03, 0.27, 0], [0.01, 0.16, 0.34], 'dark', panel);
	narceanSign(s, 'ScreenText', 'LEVEL 04', 'LEVEL -04', [-0.037, 0.29, 0], { unit: 0.0028, rotation: [0, -90, 0], parent: panel, glossSize: 30 });
	for (let r = 0; r < 4; r++) for (let c = 0; c < 2; c++) {
		const lit = r === 3 && c === 0;
		s.cylinder(`Button${r}_${c}`, [-0.032, 0.08 - r * 0.1, -0.08 + c * 0.16], 0.032, 0.02, lit ? 'amber' : r === 0 ? 'white' : 'cyan', panel, [0, 0, 90]);
	}
	s.cylinder('Stop', [-0.032, -0.33, 0.12], 0.04, 0.025, 'red', panel, [0, 0, 90]);
	s.box('KeySlot', [-0.03, -0.33, -0.1], [0.012, 0.03, 0.09], 'dark', panel);
	// Floor indicators above the opening: outside faces the landing, inside faces the rider.
	s.box('IndicatorHousing', [0, 3.15, 0.1], [1.1, 0.34, 0.1], 'armor', cabin);
	s.box('IndicatorScreen', [0, 3.15, 0.153], [0.95, 0.24, 0.005], 'dark', cabin);
	narceanSign(s, 'IndicatorOut', 'DOWN 04', 'DOWN / LEVEL -04', [0, 3.18, 0.158], { unit: 0.0075, parent: cabin, mat: 'amber', glossSize: 30 });
	narceanSign(s, 'IndicatorIn', 'ISOLATION 04', 'ISOLATION 04', [0, 3.18, 0.047], { unit: 0.0058, rotation: [0, 180, 0], parent: cabin, glossSize: 30 });
	// Threshold: amber chevrons on black.
	s.box('Threshold', [0, 0.012, 0.32], [3.4, 0.024, 0.34], 'dark');
	for (let i = 0; i < 9; i++) s.box(`Chevron${i}`, [-1.5 + i * 0.375, 0.026, 0.32], [0.09, 0.006, 0.4], 'amber', '.', [0, 35, 0]);
	// External call station on the right jamb.
	s.box('CallPanel', [1.96, 1.3, 0.12], [0.2, 0.46, 0.04], 'armor');
	s.cylinder('CallUp', [1.96, 1.42, 0.145], 0.035, 0.012, 'dark', '.', [90, 0, 0]);
	s.cylinder('CallDown', [1.96, 1.28, 0.145], 0.035, 0.012, 'amber', '.', [90, 0, 0]);
	s.box('CallLight', [1.96, 1.13, 0.143], [0.14, 0.02, 0.006], 'cyan');
	// Landing console with a raised screen and keypad.
	s.box('ConsoleBody', [2.6, 0.7, 1], [0.65, 1.4, 0.6], 'trace_wall');
	s.outline('ConsoleEdge', [2.6, 0.7, 1], [0.65, 1.4, 0.6], 'cyan', '.', 0.025, ['top', 'vertical']);
	s.box('ConsoleFace', [2.6, 1.42, 1], [0.55, 0.035, 0.45], 'amber');
	s.box('ConsoleScreen', [2.6, 1.72, 0.82], [0.6, 0.4, 0.04], 'dark', '.', [-15, 0, 0]);
	s.box('ConsoleScreenGlow', [2.6, 1.72, 0.8], [0.5, 0.3, 0.004], 'cyan', '.', [-15, 0, 0]);
	s.marker('Entrance', [0, 0, 4.2]);
	s.marker('LiftPose', [0, 0.1, -2.2]);
	s.marker('Console', [2.6, 1.45, 1]);
	s.save([10.4, 5.4, 10.4], 'Separate deep-lift landing in Trace grid panels. Cabin is a static art group with interior controls and light; VG owns transfer/fade, not moving StaticBody3D physics. Collision bodies unchanged.');
}
{
	const s = new Scene('cycle_preview');
	s.box('Floor', [0, -0.2, 0], [18, 0.4, 18], 'dark');
	s.instance('Cycle', 'trace_cycle', [0, 0, 0]);
	s.instance('Remote', 'security_cycle', [-3.5, 0, 3.0], '.', [0, 165, 0]);
	lighting(s);
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(6, 3.6, -8)\nrotation_degrees = Vector3(-16, 140, 0)\nfov = 38.0\ncurrent = true');
	s.save([18, 3, 18], 'Close art inspection: player front/side and remote rear.');
}
{
	const s = new Scene('vault_preview');
	s.instance('Vault', 'vault_room');
	s.instance('Stasis', 'stasis_cradle', [0, 0, -9.5], '.', [0, 180, 0]);
	s.instance('FEB', 'feb', [0, 0.32, -9.5], '.', [0, 180, 0]);
	s.instance('Cores', 'core_bank', [-4.5, 0, -7], '.', [0, 180, 0]);
	s.instance('Coupler', 'power_coupler', [-1.85, 1.2, -8.67], '.', [90, 0, 0]);
	s.label('Isolation', 'ISOLATION / 04', [0, 4.3, -9.3], 64);
	lighting(s);
	s.node('VaultFill', 'OmniLight3D', '.', 'position = Vector3(0, 3.5, -6)\nlight_color = Color(0.6, 0.8, 1, 1)\nlight_energy = 5.0\nomni_range = 22.0');
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(3.5, 2.6, -1.7)\nrotation_degrees = Vector3(-7, 24, 0)\nfov = 62.0\ncurrent = true');
	s.save([18.5, 6.6, 26.5], 'Assembled static vault preview, not a controller.');
}
{
	const s = new Scene('asset_gallery');
	s.box('Plinth', [0, -0.3, 0], [24, 0.6, 24], 'dark');
	s.instance('TraceCycle', 'trace_cycle', [-4.4, 0, 3.2], '.', [0, 150, 0]);
	s.instance('SecurityCycle', 'security_cycle', [-0.5, 0, 3.0], '.', [0, 150, 0]);
	s.instance('Cradle', 'cycle_cradle', [-4.4, 0, -4.8], '.', [0, 180, 0]);
	s.instance('Pylon', 'relay_pylon', [6.1, 0, -4]);
	s.instance('Stasis', 'stasis_cradle', [3, 0, 0], '.', [0, 180, 0]);
	s.instance('FEB', 'feb', [3, 0.32, 0], '.', [0, 180, 0]);
	s.instance('Greg', 'greg', [8.4, 0, -1.4], '.', [0, 200, 0]);
	s.instance('CoreBank', 'core_bank', [7.1, 0, 3.3], '.', [0, 180, 0]);
	s.label('TraceLabel', 'TRACE / MAINTENANCE', [-4.5, 0.5, 6], 40);
	s.label('SecurityLabel', 'REMOTE / ENFORCEMENT', [-0.5, 0.5, 5.7], 34);
	lighting(s);
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(11, 8, 15)\nrotation_degrees = Vector3(-25, 28, 0)\nfov = 60.0\ncurrent = true');
	s.save([24, 5, 24], 'Art review gallery only; does not modify Play.');
}
{
	const s = new Scene('void_crossing');
	// Physics support is invisible; only the two banks have continuous ground.
	s.body('SupportCollision', [0, -0.1, 0], [160, 0.2, 240], '.', 4);
	for (const [name, sign] of [['Near', 1], ['Far', -1]]) {
		s.box(`${name}Land`, [0, -16.3, sign * 136], [174, 32, 72], 'bank_rock');
		s.box(`${name}DockApron`, [0, -0.29, sign * 111], [36, 0.5, 22], 'trace_floor');
		for (let i = 0; i < 11; i++) {
			const x = (i - 5) * 16;
			const depth = 22 + (i % 4) * 7;
			s.box(`${name}Cliff${i}`, [x, -depth * 0.5 - 0.5, sign * (101.5 + (i % 3))], [14, depth, 7], 'armor', '.', [0, (i % 3 - 1) * 12, 0]);
			s.box(`${name}EdgeLamp${i}`, [x, 0.06, sign * 100.2], [2.4, 0.08, 0.12], 'amber');
		}
	}
	for (const side of [-1, 1]) {
		s.box(`BoundaryX${side}`, [side * 80, 0, 0], [0.15, 0.035, 240], 'amber');
		s.box(`BoundaryZ${side}`, [0, 0, side * 120], [160, 0.035, 0.15], 'amber');
		s.body(`BoundaryXCollision${side}`, [side * 80.5, 2, 0], [1, 4, 242]);
		s.body(`BoundaryZCollision${side}`, [0, 2, side * 120.5], [162, 4, 1]);
		for (let z = -100; z <= 100; z += 40) {
			s.cylinder(`Support${side}_${z}`, [side * 86, -6, z], 2.8, 18, 'armor', '.', [0, 0, 0], 1.0);
			s.torus(`PylonRim${side}_${z}`, [side * 86, 3.1, z], 1, 1.2, 'cyan');
		}
	}
	s.instance('NearCradle', 'cycle_cradle', [0, 0, 105]);
	s.instance('FarCradle', 'cycle_cradle', [0, 0, -105], '.', [0, 180, 0]);
	s.instance('DeepLiftLobby', 'deep_lift_lobby', [-15, 0, -112]);
	for (const [i, p] of [[-48, 0, 42], [44, 0, -18], [-18, 0, -64]].entries()) {
		s.instance(`Relay${i}`, 'relay_pylon', p);
		s.cylinder(`RelaySuspension${i}`, [p[0], -4, p[2]], 0.18, 8, 'facet');
		s.cylinder(`RelayAnchor${i}`, [p[0], -8, p[2]], 0.85, 0.4, 'armor');
		s.torus(`RelayField${i}`, [p[0], -7.7, p[2]], 0.9, 1.03, 'cyan');
	}
	const depth = s.group('AbyssDepth');
	for (let i = 0; i < 18; i++) {
		const x = -70 + (i % 6) * 28;
		const z = -66 + Math.floor(i / 6) * 65 + ((i % 3) - 1) * 8;
		const y = -85 - (i % 4) * 13;
		s.box(`Ruin${i}`, [x, y, z], [12 + i % 5, 7, 21], 'depth', depth, [7, (i * 29) % 180, -5]);
		s.cylinder(`BrokenTower${i}`, [x + 5, y + 14, z - 3], 2.3, 25, 'depth', depth, [0, 0, (i % 3 - 1) * 12], 1.1);
		s.box(`Window${i}`, [x + 5, y + 24, z - 4.3], [0.8, 0.3, 0.12], 'depth_light', depth);
	}
	const hazeMat = s.resource('Material', `${res}/materials/abyss_haze.tres`);
	const hazeMesh = s.subresource('PlaneMesh', 'size = Vector2(210, 260)');
	for (let i = 0; i < 3; i++) {
		s.node(`Haze${i}`, 'MeshInstance3D', depth, `position = ${vec([0, -30 - i * 24, 0])}\nmesh = SubResource("${hazeMesh}")\nmaterial_override = ExtResource("${hazeMat}")\ncast_shadow = 0`);
		s.pieces++;
	}
	// Distant land seen through the void; shader-only, no collision.
	const floorMat = s.resource('Material', `${res}/materials/abyss_floor.tres`);
	const floorMesh = s.subresource('PlaneMesh', 'size = Vector2(7000, 7000)');
	s.node('AbyssFloor', 'MeshInstance3D', depth, `position = ${vec([0, -460, 0])}\nmesh = SubResource("${floorMesh}")\nmaterial_override = ExtResource("${floorMat}")\ncast_shadow = 0`);
	s.pieces++;
	s.marker('PlayerSpawn', [0, 0, 105]);
	s.marker('SecuritySpawn', [63, 0, -90], '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.marker('NearExit', [4, 0, 108]);
	s.marker('FarLift', [-15, 0, -107.8]);
	s.save([210, 150, 344], 'Open void between cliff banks at Z=+/-100. Invisible layer-4 support only; no floor/grid mesh at riding height. Non-colliding ruins and patchy haze far below; shader-lit distant land at Y=-460. Docks and marker transforms unchanged.');
	emit('route.json', JSON.stringify({
		version: 1, units: 'metres', forward: '-Z', up: '+Y',
		scene: `${res}/scenes/void_crossing.tscn`,
		support_bounds: { min: [-80, -120], max: [80, 120], axes: ['x', 'z'] },
		ride_y: 0, clearance_radius: 0.75, cycle_length: 4.2,
		void_gap_z: [-100, 100], support_collision_layer: 4,
		presentation: 'Open void; solid land only at the near and far banks. No continuous visual support field.',
		abyss: 'Non-colliding ruined structures below Y=-45; patchy haze at Y=-30/-54/-78. These are scenery, never traversable floor.',
		near_dock: [0, 0, 105], far_dock: [0, 0, -105],
		relay_order: ['Relay0/LinkSocket', 'Relay1/LinkSocket', 'Relay2/LinkSocket'],
		relay_capture_radius: 2.0, relay_lane_half_width: 1.8, relay_lane_axis: 'local Z', maximum_proposed_speed: 64,
		warning: 'Art layout only. Validate reachability and collision sweeps in VG before choosing gameplay balance.',
	}, null, 2) + '\n');
}
const CRADLE_CODE = '2741';
{
	// Wrist-mounted interface translator: Narcean metal slate with a cyan lens. Pickup and equipped view use the same scene.
	const s = new Scene('interface_translator');
	s.box('Slate', [0, 0, 0], [0.16, 0.022, 0.1], 'armor');
	s.outline('Bezel', [0, 0.012, 0], [0.16, 0.002, 0.1], 'cyan', '.', 0.004, ['top']);
	s.box('Screen', [-0.012, 0.0125, 0], [0.11, 0.002, 0.075], 'dark');
	const read = s.group('Readout', '.', [-0.012, 0.0145, 0], 'rotation_degrees = Vector3(-90, 0, 0)');
	narceanStrokes(s, read, 'LEXICON', 0.0013);
	s.sphere('LensGlass', [0.062, 0.016, 0], 0.012, 'cyan', '.', [0, 0, 0], 0.012, true);
	s.torus('LensRing', [0.062, 0.012, 0], 0.012, 0.016, 'facet');
	for (const z of [-1, 1]) s.box(`Strap${z}`, [0, -0.02, z * 0.035], [0.17, 0.012, 0.018], 'suit_dark', '.', [0, 0, 0]);
	s.marker('LensPoint', [0.062, 0.03, 0]);
	s.marker('Grip', [0, -0.03, 0]);
	s.save([0.17, 0.05, 0.1], 'Interface Translator item. Possession gates English glosses on interface-script signs (metadata text_kind = "interface"); high script still needs the FEB.');
}
{
	// Dead maintenance post holding the translator in a charging shelf.
	const s = new Scene('translator_post');
	s.box('Pillar', [0, 0.8, 0], [0.5, 1.6, 0.36], 'trace_wall');
	s.outline('PillarEdge', [0, 0.8, 0], [0.5, 1.6, 0.36], 'cyan', '.', 0.02, ['vertical']);
	s.box('DeadScreen', [0, 1.3, 0.185], [0.38, 0.28, 0.01], 'dark');
	s.box('ScreenCrack', [0.04, 1.32, 0.191], [0.3, 0.008, 0.004], 'depth_light', '.', [0, 0, 28]);
	s.box('Shelf', [0, 0.95, 0.24], [0.34, 0.03, 0.18], 'facet');
	s.box('ShelfGlow', [0, 0.968, 0.24], [0.2, 0.004, 0.12], 'amber');
	s.instance('Translator', 'interface_translator', [0, 0.99, 0.24], '.', [0, 90, 0]);
	narceanSign(s, 'PostLabel', 'LEXICON SERVICE', 'LEXICON SERVICE', [0, 1.52, 0.186], { unit: 0.0042, glossSize: 34 });
	s.marker('PickupPoint', [0, 0, 0.9]);
	s.save([0.5, 1.6, 0.6], 'Where the translator is found (placement open). Hide Translator after pickup; PickupPoint is the on-foot E prompt.');
}
{
	// Four-glyph release keypad. Keys show numeral glyphs; digit glosses appear only with the translator.
	const s = new Scene('release_lock');
	s.box('Pedestal', [0, 0.55, 0], [0.62, 1.1, 0.42], 'trace_wall');
	s.outline('PedestalEdge', [0, 0.55, 0], [0.62, 1.1, 0.42], 'cyan', '.', 0.018, ['vertical', 'top']);
	const face = s.group('Face', '.', [0, 1.34, 0.05], 'rotation_degrees = Vector3(-35, 0, 0)');
	s.box('Plate', [0, 0, 0], [0.6, 0.42, 0.04], 'armor', face);
	s.box('Display', [0, 0.14, 0.022], [0.46, 0.09, 0.006], 'dark', face);
	for (let i = 0; i < 4; i++) {
		const slot = s.group(`Slot${i}`, face, [-0.15 + i * 0.1, 0.14, 0.026]);
		for (const y of [-1, 1]) s.box(`EdgeY${y}`, [0, y * 0.033, 0], [0.07, 0.004, 0.003], 'facet', slot);
		for (const x of [-1, 1]) s.box(`EdgeX${x}`, [x * 0.033, 0, 0], [0.004, 0.07, 0.003], 'facet', slot);
		s.group(`Entry${i}`, face, [-0.15 + i * 0.1, 0.14, 0.03]);
	}
	for (let d = 0; d < 10; d++) {
		const key = s.group(`Key${d}`, face, [-0.2 + (d % 5) * 0.1, d < 5 ? 0.0 : -0.11, 0.022]);
		s.box('Cap', [0, 0, 0], [0.08, 0.08, 0.012], 'dark', key);
		const glyph = s.group('Glyph', key, [0, 0.005, 0.008]);
		narceanStrokes(s, glyph, String(d), 0.0032, 'amber');
		s.node('Gloss', 'Label3D', key, `position = ${vec([0.026, -0.03, 0.008])}\ntext = "${d}"\nfont_size = 24\npixel_size = 0.0007\nmodulate = Color(0.55, 0.97, 1, 1)\nbillboard = 0\nvisible = false`);
	}
	s.box('ClampLight', [0.25, 0.14, 0.024], [0.04, 0.06, 0.006], 'red', face);
	s.marker('UsePoint', [0, 0, 0.9]);
	s.marker('DisplayPoint', [0, 1.43, 0.12]);
	s.save([0.62, 1.55, 0.5], `Cradle release lock. Controller writes entered numeral glyphs into Face/Entry0..3, swaps ClampLight to cyan on release, and shows Key*/Gloss only while the translator is held. Dev code ${CRADLE_CODE}.`);
}
{
	// Service tag carrying the cradle code as spelled-out interface-script words.
	const s = new Scene('service_tag');
	s.box('Plate', [0, 0, 0], [1.5, 0.86, 0.04], 'armor');
	s.outline('PlateEdge', [0, 0, 0], [1.5, 0.86, 0.04], 'amber', '.', 0.012, ['top', 'bottom', 'vertical']);
	s.box('Face', [0, 0, 0.022], [1.42, 0.78, 0.004], 'dark');
	const words = [...CRADLE_CODE].map(d => NUMBER_WORDS[+d]).join(' ');
	narceanSign(s, 'Line0', 'CRADLE RELEASE', 'CRADLE RELEASE', [0, 0.22, 0.028], { unit: 0.0062, mat: 'amber', glossSize: 24 });
	narceanSign(s, 'Line1', words, words, [0, -0.12, 0.028], { unit: 0.0062, glossSize: 24 });
	for (const x of [-1, 1]) s.box(`Bolt${x}`, [x * 0.68, 0.36, 0.025], [0.03, 0.03, 0.01], 'facet');
	s.save([1.5, 0.86, 0.05], `Code clue for the yard dock cradle. Without the translator only strokes show; with it, Line0/Gloss and Line1/Gloss read "CRADLE RELEASE: ${words}". Numbers are spelled out, so keypad glyphs cannot be shape-matched.`);
}
{
	// Navigation beacon: unshaded additive column plus ground ring; no lights, no collision.
	const s = new Scene('relay_beacon');
	s.cylinder('Beam', [0, 80, 0], 1.6, 160, 'beacon_cyan', '.', [0, 0, 0], 0.5);
	s.cylinder('Halo', [0, 30, 0], 4.5, 60, 'beacon_cyan', '.', [0, 0, 0], 1.2);
	s.torus('GroundRing', [0, 0.06, 0], 3.4, 3.7, 'cyan');
	s.marker('Top', [0, 160, 0]);
	s.save([9, 160, 9], 'Relay/dock locator column. Controller sets Beam/Halo material_override to beacon_cyan (available), beacon_dim (spent), beacon_white (dock) or beacon_amber (vault unlocked), and hides it until discovered beyond 600 m.');
}
{
	// End-of-road dock in Backlight yard space. Origin is DockPose; the void is local +Z.
	const s = new Scene('yard_dock');
	s.box('Apron', [0, -0.29, 2], [16, 0.5, 24], 'trace_floor');
	s.instance('Cradle', 'cycle_cradle', [0, 0, 0], '.', [0, 180, 0]);
	for (const x of [-1, 1]) {
		s.box(`GatePost${x}`, [x * 8, 3, 6], [0.6, 6, 0.6], 'armor');
		s.box(`GatePostLine${x}`, [x * 7.68, 3, 6], [0.05, 5.6, 0.05], 'cyan');
		s.box(`CantileverStrut${x}`, [x * 6, -4, 10], [0.5, 0.5, 11], 'facet', '.', [-40, 0, 0]);
	}
	s.box('GateBeam', [0, 6.2, 6], [16.6, 0.6, 0.6], 'armor');
	s.box('GateBeamLine', [0, 5.86, 5.68], [15.4, 0.06, 0.05], 'cyan');
	narceanSign(s, 'GateSign', 'TRACE DOCK', 'TRACE DOCK', [0, 6.75, 5.66], { unit: 0.045, rotation: [0, 180, 0], glossSize: 48 });
	for (let k = 0; k < 4; k++) for (const x of [-1, 1]) s.box(`OutChevron${k}_${x}`, [x * 0.45, 0.03, 8 + k * 1.6], [1.15, 0.025, 0.12], 'amber', '.', [0, x * 35, 0]);
	s.box('RoadSignPost', [-7, 1.6, -9], [0.25, 3.2, 0.25], 'armor');
	s.box('RoadSignPanel', [-7, 3.1, -9], [3.6, 1.1, 0.12], 'dark');
	narceanSign(s, 'RoadSign', 'TRACE CYCLE', 'TRACE CYCLE', [-6.75, 3.3, -9.08], { unit: 0.022, rotation: [0, 180, 0], mat: 'amber', glossSize: 44 });
	for (const k of [0, 1]) for (const y of [-1, 1]) s.box(`RoadArrow${k}_${y}`, [-8.35 + k * 0.18, 3.1 + y * 0.09, -9.08], [0.24, 0.05, 0.02], 'amber', '.', [0, 0, y * 40]);
	// High script: the translator cannot read it; the FEB can later.
	s.box('DirectivePanel', [7, 3.1, -9], [3.6, 0.8, 0.12], 'dark');
	s.box('DirectivePost', [7, 1.4, -9], [0.25, 2.8, 0.25], 'armor');
	narceanSign(s, 'Directive', 'NO BODY LEAVES THE YARD UNCOMPILED', 'NO BODY LEAVES THE YARD UNCOMPILED', [7, 3.2, -9.08], { kind: 'high', unit: 0.0105, rotation: [0, 180, 0], mat: 'white', glossSize: 30 });
	s.instance('ReleaseLock', 'release_lock', [-3.4, 0, -4.6], '.', [0, 180, 0]);
	s.marker('ReleasePoint', [-3.4, 0, -5.5]);
	s.box('ChargeTotem', [5.6, 0.9, -2], [0.6, 1.8, 0.6], 'armor');
	s.box('ChargeBar', [5.6, 0.95, -2.31], [0.16, 1.4, 0.03], 'cyan');
	s.marker('DockPose', [0, 0, 0], '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.marker('BoardPoint', [-3.2, 0, -2]);
	s.marker('GatePose', [0, 0, 6], '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.marker('ChargeDisplay', [5.6, 1.0, -2.35]);
	s.save([17, 6.5, 24], 'Yard end-of-road dock. Cradle rotated so the open approach faces the void (+Z). The cycle launches through the gate in the yard rim; BoardPoint is the on-foot E prompt from the road.');
}
const YARD = { minX: -118, maxX: 118, minZ: -12, maxZ: 420 };
const yardDock = [15, 0, 414];
const gateX = [7, 23];
{
	// Low-poly stand-in for the procedural Backlight yard (backlight_yard.vg), used only by the isolated dest.
	const s = new Scene('yard_proxy');
	const cx = (YARD.minX + YARD.maxX) / 2, cz = (YARD.minZ + YARD.maxZ) / 2;
	const w = YARD.maxX - YARD.minX, d = YARD.maxZ - YARD.minZ;
	s.box('Deck', [cx, -3, cz], [w, 6, d], 'trace_floor');
	s.box('Underside', [cx, -14, cz], [w - 20, 16, d - 20], 'bank_rock');
	for (let i = 0; i < 6; i++) s.cylinder(`Root${i}`, [i % 2 ? 60 : -60, -70, 30 + i * 70], 6, 100, 'armor', '.', [0, 0, 0], 2);
	for (let i = 0; i < 12; i++) {
		const z = 12 + i * 34;
		for (const side of [-1, 1]) {
			const tw = 12 + (i % 3) * 3, th = 22 + (i % 4) * 8, td = tw * 0.72;
			const x = side < 0 ? -76 - tw : 76;
			s.box(`Tower${side}_${i}`, [x + tw / 2, th / 2, z + td / 2], [tw, th, td], 'armor');
			s.box(`TowerTrace${side}_${i}`, [x + tw * 0.67, th * 0.4, z - 0.03], [0.14, th * 0.7, 0.05], 'cyan');
		}
	}
	for (let i = 0; i < 8; i++) {
		const z = 36 + Math.floor(i / 2) * 94, x = i % 2 === 0 ? -52 : 28;
		s.box(`PressHall${i}`, [x + 11, 4.5, z + 12], [22, 9, 24], 'facet');
	}
	for (const x of [-64, 64]) for (const z of [70, 164, 258, 352]) s.cylinder(`Silo${x}_${z}`, [x, 8, z], 3, 16, 'armor');
	for (const z of [88, 182, 276]) s.box(`GateArch${z}`, [0, 12.25, z + 1.5], [32, 2.5, 3], 'armor');
	for (const x of [-6.5, 6.5]) s.box(`RoadLine${x}`, [x, 0.03, 204], [0.16, 0.03, 420], 'white');
	s.box('LiftHead', [0, 4, 402], [8, 8, 8], 'armor');
	s.box('LiftHeadLine', [0, 3.8, 397.97], [0.24, 7.5, 0.05], 'amber');
	s.save([w, 70, d], 'Static silhouette of the Backlight yard in yard coordinates (+Z north, road on X=0, lift head at the north end). Visual only; the real yard replaces it in a later campaign-v2 merge.');
}
{
	const s = new Scene('yard_void_field');
	const F = { minX: -760, maxX: 760, minZ: -560, maxZ: 980 };
	const fw = F.maxX - F.minX, fd = F.maxZ - F.minZ, fcx = (F.minX + F.maxX) / 2, fcz = (F.minZ + F.maxZ) / 2;
	s.body('SupportCollision', [fcx, -0.1, fcz], [fw, 0.2, fd], '.', 4);
	s.instance('Yard', 'yard_proxy');
	// Containment rail around the yard deck; the only gap is the dock gate.
	const rim = s.group('YardRim');
	const rail = (name, a, b) => {
		const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
		const mid = [(a[0] + b[0]) / 2, 0.6, (a[1] + b[1]) / 2];
		const alongX = Math.abs(b[0] - a[0]) > 0.01;
		const size = alongX ? [len, 1.2, 0.35] : [0.35, 1.2, len];
		s.box(`${name}`, mid, size, 'armor', rim);
		s.box(`${name}Line`, [mid[0], 1.22, mid[2]], alongX ? [len, 0.05, 0.08] : [0.08, 0.05, len], 'cyan', rim);
		s.body(`${name}Collision`, mid, size, rim);
	};
	rail('RimSouth', [YARD.minX, YARD.minZ], [YARD.maxX, YARD.minZ]);
	rail('RimWest', [YARD.minX, YARD.minZ], [YARD.minX, YARD.maxZ]);
	rail('RimEast', [YARD.maxX, YARD.minZ], [YARD.maxX, YARD.maxZ]);
	rail('RimNorthWest', [YARD.minX, YARD.maxZ], [gateX[0], YARD.maxZ]);
	rail('RimNorthEast', [gateX[1], YARD.maxZ], [YARD.maxX, YARD.maxZ]);
	s.instance('YardDock', 'yard_dock', yardDock);
	// Code clue on the road face of the lift head, read on the way to the dock (placement proposed).
	s.instance('ServiceTag', 'service_tag', [2.6, 1.7, 397.95], '.', [0, 180, 0]);
	// Hide the translator in an archive bay near the road; the TRACE YARD dest can still start with it owned.
	const translatorNest = [39, 0, 40];
	const translatorHideout = s.group('TranslatorHideout');
	s.box('Floor', [translatorNest[0], -0.15, translatorNest[2] + 1.4], [8.6, 0.2, 6.2], 'trace_floor', translatorHideout);
	for (const side of [-1, 1]) s.box(`Wall${side}`, [translatorNest[0] + side * 4.3, 1.65, translatorNest[2] + 1.4], [0.35, 3.4, 6.2], 'armor', translatorHideout);
	s.box('BackWall', [translatorNest[0], 1.65, translatorNest[2] + 4.35], [8.6, 3.4, 0.35], 'armor', translatorHideout);
	s.box('Roof', [translatorNest[0], 3.28, translatorNest[2] + 1.4], [8.6, 0.2, 6.2], 'facet', translatorHideout);
	s.box('DoorFrame', [translatorNest[0], 1.7, translatorNest[2] - 1.52], [2.9, 3.2, 0.18], 'armor', translatorHideout);
	s.box('DoorLineL', [translatorNest[0] - 1.28, 1.65, translatorNest[2] - 1.64], [0.08, 3, 0.06], 'amber', translatorHideout);
	s.box('DoorLineR', [translatorNest[0] + 1.28, 1.65, translatorNest[2] - 1.64], [0.08, 3, 0.06], 'amber', translatorHideout);
	s.instance('TranslatorPost', 'translator_post', translatorNest, '.', [0, 180, 0]);
	s.marker('TranslatorPoint', [translatorNest[0], 0, translatorNest[2] - 4]);
	s.instance('YardDockBeacon', 'relay_beacon', [yardDock[0], 0, yardDock[2] + 2]);
	// Far yard: a secondary dock and lift kept for later campaign use, far north-east of Backlight yard.
	const vault = [360, 0, 860];
	const farYard = s.group('FarYard');
	s.box('VaultIsland', [vault[0], -16.3, vault[2] + 21], [70, 32, 56], 'bank_rock');
	s.box('VaultApron', [vault[0], -0.29, vault[2] + 4], [30, 0.5, 22], 'trace_floor');
	for (const [name, dx, dz, w, h, d] of [['HallWest', -24, 12, 16, 10, 18], ['HallEast', 11, 10, 18, 14, 20], ['Tower', -4, 35, 12, 24, 12]]) {
		s.box(`FarYard${name}`, [vault[0] + dx + w / 2, h / 2, vault[2] + dz + d / 2], [w, h, d], 'armor', farYard);
		s.box(`FarYard${name}Line`, [vault[0] + dx + w * 0.73, h * 0.42, vault[2] + dz - 0.03], [0.12, h * 0.72, 0.05], 'cyan', farYard);
	}
	for (let i = 0; i < 5; i++) s.box(`VaultEdgeLamp${i}`, [vault[0] - 28 + i * 14, 0.06, vault[2] - 6.9], [2.4, 0.08, 0.12], 'amber');
	s.instance('VaultCradle', 'cycle_cradle', vault);
	s.marker('FarYardDock', vault, '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.instance('DeepLiftLobby', 'deep_lift_lobby', [vault[0] + 15, 0, vault[2] + 7], '.', [0, 180, 0]);
	s.instance('VaultBeacon', 'relay_beacon', [vault[0] - 8, 0, vault[2] + 10]);
	// Relays: lanes must be world-axis aligned because the cycle turns in 90-degree steps.
	const relays = [
		['Relay0', [40, 0, 520], 0], ['Relay1', [180, 0, 640], 90], ['Relay2', [300, 0, 760], 0],
		['RelayWest', [-420, 0, 200], 0], ['RelaySouth', [0, 0, -360], 90], ['RelayEast', [520, 0, 120], 0],
	];
	for (const [name, p, rot] of relays) {
		s.instance(name, 'relay_pylon', p, '.', [0, rot, 0]);
		s.instance(`${name}Beacon`, 'relay_beacon', p);
		s.cylinder(`${name}Suspension`, [p[0], -4, p[2]], 0.18, 8, 'facet');
		s.cylinder(`${name}Anchor`, [p[0], -8, p[2]], 0.85, 0.4, 'armor');
	}
	for (const [name, p] of [['DockSlotWest', [-640, 0, 210]], ['DockSlotSouth', [0, 0, -480]]]) {
		s.marker(name, p);
		s.torus(`${name}Ring`, [p[0], -0.4, p[2]], 6, 6.3, 'facet');
	}
	for (const side of [-1, 1]) {
		s.box(`BoundaryX${side}`, [side > 0 ? F.maxX : F.minX, 0, fcz], [0.3, 0.05, fd], 'amber');
		s.box(`BoundaryZ${side}`, [fcx, 0, side > 0 ? F.maxZ : F.minZ], [fw, 0.05, 0.3], 'amber');
		s.body(`BoundaryXCollision${side}`, [(side > 0 ? F.maxX : F.minX) + side * 0.5, 2, fcz], [1, 4, fd + 2]);
		s.body(`BoundaryZCollision${side}`, [fcx, 2, (side > 0 ? F.maxZ : F.minZ) + side * 0.5], [fw + 2, 4, 1]);
	}
	const depth = s.group('AbyssDepth');
	for (let i = 0; i < 36; i++) {
		const a = i * 2.39996, r = 260 + (i * 97) % 520;
		const x = Math.round(Math.cos(a) * r), z = Math.round(210 + Math.sin(a) * r * 1.05);
		const y = -85 - (i % 4) * 13;
		s.box(`Ruin${i}`, [x, y, z], [14 + i % 5 * 2, 8, 26], 'depth', depth, [7, (i * 29) % 180, -5]);
		s.cylinder(`BrokenTower${i}`, [x + 5, y + 15, z - 3], 2.6, 28, 'depth', depth, [0, 0, (i % 3 - 1) * 12], 1.2);
		s.box(`Window${i}`, [x + 5, y + 26, z - 4.5], [0.9, 0.3, 0.12], 'depth_light', depth);
	}
	const hazeMat = s.resource('Material', `${res}/materials/abyss_haze.tres`);
	const hazeMesh = s.subresource('PlaneMesh', `size = Vector2(${fw + 200}, ${fd + 200})`);
	for (let i = 0; i < 3; i++) {
		s.node(`Haze${i}`, 'MeshInstance3D', depth, `position = ${vec([fcx, -30 - i * 24, fcz])}\nmesh = SubResource("${hazeMesh}")\nmaterial_override = ExtResource("${hazeMat}")\ncast_shadow = 0`);
		s.pieces++;
	}
	const floorMat = s.resource('Material', `${res}/materials/abyss_floor.tres`);
	const floorMesh = s.subresource('PlaneMesh', 'size = Vector2(9000, 9000)');
	s.node('AbyssFloor', 'MeshInstance3D', depth, `position = ${vec([fcx, -460, fcz])}\nmesh = SubResource("${floorMesh}")\nmaterial_override = ExtResource("${floorMat}")\ncast_shadow = 0`);
	s.pieces++;
	s.marker('PlayerSpawn', yardDock, '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.marker('BoardPoint', [yardDock[0] - 3.2, 0, yardDock[2] - 2]);
	s.marker('SecuritySpawn', [vault[0] + 40, 0, vault[2] - 30], '.', 'rotation_degrees = Vector3(0, 90, 0)');
	s.marker('VaultLift', [vault[0] + 15, 0, vault[2] + 2.8]);
	s.save([fw, 160, fd], 'Backlight yard void field (yard coordinates). Invisible layer-4 support across the whole field; the yard is ringed by a collidable rim with one gate at the end-of-road dock. Vault island ~600 m north-east behind three ordered relays; three free recharge relays ring the yard; two empty dock slots. Beacons are additive, unlit and non-colliding.');
	emit('yard_field.json', JSON.stringify({
		version: 2, units: 'metres', frame: 'backlight_yard', forward: '+Z north', up: '+Y',
		scene: `${res}/scenes/yard_void_field.tscn`,
		field_bounds: { min: [F.minX, F.minZ], max: [F.maxX, F.maxZ], axes: ['x', 'z'] },
		yard_rect: { min: [YARD.minX, YARD.minZ], max: [YARD.maxX, YARD.maxZ] },
		rim_gate_x: gateX, rim_collision_prefix: 'YardRim/Rim', support_collision_layer: 4, ride_y: 0,
		docks: {
			yard_dock: { node: 'YardDock', position: yardDock, exit_heading: '+Z' },
			vault: { node: 'VaultCradle', position: vault, approach_heading: '+Z' },
			far_yard: { node: 'VaultCradle', position: vault, approach_heading: '+Z', note: 'Alias for the secondary yard dock kept for later campaign use.' },
		},
		relay_order: ['Relay0/LinkSocket', 'Relay1/LinkSocket', 'Relay2/LinkSocket'],
		free_relays: ['RelayWest/LinkSocket', 'RelaySouth/LinkSocket', 'RelayEast/LinkSocket'],
		dock_slots: ['DockSlotWest', 'DockSlotSouth'],
		beacon_materials: { available: 'beacon_cyan', spent: 'beacon_dim', dock: 'beacon_white', vault_unlocked: 'beacon_amber' },
		proposed_charge: { capacity: 100, drain_per_second: '0.6 + speed^2/1800', trace_on_extra: 0.25, relay_gain: 40, relay_cooldown_s: 45, dock_refill_s: 2, low: 30, critical: 15, critical_speed_cap: 40, failure_window_s: 2.5 },
		proposed_navigation: { beacon_visible_m: 600, self_discover_m: 250, list_scan_radius_m: 900, list_scan_cost: 4, radar_radius_m: 400 },
		translation: {
			item: 'translator', start_owned_in_dest: true, gloss_range_m: 6,
			cradle_code_dev: CRADLE_CODE, cradle_lock: 'YardDock/ReleaseLock', code_clue: 'ServiceTag', translator_post: 'TranslatorPost',
			sign_contract: 'Node3D with metadata text_kind ("interface" | "high"), script, gloss; children Script (strokes) and Gloss (hidden Label3D). Translator reveals interface Gloss only; high script waits for the FEB.',
			signs: ['YardDock/GateSign', 'YardDock/RoadSign', 'YardDock/Directive', 'ServiceTag/Line0', 'ServiceTag/Line1', 'TranslatorPost/PostLabel', 'DeepLiftLobby/Sign', 'DeepLiftLobby/Cabin/IndicatorOut', 'DeepLiftLobby/Cabin/IndicatorIn', 'DeepLiftLobby/Cabin/ControlPanel/ScreenText'],
			word_hash: { algorithm: 'FNV-1a 32-bit over upper-case ASCII', cells: 'max(1, ceil(len/2))', cell_pattern: '(hash >> ((i*5) % 27)) & 63, 0 -> 42', paths: GLYPH_PATHS, shared_top_bar_y: -3 },
			numeral_patterns: NUMERAL_PATTERNS,
			number_words: NUMBER_WORDS,
			fixtures: Object.fromEntries(['TRACE', 'DOCK', 'CRADLE', 'RELEASE', 'SEVEN'].map(w => [w, { hash: narceanHash(w), cells: narceanWordCells(w) }])),
		},
		warning: 'Proposed defaults for the isolated TRACE YARD dest. Play and campaign version 1 are unchanged.',
	}, null, 2) + '\n');
}
{
	const s = new Scene('yard_field_preview');
	s.instance('Field', 'yard_void_field');
	s.instance('Cycle', 'trace_cycle', yardDock, '.', [0, 180, 0]);
	lighting(s);
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(330, 420, -260)\nrotation_degrees = Vector3(-38, 200, 0)\nfov = 65.0\nfar = 4000.0\ncurrent = true');
	s.save([1520, 160, 1540], 'Static overview of the yard void field.');
}
{
	const s = new Scene('backlight_cycle_combined');
	s.instance('Field', 'yard_void_field');
	s.instance('Cycle', 'trace_cycle', yardDock, '.', [0, 180, 0]);
	lighting(s);
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(15, 3.2, 372)\nrotation_degrees = Vector3(-9, 0, 0)\nfov = 63.0\nfar = 2800.0\ncurrent = true');
	s.save([1520, 160, 1540], 'Combined Backlight yard + trace cycle scene, with the far secondary yard dock retained for later campaign use.');
}
{
	const s = new Scene('crossing_preview');
	s.instance('Crossing', 'void_crossing');
	s.instance('Cycle', 'trace_cycle', [-10, 0, 85], '.', [0, 30, 0]);
	lighting(s);
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(58, 72, 145)\nrotation_degrees = Vector3(-27, 18, 0)\nfov = 65.0\nfar = 800.0\ncurrent = true');
	s.save([210, 150, 344], 'Static cliff-to-cliff void overview with distant ruins and haze.');
}
{
	// Glosses visible so the art can be reviewed; in play only the translator reveals interface glosses.
	const s = new Scene('translator_preview');
	s.instance('Lock', 'release_lock', [0, 0, 0]);
	s.instance('Tag', 'service_tag', [1.4, 1.1, -0.6]);
	s.instance('Post', 'translator_post', [-1.6, 0, -0.6]);
	s.instance('Translator', 'interface_translator', [0.5, 1.25, 1.9], '.', [60, 0, 0]);
	lighting(s);
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(0, 1.6, 3.2)\nrotation_degrees = Vector3(-12, 0, 0)\nfov = 60.0\ncurrent = true');
	s.save([4, 3, 4], 'Translator, release lock, service tag and pickup post close-up.');
}

emit('manifest.json', JSON.stringify({
	version: 1, status: 'original_model_kit_for_isolated_integration',
	format: 'Native Godot scenes and primitive mesh resources, no runtime generator or external model dependencies',
	ownership: 'Assistant-authored art. Cursor implements VG behavior, never regenerates or replaces these models.',
	collision: { scenery_layer: 1, invisible_support_layer: 4, cycle_layer: 2, cycle_mask: 1 },
	assets,
}, null, 2) + '\n');

let failures = 0;
for (const [name, data] of outputs) {
	const file = path.join(root, name);
	if (process.argv.includes('--check')) {
		if (!fs.existsSync(file) || !fs.readFileSync(file).equals(data)) {
			console.error(`Missing or changed generated art: ${name}`);
			failures++;
		}
	} else {
		fs.mkdirSync(path.dirname(file), { recursive: true });
		fs.writeFileSync(file, data);
	}
}
console.log(`TRACE_VAULT_ASSETS=${outputs.size} SCENES=${assets.length} MESH_INSTANCES=${assets.reduce((sum, a) => sum + a.mesh_instances, 0)} CHECK_FAILURES=${failures}`);
if (failures) process.exitCode = 1;
