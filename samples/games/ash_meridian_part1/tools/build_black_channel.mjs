import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

// Offline art source, not a game controller. No third-party assets or dependencies.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../assets/black_channel');
const checkOnly = process.argv.includes('--check');
const generated = new Map();
const manifest = [];
const surfaceOrder = new Map();
const models = new Map();
const res = 'res://assets/black_channel';
const round = n => Number(n.toFixed(5));
const vec = a => `Vector3(${a.map(round).join(', ')})`;
const packed = a => `PackedVector3Array(${a.flat().map(round).join(', ')})`;
const add = (a, b) => a.map((v, i) => v + b[i]);
const sub = (a, b) => a.map((v, i) => v - b[i]);
const mul = (a, s) => a.map(v => v * s);
const dot = (a, b) => a.reduce((s, v, i) => s + v * b[i], 0);
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const unit = a => mul(a, 1 / Math.hypot(...a));
const output = (name, data) => generated.set(name, Buffer.isBuffer(data) ? data : Buffer.from(data));

const palette = [
	['basalt', [0.036, 0.052, 0.078], 0.25],
	['armor', [0.085, 0.12, 0.16], 0.65],
	['facet', [0.14, 0.19, 0.23], 0.45],
	['cyan', [0.05, 0.85, 1.0], 0.3, [0.05, 0.85, 1.0]],
	['amber', [1.0, 0.45, 0.065], 0.3, [1.0, 0.45, 0.065]],
	['red', [1.0, 0.045, 0.075], 0.3, [1.0, 0.045, 0.075]],
	['glass', [0.025, 0.16, 0.2], 0.85],
	['violet', [0.6, 0.12, 0.95], 0.3, [0.6, 0.12, 0.95]],
];

class Model {
	constructor(name) { this.name = name; this.groups = new Map(); this.vertices = []; }
	poly(points, faces, material) {
		const center = mul(points.reduce(add, [0, 0, 0]), 1 / points.length);
		const g = this.groups.get(material) ?? { positions: [], normals: [] };
		this.groups.set(material, g);
		this.vertices.push(...points);
		for (const face of faces) {
			for (let i = 1; i < face.length - 1; i++) {
				let tri = [points[face[0]], points[face[i]], points[face[i+1]]];
				let normal = unit(cross(sub(tri[1], tri[0]), sub(tri[2], tri[0])));
				const mid = mul(tri.reduce(add, [0, 0, 0]), 1/3);
				if (dot(normal, sub(mid, center)) < 0) {
					tri = [tri[0], tri[2], tri[1]];
					normal = mul(normal, -1);
				}
				g.positions.push(...tri.flat());
				g.normals.push(...normal, ...normal, ...normal);
			}
		}
		return points;
	}
	box(center, size, material, yaw = 0) {
		const pts = [];
		for (const z of [-1, 1]) for (const y of [-1, 1]) for (const x of [-1, 1]) {
			const p = [x*size[0]/2, y*size[1]/2, z*size[2]/2];
			pts.push(add(center, [Math.cos(yaw)*p[0]+Math.sin(yaw)*p[2], p[1], -Math.sin(yaw)*p[0]+Math.cos(yaw)*p[2]]));
		}
		return this.poly(pts, [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]], material);
	}
	prism(section, length, material, offset = [0,0,0]) {
		const n = section.length;
		const pts = [-length/2, length/2].flatMap(z => section.map(([x,y]) => add([x,y,z], offset)));
		const faces = [Array.from({length:n}, (_,i)=>i), Array.from({length:n}, (_,i)=>i+n)];
		for (let i=0; i<n; i++) faces.push([i,(i+1)%n,(i+1)%n+n,i+n]);
		return this.poly(pts, faces, material);
	}
	hull(outline, bottom, top, material) {
		const n = outline.length;
		const pts = [bottom, top].flatMap(y => outline.map(([x,z]) => [x,y,z]));
		const faces = [Array.from({length:n}, (_,i)=>i), Array.from({length:n}, (_,i)=>i+n)];
		for (let i=0;i<n;i++) faces.push([i,(i+1)%n,(i+1)%n+n,i+n]);
		return this.poly(pts, faces, material);
	}
	beam(a, b, width, material) {
		const direction = unit(sub(b,a));
		const side = unit(cross(direction, Math.abs(direction[1]) > 0.95 ? [1,0,0] : [0,1,0]));
		const up = unit(cross(side, direction));
		const pts = [a,b].flatMap(p => [[-1,-1],[1,-1],[1,1],[-1,1]].map(([x,y]) => add(p, add(mul(side,x*width/2),mul(up,y*width/2)))));
		this.poly(pts, [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]], material);
	}
	save() {
		models.set(this.name, this);
		const doc = {
			asset: { version:'2.0', generator:'Ash Meridian original Black Channel art source' },
			scene:0, scenes:[{nodes:[0]}], nodes:[{name:this.name,children:[1]},{name:'Mesh',mesh:0}],
			meshes:[{name:this.name,primitives:[]}],
			materials:palette.map(([name,c,metal,emission]) => ({
				name, pbrMetallicRoughness:{baseColorFactor:[...c,1],metallicFactor:metal,roughnessFactor:0.7},
				...(emission ? {emissiveFactor:emission} : {}),
			})),
			buffers:[{byteLength:0}], bufferViews:[], accessors:[],
		};
		const bins = [];
		let offset = 0;
		const attribute = (array, bounds) => {
			const bin = Buffer.alloc(array.length*4);
			array.forEach((v,i) => bin.writeFloatLE(v,i*4));
			const index = doc.accessors.length;
			doc.bufferViews.push({buffer:0,byteOffset:offset,byteLength:bin.length,target:34962});
			const accessor = {bufferView:doc.bufferViews.length-1,componentType:5126,count:array.length/3,type:'VEC3'};
			if (bounds) {
				accessor.min = [0,1,2].map(i => Math.min(...array.filter((_,k)=>k%3===i)));
				accessor.max = [0,1,2].map(i => Math.max(...array.filter((_,k)=>k%3===i)));
			}
			doc.accessors.push(accessor);
			bins.push(bin); offset += bin.length;
			return index;
		};
		let triangles = 0;
		for (const [material,g] of this.groups) {
			doc.meshes[0].primitives.push({attributes:{POSITION:attribute(g.positions,true),NORMAL:attribute(g.normals,false)},material,mode:4});
			triangles += g.positions.length/9;
		}
		doc.buffers[0].byteLength = offset;
		const json = Buffer.from(JSON.stringify(doc));
		const jsonPad = Buffer.alloc((4-json.length%4)%4,0x20);
		const bin = Buffer.concat(bins);
		const header = Buffer.alloc(12);
		header.writeUInt32LE(0x46546c67,0); header.writeUInt32LE(2,4);
		header.writeUInt32LE(12+8+json.length+jsonPad.length+8+bin.length,8);
		const chunk = (size,type) => { const b=Buffer.alloc(8); b.writeUInt32LE(size,0); b.writeUInt32LE(type,4); return b; };
		const glb = Buffer.concat([header,chunk(json.length+jsonPad.length,0x4e4f534a),json,jsonPad,chunk(bin.length,0x004e4942),bin]);
		output(`models/${this.name}.glb`,glb);
		surfaceOrder.set(this.name,[...this.groups.keys()]);
		manifest.push({
			id:this.name, model:`${res}/models/${this.name}.glb`, triangles,
			min:[0,1,2].map(i=>round(Math.min(...this.vertices.map(p=>p[i])))),
			max:[0,1,2].map(i=>round(Math.max(...this.vertices.map(p=>p[i])))),
			sha256:crypto.createHash('sha256').update(glb).digest('hex'),
		});
	}
}

