import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.join(project, 'assets/black_channel');
const readJSON = name => JSON.parse(fs.readFileSync(path.join(root,name),'utf8'));
const manifest = readJSON('manifest.json');
const route = readJSON('route.json');
const encounter = readJSON('encounter.json');

test('all original models match the authored manifest', () => {
	assert.equal(manifest.models.filter(m=>!m.id.startsWith('route_batch_')).length,20);
	assert.ok(manifest.models.filter(m=>m.id.startsWith('route_batch_')).length>=18);
	for (const model of manifest.models) {
		const bin=fs.readFileSync(path.join(project,model.model.replace('res://','')));
		assert.equal(crypto.createHash('sha256').update(bin).digest('hex'),model.sha256,model.id);
		assert.equal(bin.readUInt32LE(0),0x46546c67);
		assert.equal(bin.readUInt32LE(4),2);
		assert.equal(bin.readUInt32LE(8),bin.length);
		assert.ok(model.triangles>0 && model.triangles<(model.id.startsWith('route_batch_')?20000:2500));
		assert.ok(model.min.every((v,i)=>Number.isFinite(v)&&v<model.max[i]));
	}
});

test('GLB attributes are finite, normals unit length, winding outward', () => {
	for(const model of manifest.models) {
		const bin=fs.readFileSync(path.join(project,model.model.replace('res://','')));
		const jsonSize=bin.readUInt32LE(12);
		const gltf=JSON.parse(bin.subarray(20,20+jsonSize).toString());
		const start=20+jsonSize+8;
		for(const primitive of gltf.meshes[0].primitives) {
			const attributes={};
			for(const [name,index] of Object.entries(primitive.attributes)) {
				const accessor=gltf.accessors[index],view=gltf.bufferViews[accessor.bufferView];
				assert.ok(view.byteOffset+view.byteLength<=gltf.buffers[0].byteLength);
				const values=[];
				for(let i=0;i<accessor.count*3;i++) values.push(bin.readFloatLE(start+view.byteOffset+i*4));
				assert.ok(values.every(Number.isFinite),`${model.id}:${name}`);
				attributes[name]=values;
			}
			const positions=attributes.POSITION,normals=attributes.NORMAL;
			assert.equal(positions.length,normals.length);
			assert.equal(positions.length%9,0);
			for(let i=0;i<positions.length;i+=9) {
				const a=positions.slice(i,i+3),b=positions.slice(i+3,i+6),c=positions.slice(i+6,i+9);
				const ab=b.map((v,k)=>v-a[k]),ac=c.map((v,k)=>v-a[k]);
				const cross=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]];
				assert.ok(Math.hypot(...cross)>0.000001,`${model.id}:degenerate triangle`);
				assert.ok(cross.reduce((sum,v,k)=>sum+v*normals[i+k],0)>0,`${model.id}:winding`);
				assert.ok(Math.abs(Math.hypot(...normals.slice(i,i+3))-1)<0.00001);
			}
		}
	}
});

test('all native scene dependencies exist locally', () => {
	for(const name of fs.readdirSync(path.join(root,'scenes'))) {
		const scene=fs.readFileSync(path.join(root,'scenes',name),'utf8');
		for(const match of scene.matchAll(/path="res:\/\/([^"]+)"/g)) {
			assert.ok(fs.existsSync(path.join(project,match[1])),`${name}: ${match[1]}`);
			assert.ok(match[1].startsWith('assets/black_channel/') || match[1]==='shaders/backlight_yard_sky.gdshader');
		}
		assert.ok(!scene.includes('type="Script"'),`${name}: art must not contain controllers`);
	}
});

