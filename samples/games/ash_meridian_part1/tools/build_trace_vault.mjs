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
};
for (const [id, [color, metal, lit]] of Object.entries(palette)) {
	emit(`materials/${id}.tres`, `[gd_resource type="StandardMaterial3D" format=3]

[resource]
albedo_color = Color(${color}, 1)
metallic = ${metal}
roughness = 0.64
${lit ? `shading_mode = 0\nemission_enabled = true\nemission = Color(${color}, 1)\nemission_energy_multiplier = 1.1` : ''}
`);
}

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
	torus(name, position, inner, outer, mat, parent = '.', rotation = [0, 0, 0]) {
		this.mesh(name, 'TorusMesh', `inner_radius = ${inner}\nouter_radius = ${outer}\nrings = 24\nring_segments = 8`, position, mat, parent, rotation);
	}
	body(name, position, size, parent = '.') {
		const body = this.node(name, 'StaticBody3D', parent, `position = ${vec(position)}\ncollision_layer = 1\ncollision_mask = 0`);
		const shape = this.subresource('BoxShape3D', `size = ${vec(size)}`);
		this.node('Collision', 'CollisionShape3D', body, `shape = SubResource("${shape}")`);
	}
	instance(name, file, position = [0, 0, 0], parent = '.', rotation = [0, 0, 0]) {
		const id = this.resource('PackedScene', `${res}/scenes/${file}.tscn`);
		return this.node(name, '', parent, `position = ${vec(position)}\nrotation_degrees = ${vec(rotation)}`, id);
	}
	label(name, text, position, size = 36, parent = '.') {
		this.node(name, 'Label3D', parent, `position = ${vec(position)}\ntext = "${text}"\nfont_size = ${size}\npixel_size = 0.006\nmodulate = Color(0.45, 0.85, 0.92, 1)\nno_depth_test = false\nbillboard = 1`);
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
	const s = new Scene('relay_pylon');
	s.cylinder('Foot', [0, 0.18, 0], 1.35, 0.36, 'armor', '.', [0, 0, 0], 1.1);
	s.body('BaseCollision', [0, 0.25, 0], [2.2, 0.5, 2.2]);
	s.box('Column', [0, 2.1, 0], [0.9, 3.5, 0.9], 'facet');
	s.body('ColumnCollision', [0, 2, 0], [0.9, 3.5, 0.9]);
	for (const x of [-0.5, 0.5]) s.box(`Seam${x}`, [x, 2.1, 0.46], [0.05, 2.9, 0.035], 'cyan');
	s.cylinder('Crown', [0, 4.0, 0], 0.9, 0.35, 'armor');
	s.torus('StatusLamp', [0, 4.2, 0], 0.62, 0.73, 'amber');
	s.marker('LinkSocket', [0, 0.2, 1.8]);
	s.marker('StatusAnchor', [0, 4.4, 0]);
	s.save([2.7, 4.3, 2.7], 'Sample LinkSocket; do not navigate the cycle through solid pylon collision.');
}
{
	const s = new Scene('feb');
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
	s.save([1.65, 2.65, 0.72], 'Awakening rig only. Pivot head and arms; no locomotion skeleton or gameplay collision.');
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
	s.group('ClampPivots');
	for (const side of [-1, 1]) for (const [part, y] of [['Upper', 2.5], ['Lower', 1.0]]) {
		const p = s.group(`${part}${side < 0 ? 'Left' : 'Right'}`, 'ClampPivots', [side * 1.05, y, -0.32]);
		s.box('Arm', [-side * 0.25, 0, 0], [0.55, 0.13, 0.22], 'facet', p);
		s.box('Contact', [-side * 0.5, 0, -0.06], [0.13, 0.23, 0.14], 'amber', p);
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
	s.save([4.0, 3.9, 3], 'Standby cradle. Insert FEB at FigureMount. Clamp rotations are independent. No transparent shell or active particle system.');
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
	const s = new Scene('deep_lift_lobby');
	s.box('Landing', [0, -0.25, 0], [10, 0.5, 10], 'facet');
	s.body('LandingCollision', [0, -0.25, 0], [10, 0.5, 10]);
	for (const side of [-1, 1]) {
		s.box(`Wall${side}`, [side * 5, 2, 0], [0.4, 4, 10], 'armor');
		s.body(`WallCollision${side}`, [side * 5, 2, 0], [0.4, 4, 10]);
		s.box(`Guide${side}`, [side * 1.7, 0.015, 0], [0.05, 0.025, 9], 'amber');
		s.box(`Front${side}`, [side * 3.4, 2, 5], [3.2, 4, 0.4], 'armor');
		s.body(`FrontCollision${side}`, [side * 3.4, 2, 5], [3.2, 4, 0.4]);
	}
	s.box('Back', [0, 2, -5], [10, 4, 0.4], 'armor');
	s.body('BackCollision', [0, 2, -5], [10, 4, 0.4]);
	const cabin = s.group('Cabin');
	s.box('LiftDeck', [0, 0.05, -2.2], [3.5, 0.1, 4.5], 'dark', cabin);
	s.body('CabinCollision', [0, 0.05, -2.2], [3.5, 0.1, 4.5], cabin);
	for (const side of [-1, 1]) {
		s.box(`Rail${side}`, [side * 1.8, 1.7, -2.2], [0.12, 3.4, 4.5], 'facet', cabin);
		s.box(`Signal${side}`, [side * 1.72, 1.9, 0.05], [0.04, 2.5, 0.04], 'cyan', cabin);
	}
	s.box('ConsoleBody', [2.6, 0.7, 1], [0.65, 1.4, 0.6], 'armor');
	s.box('ConsoleFace', [2.6, 1.42, 1], [0.55, 0.035, 0.45], 'amber');
	s.marker('Entrance', [0, 0, 4.2]);
	s.marker('LiftPose', [0, 0.1, -2.2]);
	s.marker('Console', [2.6, 1.45, 1]);
	s.label('Sign', 'DEEP SERVICE / ISOLATION 04', [0, 3.5, -4.6], 46);
	s.save([10.4, 4, 10.4], 'Separate deep-lift landing. Cabin is a static art group; VG owns transfer/fade, not moving StaticBody3D physics.');
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
	s.instance('CoreBank', 'core_bank', [7.1, 0, 3.3], '.', [0, 180, 0]);
	s.label('TraceLabel', 'TRACE / MAINTENANCE', [-4.5, 0.5, 6], 40);
	s.label('SecurityLabel', 'REMOTE / ENFORCEMENT', [-0.5, 0.5, 5.7], 34);
	lighting(s);
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(11, 8, 15)\nrotation_degrees = Vector3(-25, 28, 0)\nfov = 60.0\ncurrent = true');
	s.save([24, 5, 24], 'Art review gallery only; does not modify Play.');
}
{
	const s = new Scene('void_crossing');
	s.box('SupportField', [0, -0.1, 0], [160, 0.2, 240], 'dark');
	s.body('SupportCollision', [0, -0.1, 0], [160, 0.2, 240]);
	for (let x = -80; x <= 80; x += 20) s.box(`GridX${x}`, [x, 0.012, 0], [0.035, 0.015, 240], 'facet');
	for (let z = -120; z <= 120; z += 20) s.box(`GridZ${z}`, [0, 0.012, z], [160, 0.015, 0.035], 'facet');
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
	for (const [i, p] of [[-48, 0, 42], [44, 0, -18], [-18, 0, -64]].entries()) s.instance(`Relay${i}`, 'relay_pylon', p);
	s.marker('PlayerSpawn', [0, 0, 105]);
	s.marker('SecuritySpawn', [63, 0, -90], '.', 'rotation_degrees = Vector3(0, 180, 0)');
	s.marker('NearExit', [4, 0, 108]);
	s.marker('FarLift', [-15, 0, -107.8]);
	s.save([174, 21, 242], 'Isolated static support field with boundaries and both docks. No controller, trails or enemy logic. Not wired into campaign.');
	emit('route.json', JSON.stringify({
		version: 1, units: 'metres', forward: '-Z', up: '+Y',
		scene: `${res}/scenes/void_crossing.tscn`,
		support_bounds: { min: [-80, -120], max: [80, 120], axes: ['x', 'z'] },
		ride_y: 0, clearance_radius: 0.75, cycle_length: 4.2,
		near_dock: [0, 0, 105], far_dock: [0, 0, -105],
		relay_order: ['Relay0/LinkSocket', 'Relay1/LinkSocket', 'Relay2/LinkSocket'],
		relay_capture_radius: 3.5, maximum_proposed_speed: 64,
		warning: 'Art layout only. Validate reachability and collision sweeps in VG before choosing gameplay balance.',
	}, null, 2) + '\n');
}
{
	const s = new Scene('crossing_preview');
	s.instance('Crossing', 'void_crossing');
	s.instance('Cycle', 'trace_cycle', [-10, 0, 85], '.', [0, 30, 0]);
	lighting(s);
	s.node('Camera', 'Camera3D', '.', 'position = Vector3(58, 72, 145)\nrotation_degrees = Vector3(-27, 18, 0)\nfov = 65.0\nfar = 800.0\ncurrent = true');
	s.save([174, 21, 242], 'Static whole-field overview.');
}

emit('manifest.json', JSON.stringify({
	version: 1, status: 'original_model_kit_for_isolated_integration',
	format: 'Native Godot scenes and primitive mesh resources, no runtime generator or external model dependencies',
	ownership: 'Assistant-authored art. Cursor implements VG behavior, never regenerates or replaces these models.',
	collision: { scenery_layer: 1, cycle_layer: 2, cycle_mask: 1 },
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