class Scene {
	constructor() { this.ext=[]; this.sub=[]; this.nodes=[]; }
	resource(type, resourcePath, id) { this.ext.push(`[ext_resource type="${type}" path="${resourcePath}" id="${id}"]`); }
	shape(id, type, props) { this.sub.push(`[sub_resource type="${type}" id="${id}"]\n${props}`); }
	node(name, type, parent, props='', instance='') {
		this.nodes.push(`[node name="${name}"${type?` type="${type}"`:''}${parent!==null?` parent="${parent}"`:''}${instance?` instance=ExtResource("${instance}")`:''}]\n${props}`);
	}
	boxBody(name, parent, center, size) {
		const id = `shape_${this.sub.length}`;
		this.shape(id,'BoxShape3D',`size = ${vec(size)}`);
		this.node(name,'StaticBody3D',parent,`position = ${vec(center)}\ncollision_layer = 1\ncollision_mask = 0`);
		this.node('Collision','CollisionShape3D',parent==='.'?name:`${parent}/${name}`,`shape = SubResource("${id}")`);
	}
	save(name) {
		output(`scenes/${name}.tscn`,`[gd_scene load_steps=${1+this.ext.length+this.sub.length} format=3]\n\n${[...this.ext,...this.sub,...this.nodes].join('\n\n')}\n`);
	}
	saveCollision(name) {
		const scene=new Scene();
		scene.ext=this.ext;
		scene.sub=this.sub;
		scene.nodes=this.nodes.filter(node=>!node.includes('name="Visual"')&&!node.includes('parent="Visual/'));
		scene.save(`${name}_collision`);
	}
}
const visual = (s, model, parent='.', name='Visual') => {
	const id = `model_${model}`;
	if (!s.ext.some(line=>line.includes(`id="${id}"`))) s.resource('PackedScene',`${res}/models/${model}.glb`,id);
	s.node(name,'',parent,'',id);
	const props = surfaceOrder.get(model).map((material,index)=>{
		const materialId=`material_${material}`;
		if(!s.ext.some(line=>line.includes(`id="${materialId}"`))) s.resource('Material',`${res}/materials/${palette[material][0]}.tres`,materialId);
		return `surface_material_override/${index} = ExtResource("${materialId}")`;
	}).join('\n');
	s.nodes.push(`[node name="Mesh" parent="${parent==='.'?name:`${parent}/${name}`}/${model}" index="0"]\nvisibility_range_end = 1900.0\nvisibility_range_end_margin = 150.0\n${props}`);
};
const marker = (s,name,parent,p) => s.node(name,'Marker3D',parent,`position = ${vec(p)}`);

for(const [name,color,,emission] of palette) {
	output(`materials/${name}.tres`,`[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n[ext_resource type="Shader" path="${res}/materials/backlight_surface.gdshader" id="shader"]\n\n[resource]\nshader = ExtResource("shader")\nshader_parameter/base_color = Color(${color.join(', ')}, 1)\nshader_parameter/illuminated = ${Boolean(emission)}\n`);
}

// Straight modules use a common open flight envelope: x +/-44, floor y=-14.
const canyon = new Model('canyon_straight');
const wallSections = [];
for (const side of [-1,1]) {
	const section = [[48,-14],[68,-14],[68,68],[58,68],[50,40],[45,11]].map(([x,y])=>[x*side,y]);
	wallSections.push(canyon.prism(section,96,0));
	for (const z of [-36,-12,12,36]) {
		canyon.box([side*44.5,6,z],[0.28,0.3,14],3);
		canyon.box([side*47.5,33,z],[0.3,1.1,5],4);
		canyon.box([side*45.5,18,z],[2,6,3],1);
		canyon.beam([side*44,-10,z],[side*44,10,z],1.5,1);
		canyon.beam([side*44,10,z],[side*49,40,z],1.5,1);
		canyon.beam([side*49,40,z],[side*57,66,z],1.5,1);
		canyon.beam([side*43.1,10,z+0.1],[side*48.1,40,z+0.1],0.16,3);
		canyon.box([side*43.7,1,z],[1.3,2,3],4);
	}
	canyon.beam([side*46.5,-4,-48],[side*46.5,-4,48],0.3,3);
	canyon.box([side*43,-9,0],[1.5,1.5,96],1);
	canyon.box([side*42.2,-8.8,0],[0.18,0.3,96],3);
}
canyon.box([0,-16,0],[136,4,96],0);
canyon.box([0,-13.85,0],[1.2,0.2,96],1);
for (const x of [-16,16]) canyon.box([x,-13.75,0],[0.16,0.2,96],3);
for (const z of [-32,0,32]) canyon.box([0,-13.5,z],[4,0.3,1.1],4);
canyon.save();
{
	const s=new Scene();
	s.node('CanyonStraight','Node3D',null);
	visual(s,'canyon_straight');
	s.boxBody('Floor','.',[0,-16,0],[136,4,96]);
	wallSections.forEach((points,i)=>{
		s.shape(`cliff_${i}`,'ConvexPolygonShape3D',`points = ${packed(points)}`);
		s.node(`Cliff${i}`,'StaticBody3D','.', 'collision_layer = 1\ncollision_mask = 0');
		s.node('Collision','CollisionShape3D',`Cliff${i}`,`shape = SubResource("cliff_${i}")`);
	});
	marker(s,'Entry','.',[0,10,48]); marker(s,'Exit','.',[0,10,-48]);
	s.save('canyon_straight');
	s.saveCollision('canyon_straight');
}