test('lattice braces terminate on a complete rear frame with depth ties', () => {
	const bin=fs.readFileSync(path.join(root,'models/lattice_arch.glb'));
	const jsonSize=bin.readUInt32LE(12);
	const gltf=JSON.parse(bin.subarray(20,20+jsonSize).toString());
	const start=20+jsonSize+8;
	const armor=gltf.meshes[0].primitives.find(p=>gltf.materials[p.material].name==='armor');
	assert.ok(armor);
	const accessor=gltf.accessors[armor.attributes.POSITION];
	const view=gltf.bufferViews[accessor.bufferView];
	const vertices=[];
	for(let i=0;i<accessor.count;i++) {
		vertices.push([0,1,2].map(k=>bin.readFloatLE(start+view.byteOffset+(i*3+k)*4)));
	}
	const points=[[-60,-20,0],[-60,32,0],[-38,64,0],[38,64,0],[60,32,0],[60,-20,0]];
	for(const p of points) {
		assert.ok(vertices.some(v=>Math.hypot(...v.map((n,k)=>n-(p[k]+(k===2?-24:0))))<2),`rear node ${p}`);
	}
	// The rear crown and its two shoulders must have full structural beams.
	for(let i=1;i<4;i++) {
		const a=points[i],b=points[i+1];
		assert.ok(vertices.some(v=>Math.abs(v[0]-a[0])<2 && Math.abs(v[1]-a[1])<2 && v[2]<-23));
		assert.ok(vertices.some(v=>Math.abs(v[0]-b[0])<2 && Math.abs(v[1]-b[1])<2 && v[2]<-23));
	}
});

test('route distance, duration and sample spacing meet the encounter contract', () => {
	assert.ok(route.length>12000 && route.length<15000);
	assert.equal(route.minimum_speed,32);
	assert.equal(route.nominal_speed,90);
	assert.equal(route.maximum_speed,240);
	assert.ok(route.length/route.nominal_speed>130 && route.length/route.nominal_speed<170);
	let distance=0;
	for(let i=1;i<route.samples.length;i++) {
		const a=route.samples[i-1],b=route.samples[i];
		const step=Math.hypot(...b.position.map((v,k)=>v-a.position[k]));
		assert.ok(step<90 && step>0);
		distance+=step;
		assert.ok(Math.abs(b.distance-distance)<0.001);
		assert.ok(b.half_width>=20 && b.half_width<=40);
		assert.ok(b.min_height<b.max_height);
	}
	assert.ok(Math.abs(distance-route.length)<0.001);
});

test('staggered solid baffles have alternating flyable gaps and advance warning spacing', () => {
	assert.ok(route.obstacles.length>=8);
	for(let i=0;i<route.obstacles.length;i++) {
		const obstacle=route.obstacles[i];
		assert.ok(obstacle.distance>4500 && obstacle.distance<route.length-400);
		assert.equal(Math.abs(obstacle.safe_lateral),22);
		assert.equal(obstacle.safe_lateral*obstacle.blocked_side,-22);
		if(i) {
			assert.notEqual(obstacle.blocked_side,route.obstacles[i-1].blocked_side);
			assert.ok(obstacle.distance-route.obstacles[i-1].distance>=800);
		}
	}
	const scene=fs.readFileSync(path.join(root,'scenes/black_channel_route.tscn'),'utf8');
	assert.equal((scene.match(/instance=ExtResource\("baffle(?:_[12])?"\)/g)||[]).length,route.obstacles.length);
	assert.ok(scene.includes('canyon_straight_collision.tscn'));
	assert.ok(scene.includes('route_batch_0.glb'));
});

test('exposed causeways and industrial landmarks break up the enclosed channel', () => {
	const scene=fs.readFileSync(path.join(root,'scenes/black_channel_route.tscn'),'utf8');
	assert.ok((scene.match(/instance=ExtResource\("causeway"\)/g)||[]).length>40);
	assert.ok((scene.match(/instance=ExtResource\("canyon"\)/g)||[]).length>20);
	assert.ok((scene.match(/instance=ExtResource\("lattice"\)/g)||[]).length>10);
	assert.ok((scene.match(/instance=ExtResource\("spire"\)/g)||[]).length>40);
	assert.equal(route.sections[0].from,0);
	assert.equal(route.sections.at(-1).to,route.length);
	for(let i=1;i<route.sections.length;i++) assert.equal(route.sections[i-1].to,route.sections[i].from);
	const ash=manifest.models.find(m=>m.id==='ash_flight');
	assert.ok(ash);
	assert.ok(ash.min.every((v,i)=>Math.abs(v)<6 && Math.abs(ash.max[i])<6));
});

