#[compute]
#version 450
// Lorenz attractor compute pass (blueprint — same math as showcase_lorenz_cloud.gd).
// Full RenderingDevice pipeline hookup is deferred; CPU MultiMesh uses identical equations.

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer ParticleBuffer {
	vec4 positions[];
};

layout(push_constant) uniform Constants {
	float time;
	float delta;
} params;

void main() {
	uint id = gl_GlobalInvocationID.x;
	vec3 p = positions[id].xyz;

	float sigma = 10.0;
	float rho = 28.0;
	float beta = 8.0 / 3.0;

	vec3 d;
	d.x = sigma * (p.y - p.x);
	d.y = p.x * (rho - p.z) - p.y;
	d.z = p.x * p.y - beta * p.z;

	p += d * params.delta * 0.08;

	if (length(p) > 42.0) {
		p = vec3(sin(float(id) * 0.04) * 0.4, cos(float(id) * 0.035) * 0.4, 8.0);
	}

	positions[id].xyz = p;
}