const causeway = new Model('open_causeway');
causeway.box([0,-16,0],[104,4,96],0);
for (const x of [-40,-16,16,40]) causeway.beam([x,-13.7,-48],[x,-13.7,48],0.18,3);
for (const z of [-36,-12,12,36]) {
	causeway.beam([-40,-13.6,z],[40,-13.6,z],0.12,7);
	for (const side of [-1,1]) {
		causeway.beam([side*40,-13.5,z],[side*16,-13.5,z-12],0.14,3);
		causeway.box([side*48,-10,z],[6,8,5],1);
		causeway.box([side*44.8,-6,z],[0.25,0.4,5],4);
	}
}
for (const z of [-32,0,32]) causeway.box([0,-13.5,z],[4,0.3,1.1],4);
causeway.save();
{
	const s=new Scene(); s.node('OpenCauseway','Node3D',null); visual(s,'open_causeway');
	s.boxBody('Floor','.',[0,-16,0],[104,4,96]);
	for (const side of [-1,1]) for (const [i,z] of [-36,-12,12,36].entries()) {
		s.boxBody(`Buttress${side<0?'L':'R'}${i}`,'.',[side*48,-10,z],[6,8,5]);
	}
	s.save('open_causeway');
	s.saveCollision('open_causeway');
}

const lattice = new Model('lattice_arch');
const archPoints = [[-60,-20,0],[-60,32,0],[-38,64,0],[38,64,0],[60,32,0],[60,-20,0]];
for (let i=0;i<archPoints.length-1;i++) {
	lattice.beam(archPoints[i],archPoints[i+1],2.0,1);
	lattice.beam(add(archPoints[i],[0,0,1.1]),add(archPoints[i+1],[0,0,1.1]),0.22,7);
	lattice.beam(add(archPoints[i],[0,0,-24]),add(archPoints[i+1],[0,0,-24]),2.0,1);
	lattice.beam(add(archPoints[i],[0,0,-25.1]),add(archPoints[i+1],[0,0,-25.1]),0.22,3);
}
for (const point of archPoints) {
	lattice.beam(point,add(point,[0,0,-24]),1.2,1);
	for(const depth of [0,-24]) lattice.box(add(point,[0,0,depth]),[3,3,3],4);
}
for (const side of [-1,1]) {
	lattice.beam([side*60,32,0],[side*38,64,-24],0.4,3);
	lattice.beam([side*60,32,-24],[side*38,64,0],0.4,3);
}
lattice.beam([-38,64,0],[38,64,-24],0.28,7);
lattice.beam([38,64,0],[-38,64,-24],0.28,7);
lattice.save();
{
	const s=new Scene(); s.node('LatticeArch','Node3D',null); visual(s,'lattice_arch');
	for (const side of [-1,1]) s.boxBody(`Support${side<0?'L':'R'}`,'.',[side*60,6,0],[3,52,3]);
	s.boxBody('Crown','.',[0,64,0],[78,3,3]);
	s.save('lattice_arch');
	s.saveCollision('lattice_arch');
}

const tower = new Model('industrial_spire');
tower.prism([[-23,-65],[23,-65],[19,40],[8,120],[-5,148],[-17,72]],42,0);
for (const side of [-1,1]) {
	tower.beam([side*23,-65,22],[side*19,40,22],0.3,3);
	tower.beam([side*19,40,22],[side*8,120,22],0.3,7);
	tower.beam([side*8,120,22],[-5,148,22],0.3,3);
}
for (let y=-40;y<100;y+=20) {
	tower.box([0,y,21.3],[24,0.3,0.4],3);
	tower.box([9,y+3,21.5],[5,1.4,0.4],4);
}
tower.beam([-18,-40,22],[14,60,22],0.25,7);
tower.beam([18,-40,22],[-14,60,22],0.25,7);
tower.save();
{
	const s=new Scene(); s.node('IndustrialSpire','Node3D',null); visual(s,'industrial_spire');
	s.boxBody('Tower','.',[0,20,0],[46,170,42]);
	s.save('industrial_spire');
	s.saveCollision('industrial_spire');
}

const ash = new Model('ash_flight');
ash.hull([[0,-5.5],[1.5,-3.5],[2.1,2.8],[1.4,5],[-1.4,5],[-2.1,2.8],[-1.5,-3.5]],-0.8,0.65,1);
ash.hull([[0,-4.1],[1.05,-2.5],[0.9,0.6],[-0.9,0.6],[-1.05,-2.5]],0.66,1.5,6);
for (const side of [-1,1]) {
	ash.hull([[side*1.5,-2],[side*4.8,1],[side*4.8,3.8],[side*1.7,3.3]],-0.55,0.15,0);
	ash.box([side*3.4,0,2.7],[1.3,1.8,4.2],1);
	ash.box([side*3.4,0,4.85],[0.95,1.2,0.15],5);
	ash.beam([side*1.5,0.7,-3.5],[side*2.1,0.7,2.8],0.09,3);
	ash.beam([side*1.7,0.2,-1.9],[side*4.8,0.2,1],0.1,4);
	ash.beam([side*4.8,0.2,1],[side*4.8,0.2,3.8],0.1,3);
	ash.beam([side*1.4,0.7,5],[side*2.1,0.7,2.8],0.1,4);
}
ash.beam([-0.9,1.53,0.6],[0,1.53,-4.1],0.08,3);
ash.beam([0.9,1.53,0.6],[0,1.53,-4.1],0.08,3);
ash.save();
{
	const s=new Scene(); s.node('AshFlight','Node3D',null); visual(s,'ash_flight');
	for (const [name,x] of [['EngineLeft',-3.4],['EngineRight',3.4]]) marker(s,name,'.',[x,0,4.9]);
	s.save('ash_flight');
}