test('route markers and dialogue use the same event identifiers', () => {
	const events=new Set(route.events.map(e=>e.id));
	assert.equal(events.size,route.events.length);
	const scene=fs.readFileSync(path.join(root,'scenes/black_channel_route.tscn'),'utf8');
	for(const event of route.events) {
		assert.ok(event.distance>=0 && event.distance<=route.length);
		assert.ok(scene.includes(`name="${event.id}" type="Marker3D" parent="Markers"`));
	}
	for(const line of encounter.dialogue) assert.ok(events.has(line.event),line.event);
	for(const id of encounter.checkpoints) assert.ok(events.has(id));
	for(const wave of encounter.suggested_waves) {
		assert.ok(events.has(wave.event));
		assert.ok(fs.existsSync(path.join(root,'scenes',`${wave.enemy}.tscn`)));
	}
});

test('gate opening has sufficient approach time at maximum speed', () => {
	const request=route.events.find(e=>e.id===encounter.gate.request_event);
	const crossing=route.events.find(e=>e.id===encounter.gate.clearance_event);
	const available=(crossing.distance-request.distance)/route.maximum_speed;
	assert.ok(available>encounter.gate.opening_seconds+2);
	assert.ok(route.samples.filter(s=>Math.abs(s.distance-crossing.distance)<80).every(s=>s.half_width===20));
});

test('encounter preserves the post-alliance story boundary', () => {
	assert.ok(encounter.campaign_gate.requires.includes('rob_allied'));
	assert.ok(encounter.campaign_gate.requires.includes('orac_online'));
	assert.ok(encounter.campaign_gate.requires.includes('final_repair_item_secured'));
	assert.ok(encounter.campaign_gate.requires.includes('other_repair_items_secured'));
	assert.ok(encounter.completion_effects.includes('exterior_drive_repair_pending'));
	assert.ok(!encounter.completion_effects.includes('resume_survey_with_component'));
	assert.ok(encounter.campaign_gate.excludes.includes('first_visit_escape'));
	assert.equal(encounter.status,'gameplay_not_implemented');
	assert.equal(encounter.gate.allow_closing_behind_player,false);
});

test('late shutters alternate altitude with fair top-speed reaction time', () => {
	assert.equal(route.altitude_obstacles.length,6);
	for(const [i,o] of route.altitude_obstacles.entries()) {
		assert.ok(o.distance>6500 && o.distance<route.length-800);
		assert.ok(Math.abs(o.safe_height-o.blocked_height)>16);
		assert.ok(o.safe_height>=-8 && o.safe_height<=14);
		if(i) {
			const previous=route.altitude_obstacles[i-1];
			assert.notEqual(Math.sign(previous.safe_height),Math.sign(o.safe_height));
			assert.ok((o.distance-previous.distance)/240>3.5);
		}
	}
});

test('wreckage cycles distinct silhouettes with shard collision instead of a solid box proxy', () => {
	for(const base of ['broken_baffle','altitude_shutter']) {
		const hashes=new Set();
		for(let variant=0;variant<3;variant++) {
			const id=variant===0?base:`${base}_${variant}`;
			hashes.add(manifest.models.find(m=>m.id===id).sha256);
			const scene=fs.readFileSync(path.join(root,'scenes',`${id}.tscn`),'utf8');
			assert.ok(!scene.includes('BoxShape3D'),id);
			assert.ok((scene.match(/ConvexPolygonShape3D/g)||[]).length>=4,id);
		}
		assert.equal(hashes.size,3);
	}
	assert.deepEqual(new Set(route.obstacles.map(o=>o.variant)),new Set([0,1,2]));
	assert.deepEqual(new Set(route.altitude_obstacles.map(o=>o.variant)),new Set([0,1,2]));
	const scene=fs.readFileSync(path.join(root,'scenes','black_channel_route.tscn'),'utf8');
	assert.equal((scene.match(/name="Sentinel\d"/g)||[]).length,4);
});
