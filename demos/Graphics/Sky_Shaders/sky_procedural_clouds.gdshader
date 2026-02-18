// Simplified Volumetric Sky Shader for VisualGasic Demo
// Based on the official Godot 3D Sky Shaders demo.
// This version uses procedural noise instead of 3D texture lookups,
// making it self-contained (no external texture assets required).
//
// Features:
//   - Physical Rayleigh + Mie atmospheric scattering
//   - Procedural volumetric clouds (hash-based noise)
//   - Sun disk with configurable size
//   - Day/night cycle support (driven by DirectionalLight3D)
//   - Cloud coverage, density, and time controls

shader_type sky;
render_mode use_half_res_pass;

// Cloud parameters
uniform float cloud_density : hint_range(0.01, 0.99) = 0.05;
uniform float cloud_coverage : hint_range(0.0, 0.99) = 0.25;
uniform float cloud_time_scale : hint_range(0.0, 20.0) = 1.0;
uniform float cloud_time_offset : hint_range(0.0, 1000.0, 0.1) = 0.0;

// Atmosphere parameters
uniform float rayleigh : hint_range(0, 64) = 2.0;
uniform vec4 rayleigh_color : source_color = vec4(0.26, 0.41, 0.58, 1.0);
uniform float mie : hint_range(0, 1) = 0.005;
uniform float mie_eccentricity : hint_range(-1, 1) = 0.8;
uniform vec4 mie_color : source_color = vec4(0.63, 0.77, 0.92, 1.0);

uniform float turbidity : hint_range(0, 1000) = 10.0;
uniform float sun_disk_scale : hint_range(0, 360) = 1.0;
uniform vec4 ground_color : source_color = vec4(0.1, 0.07, 0.034, 1.0);
uniform float exposure : hint_range(0, 128) = 0.1;

const vec3 UP = vec3(0.0, 1.0, 0.0);
const float GROUND_RADIUS = 6000000.0;
const float SKY_BOTTOM_RADIUS = 6001500.0;
const float SKY_TOP_RADIUS = 6004000.0;
const float SOL_SIZE = 0.00872663806;
const float SUN_ENERGY = 1000.0;
const float rayleigh_zenith_size = 8.4e3;
const float mie_zenith_size = 1.25e3;

// Procedural noise functions (replace 3D texture lookups)
float hash31(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    return mix(
        mix(mix(hash31(i + vec3(0,0,0)), hash31(i + vec3(1,0,0)), f.x),
            mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
            mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y),
        f.z);
}

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise3d(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// Phase function for Mie scattering
float henyey_greenstein(float cos_theta, float g) {
    const float k = 0.0795774715459;
    return k * (1.0 - g * g) / (pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5));
}

// Analytic atmosphere
vec3 atmosphere(vec3 eye_dir) {
    float zenith_angle = clamp(dot(UP, normalize(LIGHT0_DIRECTION)), -1.0, 1.0);
    float sun_energy = max(0.0, 1.0 - exp(-((PI * 0.5) - acos(zenith_angle)))) * SUN_ENERGY * LIGHT0_ENERGY;
    float sun_fade = 1.0 - clamp(1.0 - exp(LIGHT0_DIRECTION.y), 0.0, 1.0);

    float rayleigh_coefficient = rayleigh - (1.0 * (1.0 - sun_fade));
    vec3 rayleigh_beta = rayleigh_coefficient * rayleigh_color.rgb * 0.0001;
    vec3 mie_beta = turbidity * mie * mie_color.rgb * 0.000434;

    float zenith = acos(max(0.0, dot(UP, eye_dir)));
    float optical_mass = 1.0 / (cos(zenith) + 0.15 * pow(93.885 - degrees(zenith), -1.253));
    float rayleigh_scatter = rayleigh_zenith_size * optical_mass;
    float mie_scatter = mie_zenith_size * optical_mass;

    vec3 extinction = exp(-(rayleigh_beta * rayleigh_scatter + mie_beta * mie_scatter));
    float cos_theta = dot(eye_dir, normalize(LIGHT0_DIRECTION));
    float rayleigh_phase = (3.0 / (16.0 * PI)) * (1.0 + pow(cos_theta * 0.5 + 0.5, 2.0));
    vec3 betaRTheta = rayleigh_beta * rayleigh_phase;
    float mie_phase = henyey_greenstein(cos_theta, mie_eccentricity);
    vec3 betaMTheta = mie_beta * mie_phase;

    vec3 Lin = pow(sun_energy * ((betaRTheta + betaMTheta) / (rayleigh_beta + mie_beta)) * (1.0 - extinction), vec3(1.5));
    Lin *= mix(vec3(1.0), pow(sun_energy * ((betaRTheta + betaMTheta) / (rayleigh_beta + mie_beta)) * extinction, vec3(0.5)),
               clamp(pow(1.0 - zenith_angle, 5.0), 0.0, 1.0));
    Lin *= mix(ground_color.rgb, vec3(1.0), smoothstep(-0.1, 0.1, dot(UP, eye_dir)));

    // Sun disk
    float sunAngularDiameterCos = cos(SOL_SIZE * sun_disk_scale);
    float sunAngularDiameterCos2 = cos(SOL_SIZE * sun_disk_scale * 0.5);
    float sundisk = smoothstep(sunAngularDiameterCos, sunAngularDiameterCos2, cos_theta);
    Lin += (sun_energy * 1900.0 * extinction) * sundisk;

    return Lin * exposure;
}