const bridge = new Model('service_bridge');
bridge.box([0,0,0],[110,4,9],1);
for (const x of [-47,47]) bridge.box([x,-16,0],[5,32,9],0);
for (const z of [-4.6,4.6]) {
	bridge.box([0,2.7,z],[110,0.18,0.18],3);
	for (let x=-50;x<50;x+=10) bridge.beam([x,-2,z],[x+10,2,z],0.5,2);
}
bridge.save();
{
	const s=new Scene(); s.node('ServiceBridge','Node3D',null); visual(s,'service_bridge');
	s.boxBody('Span','.',[0,0,0],[110,4,9]);
	for (const [i,x] of [-47,47].entries()) s.boxBody(`Support${i}`,'.',[x,-16,0],[5,32,9]);
	s.save('service_bridge');
	s.saveCollision('service_bridge');
}

const roof=new Model('covered_roof');
roof.box([0,0,0],[104,4,96],0);
for(const z of [-36,-12,12,36]) {
	roof.box([0,-2.6,z],[100,1.2,1.6],1);
	roof.box([0,-3.3,z],[78,0.15,0.2],3);
}
for(const x of [-36,36]) roof.box([x,-2.3,0],[0.3,0.3,96],4);
roof.save();
{
	const s=new Scene(); s.node('CoveredRoof','Node3D',null); visual(s,'covered_roof');
	s.boxBody('Ceiling','.',[0,0,0],[104,4,96]);
	for(const [i,z] of [-36,-12,12,36].entries()) s.boxBody(`Rib${i}`,'.',[0,-2.6,z],[100,1.2,1.6]);
	s.save('covered_roof');
	s.saveCollision('covered_roof');
}

const frame = new Model('gate_frame');
for (const x of [-31,31]) {
	frame.box([x,16,0],[10,64,12],0);
	frame.box([x,16,-6.1],[0.25,58,0.25],4);
	for (const y of [-8,4,16,28,40]) frame.box([x,y,6.1],[6,0.35,0.3],3);
}
frame.box([0,46,0],[72,6,12],1);
frame.box([0,42.8,6.1],[52,0.3,0.3],4);
frame.save();
const leaf=new Model('gate_leaf');
leaf.box([0,0,0],[26,56,3],1);
for (const x of [-12,12]) leaf.box([x,0,1.65],[0.2,54,0.25],4);
for (let y=-24;y<=24;y+=8) {
	leaf.box([0,y,1.65],[21,0.25,0.3],2);
	leaf.box([0,y,1.85],[4,0.3,0.3],4);
}
leaf.save();
{
	const s=new Scene(); s.node('SecurityGate','Node3D',null);
	visual(s,'gate_frame');
	for (const [i,x] of [-31,31].entries()) s.boxBody(`Pier${i}`,'.',[x,16,0],[10,64,12]);
	s.boxBody('Lintel','.',[0,46,0],[72,6,12]);
	s.shape('door','BoxShape3D','size = Vector3(26, 56, 3)');
	for (const [name,x] of [['LeftDoor',-39],['RightDoor',39]]) {
		s.node(name,'AnimatableBody3D','.',`position = Vector3(${x}, 14, 0)\ncollision_layer = 1\ncollision_mask = 0\nmetadata/closed_x = ${x/3}\nmetadata/open_x = ${x}`);
		visual(s,'gate_leaf',name);
		s.node('Collision','CollisionShape3D',name,'shape = SubResource("door")');
	}
	marker(s,'Approach','.',[0,10,80]); marker(s,'Clearance','.',[0,10,-30]);
	s.save('security_gate');
}

const drone = new Model('needle_drone');
const droneHull = drone.hull([[0,-6],[1.8,-2.8],[2,1.5],[1.1,3.2],[-1.1,3.2],[-2,1.5],[-1.8,-2.8]],-0.65,0.65,1);
drone.hull([[0,-4.5],[0.85,-1.3],[0.7,0.6],[-0.7,0.6],[-0.85,-1.3]],0.66,1.15,6);
for (const side of [-1,1]) {
	drone.hull([[side*1.2,-1.8],[side*5,-3],[side*4.4,2.8],[side*2,1.8]],-0.3,0.12,0);
	drone.beam([side*1.3,0.3,-2],[side*4.8,0.3,-2.8],0.12,5);
	drone.box([side*1.2,0,3.25],[0.7,0.65,0.2],7);
	drone.box([side*2.7,-0.2,-2.8],[0.4,0.5,3],1);
	drone.box([side*2.7,-0.2,-4.35],[0.28,0.28,0.15],5);
}
drone.box([0,0,-5.85],[0.35,0.35,0.25],5);
drone.beam([0,1.18,-4.3],[0,1.18,0.5],0.09,3);
for(const side of [-1,1]) {
	drone.beam([side*1.7,0.73,-2.6],[side*1.9,0.73,1.4],0.1,7);
	drone.beam([side*5,0.16,-3],[side*4.4,0.16,2.8],0.09,5);
}
drone.save();
{
	const s=new Scene();
	s.node('NeedleDrone','CharacterBody3D',null,'collision_layer = 4\ncollision_mask = 1\nmetadata/forward_axis = "-Z"');
	visual(s,'needle_drone');
	s.shape('hull','ConvexPolygonShape3D',`points = ${packed(droneHull)}`);
	s.node('HullCollision','CollisionShape3D','.','shape = SubResource("hull")');
	s.shape('wing','BoxShape3D','size = Vector3(2.5, 0.5, 4.5)');
	for (const [i,x] of [-3.2,3.2].entries()) s.node(`WingCollision${i}`,'CollisionShape3D','.',`position = Vector3(${x}, -0.05, 0)\nshape = SubResource("wing")`);
	marker(s,'MuzzleLeft','.',[-2.7,-0.2,-4.5]); marker(s,'MuzzleRight','.',[2.7,-0.2,-4.5]);
	marker(s,'EngineLeft','.',[-1.2,0,3.5]); marker(s,'EngineRight','.',[1.2,0,3.5]);
	marker(s,'AimPoint','.',[0,0,0]); s.save('needle_drone');
}

