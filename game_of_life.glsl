#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba8, binding = 0) uniform image2D current_state;
layout(rgba8, binding = 1) uniform image2D next_state;

vec4 get_age_color(float age) {
    float normalized_age = min(age / 100.0, 1.0);
    vec3 young_color = vec3(0.0, 0.5, 1.0);
    vec3 mid_color = vec3(0.0, 1.0, 0.0);
    vec3 old_color = vec3(1.0, 0.0, 0.0);
    vec3 color;
    if (normalized_age < 0.5) {
        color = mix(young_color, mid_color, normalized_age * 2.0);
    } else {
        color = mix(mid_color, old_color, (normalized_age - 0.5) * 2.0);
    }
    
    return vec4(color, 1.0);
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(current_state);
    if (pos.x >= size.x || pos.y >= size.y) {
        return;
    }
    int neighbors = 0;
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;
            
            ivec2 neighbor = pos + ivec2(dx, dy);
            neighbor = ivec2(
                (neighbor.x + size.x) % size.x,
                (neighbor.y + size.y) % size.y
            );
            vec4 neighbor_color = imageLoad(current_state, neighbor);
            neighbors += int(length(neighbor_color.rgb) > 0.1);
        }
    }
    
    vec4 current_color = imageLoad(current_state, pos);
    float age = 0.0;
    if (length(current_color.rgb) > 0.1) {
        vec3 color = current_color.rgb;
        if (color.b > color.g && color.g >= color.r) {
            age = (color.g / 0.5) * 25.0;
        } else if (color.g >= color.b && color.g >= color.r) {
            age = 50.0 + (1.0 - color.b) * 25.0;
        } else {
            age = 75.0 + (color.r) * 25.0;
        }
    }
    vec4 next_color = vec4(0.0, 0.0, 0.0, 1.0);
    if (length(current_color.rgb) > 0.1) {
        if (neighbors == 2 || neighbors == 3) {
            age = min(age + 1.0, 100.0);
            next_color = get_age_color(age);
        }
    } else {
        if (neighbors == 3) {
            next_color = vec4(0.0, 0.5, 1.0, 1.0);
        }
    }
    
    imageStore(next_state, pos, next_color);
}