// Simple cloud density using procedural noise
float cloud_density_at(vec3 p) {
    float time = cloud_time_offset * cloud_time_scale * 0.003;
    vec3 wind = vec3(time * 0.9, 0.0, time * 1.0);

    float height_fraction = clamp((length(p) - SKY_BOTTOM_RADIUS) / (SKY_TOP_RADIUS - SKY_BOTTOM_RADIUS), 0.0, 1.0);
    // Height-based density gradient
    float height_gradient = 4.0 * height_fraction * (1.0 - height_fraction);

    float n = fbm(p * 0.00008 + wind);
    float base_cloud = smoothstep(1.0 - cloud_coverage, 1.0, n) * height_gradient;
    return base_cloud;
}

float intersect_sphere(vec3 pos, vec3 dir, float r) {
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, pos);
    float c = dot(pos, pos) - r * r;
    float d = b * b - 4.0 * a * c;
    if (d < 0.0) return -1.0;
    return max((-b + sqrt(d)) / (2.0 * a), (-b - sqrt(d)) / (2.0 * a));
}

vec4 march_clouds(vec3 dir, vec3 background) {
    if (dir.y <= 0.0) {
        return vec4(background, 1.0);
    }

    vec3 camera_pos = vec3(0.0, GROUND_RADIUS, 0.0);
    float t_start = intersect_sphere(camera_pos, dir, SKY_BOTTOM_RADIUS);
    float t_end = intersect_sphere(camera_pos, dir, SKY_TOP_RADIUS);
    if (t_start < 0.0) t_start = 0.0;

    vec3 start = camera_pos + dir * t_start;
    vec3 end_pos = camera_pos + dir * t_end;
    float shell_dist = length(end_pos - start);

    const int STEPS = 24;
    vec3 ray_step = dir * shell_dist / float(STEPS);
    vec3 ldir = normalize(LIGHT0_DIRECTION);

    float T = 1.0;
    float alpha = 0.0;
    vec3 L = vec3(0.0);
    vec3 p = start + ray_step * hash31(start * 10.0);

    float cos_theta = dot(ldir, normalize(dir));
    float phase = max(henyey_greenstein(cos_theta, 0.6), henyey_greenstein(cos_theta, -0.2));

    vec3 sun_color = atmosphere(ldir);
    vec3 ambient = atmosphere(normalize(vec3(1.0, 1.0, 0.0)));

    for (int i = 0; i < STEPS; i++) {
        float d = cloud_density_at(p);
        if (d > 0.001) {
            float dt = exp(-cloud_density * d * length(ray_step));
            float height_fraction = clamp((length(p) - SKY_BOTTOM_RADIUS) / (SKY_TOP_RADIUS - SKY_BOTTOM_RADIUS), 0.0, 1.0);

            // Simple light sampling
            float ld = cloud_density_at(p + ldir * 300.0);
            float light_atten = exp(-cloud_density * ld * 300.0);

            vec3 cloud_color = mix(ambient * 0.3, sun_color * phase, light_atten) * T * d;
            alpha += (1.0 - dt) * (1.0 - alpha);
            L += cloud_color;
            T *= dt;
        }
        p += ray_step;
    }

    vec3 col = background * (1.0 - alpha) + L;
    col = mix(clamp(col, vec3(0.0), vec3(1.0)), clamp(background, vec3(0.0), vec3(1.0)),
              smoothstep(0.6, 1.0, 1.0 - dir.y));
    return vec4(col, 1.0);
}

void sky() {
    vec3 background = atmosphere(EYEDIR);

    if (AT_HALF_RES_PASS) {
        vec4 clouds = march_clouds(EYEDIR, background);
        COLOR = clouds.rgb;
        ALPHA = clouds.a;
    } else if (AT_CUBEMAP_PASS) {
        COLOR = background;
    } else {
        if (HALF_RES_COLOR.a > 0.0) {
            COLOR = HALF_RES_COLOR.rgb;
        } else {
            COLOR = background;
        }
    }
}