const base=new Model('sentinel_base');
base.prism([[-4,0],[4,0],[3,2],[-3,2]],7,0);
base.box([0,2.4,0],[5,0.8,5],1);
for(const x of [-3.6,3.6]) base.box([x,0.7,0],[0.15,0.3,5],4);
base.save();
const head=new Model('sentinel_head');
head.hull([[-2.8,2],[-2.8,-1.5],[-1.6,-3],[1.6,-3],[2.8,-1.5],[2.8,2]],-1.2,1.2,1);
for(const x of [-1.8,1.8]) {
	head.box([x,-0.25,-4],[0.65,0.7,5],0);
	head.box([x,-0.25,-6.6],[0.45,0.45,0.2],5);
	head.box([x,0.3,0],[0.15,0.25,3],4);
}
head.box([0,0.3,-2.8],[1.2,0.4,0.25],5); head.save();
{
	const s=new Scene(); s.node('WallSentinel','Node3D',null); visual(s,'sentinel_base');
	s.boxBody('BaseCollision','.',[0,1.4,0],[8,2.8,7]);
	s.node('Yaw','Node3D','.','position = Vector3(0, 3.5, 0)');
	s.node('Pitch','AnimatableBody3D','Yaw','collision_layer = 4\ncollision_mask = 0\nsync_to_physics = false');
	visual(s,'sentinel_head','Yaw/Pitch');
	s.shape('head','BoxShape3D','size = Vector3(5.6, 2.4, 5)');
	s.node('Collision','CollisionShape3D','Yaw/Pitch','position = Vector3(0, 0, -0.5)\nshape = SubResource("head")');
	s.shape('barrel','BoxShape3D','size = Vector3(0.65, 0.7, 5)');
	for(const [i,x] of [-1.8,1.8].entries()) s.node(`BarrelCollision${i}`,'CollisionShape3D','Yaw/Pitch',`position = Vector3(${x}, -0.25, -4)\nshape = SubResource("barrel")`);
	marker(s,'MuzzleLeft','Yaw/Pitch',[-1.8,-0.25,-6.8]);
	marker(s,'MuzzleRight','Yaw/Pitch',[1.8,-0.25,-6.8]);
	marker(s,'AimPoint','Yaw/Pitch',[0,0,0]);
	s.save('wall_sentinel');
}

const pylon=new Model('relay_pylon');
pylon.prism([[-5,0],[5,0],[3,4],[-3,4]],8,0);
pylon.prism([[-2.5,4],[2.5,4],[1.5,30],[-1.5,30]],4,1);
for (const x of [-1.7,1.7]) pylon.beam([x,5,2.2],[x*0.6,29,2.2],0.22,3);
for (const y of [10,17,24]) pylon.box([0,y,2.3],[2,0.45,0.3],4);
for (const side of [-1,1]) {
	pylon.beam([side*1.5,30,0],[side*5,35,0],0.8,2);
	pylon.beam([side*5,35,0],[side*2,37,0],0.25,3);
}
pylon.box([0,31,0],[1.5,3,1.5],3); pylon.save();
{
	const s=new Scene(); s.node('RelayPylon','Node3D',null); visual(s,'relay_pylon');
	s.boxBody('Foot','.',[0,2,0],[10,4,8]);
	s.boxBody('Tower','.',[0,17,0],[5,26,4]);
	marker(s,'Signal','.',[0,32,0]); s.save('relay_pylon'); s.saveCollision('relay_pylon');
}

const wreckage=(name,wide,variant)=>{
	const model=new Model(name),solids=[];
	const count=wide?[4,5,3][variant]:[3,4,2][variant];
	const width=wide?82:42,height=wide?20:62;
	for(let i=0;i<count;i++) {
		const left=-width/2+i*width/count+0.3,right=-width/2+(i+1)*width/count-0.3;
		const top=height/2-(i+variant)%3*(wide?1.6:5.0),bottom=-height/2+(i*2+variant)%3*(wide?0.8:3.5);
		const cut=(wide?2:5)+(i+variant)%3*(wide?0.6:2.0);
		const section=[[left,bottom+cut],[left+cut,bottom],[right-1,bottom+1],
			[right,top-cut],[right-cut,top],[left+1,top-1]];
		const points=model.prism(section,6+(i+variant)%3,i%2===0?1:0);
		solids.push(points);
		for(let j=0;j<section.length;j++) {
			const a=section[j],b=section[(j+1)%section.length];
			model.beam([a[0],a[1],4.3],[b[0],b[1],4.3],0.2,j%3===0?4:2);
		}
		const mid=(left+right)/2;
		model.beam([left+2,bottom+5,4.4],[right-2,top-5,4.4],0.55,2);
		model.beam([mid,bottom+3,4.5],[mid,top-3,4.5],0.35,variant===1?7:4);
		for(let j=0;j<3;j++) {
			const y=bottom+5+(top-bottom-10)*(j+0.5)/3;
			model.box([mid+(j%2?1:-1),y,4.5],[Math.max(2,(right-left)*0.4),0.7,0.4],4);
		}
		if(variant===2) {
			model.prism([[left+2,bottom+3],[right-2,bottom+6],[mid,top-4]],1.2,2,[0,0,5]);
		}
	}
	const structuralBeam=(a,b,width,material)=>{
		const first=model.vertices.length;
		model.beam(a,b,width,material);
		solids.push(model.vertices.slice(first));
	};
	if(wide) {
		structuralBeam([-39,-6,1],[2,5,2],1.4,2);
		structuralBeam([2,5,2],[38,-3,0],1.4,2);
	} else {
		structuralBeam([-19,-26,1],[12,8,2],1.8,2);
		structuralBeam([12,8,2],[18,24,0],1.8,2);
	}
	if(variant===1) {
		const hub=[[-5,-3],[0,-6],[5,-3],[5,3],[0,6],[-5,3]];
		solids.push(model.prism(hub,3.5,2,[wide?12:0,0,5]));
		model.prism(hub.map(([x,y])=>[x*0.55,y*0.55]),0.3,5,[wide?12:0,0,7]);
	}
	model.save();
	const scene=new Scene(); scene.node(wide?'AltitudeShutter':'BrokenBaffle','Node3D',null); visual(scene,name);
	scene.node('Solid','StaticBody3D','.','collision_layer = 8\ncollision_mask = 0');
	for(const [i,points] of solids.entries()) {
		const id=`shard_${i}`;
		scene.shape(id,'ConvexPolygonShape3D',`points = PackedVector3Array(${points.flat().map(round).join(', ')})`);
		scene.node(`Shard${i}`,'CollisionShape3D','Solid',`shape = SubResource("${id}")`);
	}
	scene.save(name);
};
for(let variant=0;variant<3;variant++) wreckage(variant===0?'broken_baffle':`broken_baffle_${variant}`,false,variant);

