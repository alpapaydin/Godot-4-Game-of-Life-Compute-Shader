#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(r8, binding = 0) uniform image2D current_state;
layout(r8, binding = 1) uniform image2D next_state;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(current_state);
    if (pos.x >= size.x || pos.y >= size.y) {
        return;
    }
    int neighbors = 0;
    // Count neighbors
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            if (dx == 0 && dy == 0) continue;
            ivec2 neighbor = pos + ivec2(dx, dy);
            // Wrap around edges
            neighbor = ivec2(
                (neighbor.x + size.x) % size.x,
                (neighbor.y + size.y) % size.y
            );
            float state = imageLoad(current_state, neighbor).r;
            neighbors += int(state > 0.5);
        }
    }
    float current = imageLoad(current_state, pos).r;
    // Check if alive
    float next = 0.0;
    if (current > 0.5) {
        next = (neighbors == 2 || neighbors == 3) ? 1.0 : 0.0;
    } else {
        next = (neighbors == 3) ? 1.0 : 0.0;
    }
    imageStore(next_state, pos, vec4(next));
}