const routePoints = [[0,10,0],[0,10,-420],[120,15,-850],[300,20,-1300],[180,14,-1750],[-120,10,-2200],[-260,18,-2650],[-80,20,-3100],[220,12,-3550],[320,10,-4050],[100,18,-4550],[0,28,-5050],[0,36,-5550],[240,28,-6100],[500,18,-6650],[360,32,-7200],[-100,45,-7750],[-460,22,-8350],[-300,16,-8950],[160,30,-9500],[420,48,-10100],[200,60,-10700],[0,85,-11300],[0,130,-11900]];
for(let variant=0;variant<3;variant++) wreckage(variant===0?'altitude_shutter':`altitude_shutter_${variant}`,true,variant);
const arc = new Model('power_arc');
const arcPoints=[[-19,0,0],[-12,5,1],[-7,-3,-1],[0,4,0],[4,-5,2],[12,3,-1],[19,0,0]];
for(let i=1;i<arcPoints.length;i++) {
	arc.beam(arcPoints[i-1],arcPoints[i],0.22,3);
}
for(const x of [-20,20]) {
	arc.box([x,-4,0],[2,14,3],1);
	arc.box([x,2,0],[3,2,4],7);
}
arc.save();
const route = [];
const catmull = (a,b,c,d,t) => b.map((v,i)=>0.5*((2*v)+(-a[i]+c[i])*t+(2*a[i]-5*v+4*c[i]-d[i])*t*t+(-a[i]+3*v-3*c[i]+d[i])*t*t*t));
for(let j=0;j<routePoints.length-1;j++) {
	const steps=Math.ceil(Math.hypot(...sub(routePoints[j+1],routePoints[j]))/68);
	for(let k=0;k<steps;k++) route.push(catmull(routePoints[Math.max(0,j-1)],routePoints[j],routePoints[j+1],routePoints[Math.min(routePoints.length-1,j+2)],k/steps));
}
route.push(routePoints.at(-1));
let distance=0;
const samples=route.map((p,i)=>{
	if(i) distance+=Math.hypot(...sub(p,route[i-1]));
	const gateDistance=Math.abs(distance-4150);
	const halfWidth=gateDistance<80?20:gateDistance<300?20+(gateDistance-80)/11:40;
	return {distance:round(distance),position:p.map(round),half_width:round(halfWidth),min_height:-8,max_height:14};
});
const atDistance = d => {
	let i=samples.findIndex(s=>s.distance>=d); if(i<1)i=1;
	const a=samples[i-1],b=samples[i],t=(d-a.distance)/(b.distance-a.distance);
	const p=add(a.position,mul(sub(b.position,a.position),t));
	const tangent=unit(sub(b.position,a.position));
	return {position:p,yaw:Math.atan2(-tangent[0],-tangent[2])};
};
const routeEvents=[
	{id:'entry',distance:0,kind:'checkpoint'},
	{id:'first_pursuit',distance:650,kind:'wave'},
	{id:'bridge_warning',distance:1350,kind:'dialogue'},
	{id:'covered_channel',distance:1750,kind:'checkpoint'},
	{id:'sentinel_warning',distance:2250,kind:'dialogue'},
	{id:'gate_warning',distance:2150,kind:'dialogue'},
	{id:'service_gate',distance:4150,kind:'gate'},
	{id:'relay_checkpoint',distance:6500,kind:'checkpoint'},
	{id:'breakout',distance:11200,kind:'dialogue'},
	{id:'exit',distance:round(distance),kind:'finish'},
].sort((a,b)=>a.distance-b.distance);
const s=new Scene();
const batches=new Map();
const batchModel=(model,position,yaw,scale,d)=>{
	const id=`route_batch_${Math.floor(d/700)}`;
	const batch=batches.get(id)??new Model(id);
	batches.set(id,batch);
	const transform=p=>add(position,[Math.cos(yaw)*p[0]*scale[0]+Math.sin(yaw)*p[2]*scale[2],p[1]*scale[1],-Math.sin(yaw)*p[0]*scale[0]+Math.cos(yaw)*p[2]*scale[2]]);
	for(const [material,group] of models.get(model).groups) {
		const out=batch.groups.get(material)??{positions:[],normals:[]};
		batch.groups.set(material,out);
		for(let i=0;i<group.positions.length;i+=3) {
			const p=transform(group.positions.slice(i,i+3));
			out.positions.push(...p); batch.vertices.push(p);
			const n=group.normals.slice(i,i+3).map((v,k)=>v/scale[k]);
			out.normals.push(...unit([Math.cos(yaw)*n[0]+Math.sin(yaw)*n[2],n[1],-Math.sin(yaw)*n[0]+Math.cos(yaw)*n[2]]));
		}
	}
};
s.resource('PackedScene',`${res}/scenes/canyon_straight_collision.tscn`,'canyon');
s.resource('PackedScene',`${res}/scenes/service_bridge_collision.tscn`,'bridge');
s.resource('PackedScene',`${res}/scenes/covered_roof_collision.tscn`,'roof');
s.resource('PackedScene',`${res}/scenes/security_gate.tscn`,'gate');
s.resource('PackedScene',`${res}/scenes/relay_pylon_collision.tscn`,'pylon');
s.resource('PackedScene',`${res}/scenes/open_causeway_collision.tscn`,'causeway');
s.resource('PackedScene',`${res}/scenes/lattice_arch_collision.tscn`,'lattice');
s.resource('PackedScene',`${res}/scenes/industrial_spire_collision.tscn`,'spire');
s.resource('PackedScene',`${res}/scenes/broken_baffle.tscn`,'baffle');
s.resource('PackedScene',`${res}/scenes/altitude_shutter.tscn`,'shutter');
for(let variant=1;variant<3;variant++) {
	s.resource('PackedScene',`${res}/scenes/broken_baffle_${variant}.tscn`,`baffle_${variant}`);
	s.resource('PackedScene',`${res}/scenes/altitude_shutter_${variant}.tscn`,`shutter_${variant}`);
}
s.node('BlackChannel','Node3D',null,'metadata/asset_contract_version = 1\nmetadata/gameplay_implemented = false');
s.node('Geometry','Node3D','.');
for(let i=0;i<route.length-1;i++) {
	const a=route[i],b=route[i+1],p=mul(add(a,b),0.5),delta=sub(b,a);
	const horizontal=Math.hypot(delta[0],delta[2]);
	const yaw=Math.atan2(-delta[0],-delta[2]);
	// Overlap modules slightly at bends. Geometry stays level; route heights are flight centers.
	const d=samples[i].distance;
	const exposed=d<1100 || (d>=2100 && d<3000) || (d>=4350 && d<6500) || (d>=8200 && d<10000) || d>=11200;
	const origin=[p[0],p[1]-10,p[2]],stretch=[1,1,(horizontal+7)/96];
	batchModel(exposed?'open_causeway':'canyon_straight',origin,yaw,stretch,d);
	s.node(`Channel${String(i).padStart(3,'0')}`,'','Geometry',`position = ${vec([p[0],p[1]-10,p[2]])}\nrotation = Vector3(0, ${round(yaw)}, 0)\nscale = Vector3(1, 1, ${round((horizontal+7)/96)})`,exposed?'causeway':'canyon');
	if (exposed && i%3===0) {
		batchModel('lattice_arch',origin,yaw,[1,1,1],d);
		s.node(`Lattice${i}`,'','Geometry',`position = ${vec([p[0],p[1]-10,p[2]])}\nrotation = Vector3(0, ${round(yaw)}, 0)`,'lattice');
	}
	if (i%3===0) {
		for (const side of [-1,1]) {
			const setback=125+(i%5)*26;
			const x=Math.cos(yaw)*setback*side,z=-Math.sin(yaw)*setback*side;
			batchModel('industrial_spire',[p[0]+x,p[1]-30-(i%4)*12,p[2]+z],yaw+(side<0?0:Math.PI),[1,0.65+(i%5)*0.18,1],d);
			s.node(`Spire${i}${side<0?'L':'R'}`,'','Geometry',`position = ${vec([p[0]+x,p[1]-30-(i%4)*12,p[2]+z])}\nrotation = Vector3(0, ${round(yaw+(side<0?0:Math.PI))}, 0)\nscale = Vector3(1, ${round(0.65+(i%5)*0.18)}, 1)`,'spire');
		}
	}
	if(samples[i].distance>=1750 && samples[i].distance<2100) {
		batchModel('covered_roof',add(p,[0,30,0]),yaw,stretch,d);
		s.node(`Roof${i}`,'','Geometry',`position = ${vec(add(p,[0,30,0]))}\nrotation = Vector3(0, ${round(yaw)}, 0)\nscale = Vector3(1, 1, ${round((horizontal+7)/96)})`,'roof');
	}
	if (i%4===0 && i>0) {
		const x=Math.cos(yaw)*59,z=-Math.sin(yaw)*59;
		batchModel('relay_pylon',[p[0]+x,p[1]-24,p[2]+z],yaw,[1,1,1],d);
		s.node(`Pylon${i}`,'','Geometry',`position = ${vec([p[0]+x,p[1]-24,p[2]+z])}\nrotation = Vector3(0, ${round(yaw)}, 0)`,'pylon');
	}
	if (i%9===0 && d>900) {
		const side=i%2===0?1:-1;
		batchModel('power_arc',[p[0]+Math.cos(yaw)*side*80,p[1]+24,p[2]-Math.sin(yaw)*side*80],yaw,[1,1,1],d);
	}
}
for(const [i,d] of [180,1450,2050,2900,3300,5800,7200,9100,10800,11900].entries()) {
	const p=atDistance(d);
	batchModel('service_bridge',add(p.position,[0,24,0]),p.yaw,[1,1,1],d);
	s.node(`Bridge${i}`,'','Geometry',`position = ${vec(add(p.position,[0,24,0]))}\nrotation = Vector3(0, ${round(p.yaw)}, 0)`,'bridge');
}
for(const [id,batch] of batches) {
	batch.save();
	visual(s,id,'.',id);
}
const obstacles=[5200,6000,6900,7800,8700,9600,10500,11400,12300].filter(d=>d<distance-400).map((d,i)=>({
	id:`baffle_${i}`,distance:d,blocked_side:i%2===0?-1:1,safe_lateral:i%2===0?22:-22,variant:i%3,
}));
s.node('Obstacles','Node3D','.');
for(const o of obstacles) {
	const p=atDistance(o.distance),right=[Math.cos(p.yaw),0,-Math.sin(p.yaw)];
	s.node(o.id,'','Obstacles',`position = ${vec(add(p.position,mul(right,o.blocked_side*22)))}\nrotation = Vector3(0, ${round(p.yaw)}, 0)`,o.variant===0?'baffle':`baffle_${o.variant}`);
}
const gateAt=atDistance(4150);
const altitudeObstacles=[7350,8250,9150,10050,10950,11850].map((d,i)=>({
	id:`shutter_${i}`,distance:d,blocked_height:i%2===0?-12:22,safe_height:i%2===0?9:-1,variant:i%3,
}));
for(const o of altitudeObstacles) {
	const p=atDistance(o.distance);
	s.node(o.id,'','Obstacles',`position = ${vec(add(p.position,[0,o.blocked_height,0]))}\nrotation = Vector3(0, ${round(p.yaw)}, 0)`,o.variant===0?'shutter':`shutter_${o.variant}`);
}
s.node('ServiceGate','','.',`position = ${vec(add(gateAt.position,[0,-10,0]))}\nrotation = Vector3(0, ${round(gateAt.yaw)}, 0)`,'gate');
s.node('Markers','Node3D','.');
for(const e of routeEvents) {
	const p=atDistance(e.distance);
	s.node(e.id,'Marker3D','Markers',`position = ${vec(p.position)}\nrotation = Vector3(0, ${round(p.yaw)}, 0)\nmetadata/distance = ${e.distance}`);
}
s.node('EnemySpawns','Node3D','.');
for(const [i,d] of [450,900,2300].entries()) {
	const p=atDistance(d);
	s.node(`Needle${i}`,'Marker3D','EnemySpawns',`position = ${vec(add(p.position,[12,5,20]))}\nrotation = Vector3(0, ${round(p.yaw)}, 0)\nmetadata/distance = ${d}`);
}
s.node('SentinelSpawns','Node3D','.');
for(const [i,d] of [2450,2750,9400,11100].entries()) {
	const p=atDistance(d),side=i%2===0?-1:1;
	const right=[Math.cos(p.yaw),0,-Math.sin(p.yaw)];
	s.node(`Sentinel${i}`,'Marker3D','SentinelSpawns',`position = ${vec(add(p.position,add(mul(right,side*42),[0,-4,0])))}\nrotation = Vector3(0, ${round(p.yaw+Math.PI)}, 0)\nmetadata/distance = ${d}`);
}
s.save('black_channel_route');
output('route.json',JSON.stringify({
	version:1,units:'metres',forward:'-Z',up:'+Y',length:round(distance),
	nominal_speed:90,minimum_speed:32,maximum_speed:240,
	sections:[
		{id:'exposed_approach',from:0,to:1100,style:'causeway'},
		{id:'cliff_cut',from:1100,to:1750,style:'canyon'},
		{id:'covered_channel',from:1750,to:2100,style:'covered'},
		{id:'relay_expanse',from:2100,to:3000,style:'causeway'},
		{id:'service_lock',from:3000,to:4350,style:'canyon'},
		{id:'freight_causeway',from:4350,to:6500,style:'causeway'},
		{id:'baffle_cut',from:6500,to:8200,style:'canyon'},
		{id:'broken_grid',from:8200,to:10000,style:'causeway'},
		{id:'last_cut',from:10000,to:11200,style:'canyon'},
		{id:'breakout',from:11200,to:round(distance),style:'causeway'},
	],
	obstacles,altitude_obstacles:altitudeObstacles,
	player_clearance_radius:6,geometry_layer:1,player_layer:2,enemy_layer:4,
	samples,events:routeEvents,
	note:'Data and static scenery only. Cursor implements movement, events, enemies and campaign integration.',
},null,2)+'\n');

const environment = scene => {
	scene.resource('Shader','res://shaders/backlight_yard_sky.gdshader','yard_sky');
	scene.shape('sky_material','ShaderMaterial','shader = ExtResource("yard_sky")');
	scene.shape('sky','Sky','sky_material = SubResource("sky_material")');
	scene.shape('environment','Environment','background_mode = 2\nsky = SubResource("sky")\nambient_light_source = 3\nambient_light_color = Color(0.34, 0.47, 0.64, 1)\nambient_light_energy = 0.65\nreflected_light_source = 2\nfog_enabled = true\nfog_light_color = Color(0.055, 0.085, 0.13, 1)\nfog_density = 0.0018\ntonemap_mode = 0');
	scene.node('Environment','WorldEnvironment','.','environment = SubResource("environment")');
	scene.node('Moonlight','DirectionalLight3D','.','rotation_degrees = Vector3(-34, -28, 0)\nlight_color = Color(0.56, 0.72, 1, 1)\nlight_energy = 1.3');
	scene.node('Rim','DirectionalLight3D','.','rotation_degrees = Vector3(-18, 130, 0)\nlight_color = Color(0.6, 0.2, 0.35, 1)\nlight_energy = 0.65');
};
{
	const p=new Scene(); p.node('BlackChannelPreview','Node3D',null);
	p.resource('PackedScene',`${res}/scenes/black_channel_route.tscn`,'route');
	p.resource('PackedScene',`${res}/scenes/needle_drone.tscn`,'drone');
	p.resource('PackedScene',`${res}/scenes/wall_sentinel.tscn`,'turret');
	p.node('Route','','.','','route');
	p.node('NeedleLeft','','.','position = Vector3(-12, 14, 0)\nrotation_degrees = Vector3(0, 12, -12)','drone');
	p.node('NeedleRight','','.','position = Vector3(16, 17, -34)\nrotation_degrees = Vector3(0, -8, 9)','drone');
	p.node('Sentinel','','.','position = Vector3(38, 3, -55)\nrotation_degrees = Vector3(0, 155, 0)','turret');
	environment(p);
	p.node('Camera','Camera3D','.','position = Vector3(0, 18, 28)\nrotation_degrees = Vector3(-3, 0, 0)\nfov = 68.0\nfar = 1800.0\ncurrent = true');
	p.save('preview');
}
{
	const p=new Scene(); p.node('BlackChannelAssetGallery','Node3D',null);
	for(const [id,file] of [['drone','needle_drone'],['ash','ash_flight'],['turret','wall_sentinel'],['pylon','relay_pylon'],['gate','security_gate']]) p.resource('PackedScene',`${res}/scenes/${file}.tscn`,id);
	p.node('NeedleDrone','','.','position = Vector3(-17, 8, -4)\nrotation_degrees = Vector3(0, 150, -8)\nscale = Vector3(2, 2, 2)','drone');
	p.node('AshFlight','','.','position = Vector3(-3, 10, 18)\nrotation_degrees = Vector3(0, 150, 0)','ash');
	p.node('WallSentinel','','.','position = Vector3(7, 1, 6)\nrotation_degrees = Vector3(0, 160, 0)\nscale = Vector3(1.5, 1.5, 1.5)','turret');
	p.node('RelayPylon','','.','position = Vector3(24, 0, -25)','pylon');
	p.node('SecurityGate','','.','position = Vector3(-12, 0, -75)','gate');
	environment(p);
	p.node('Camera','Camera3D','.','position = Vector3(25, 26, 50)\nrotation_degrees = Vector3(-12, 24, 0)\nfov = 60.0\ncurrent = true');
	p.save('asset_gallery');
}
output('manifest.json',JSON.stringify({version:1,ownership:'Assistant-authored art. Cursor must not regenerate or replace models.',models:manifest},null,2)+'\n');

let failures=0;
for(const [name,data] of generated) {
	const target=path.join(root,name);
	if(checkOnly) {
		if(!fs.existsSync(target)||!fs.readFileSync(target).equals(data)) {
			console.error(`Asset is missing or differs from art source: ${name}`); failures++;
		}
	} else {
		fs.mkdirSync(path.dirname(target),{recursive:true});
		fs.writeFileSync(target,data);
	}
}
console.log(`BLACK_CHANNEL_ASSETS=${generated.size} MODELS=${manifest.length} TRIANGLES=${manifest.reduce((n,m)=>n+m.triangles,0)} ROUTE_METRES=${round(distance)} CHECK_FAILURES=${failures}`);
if(failures) process.exitCode=1;
