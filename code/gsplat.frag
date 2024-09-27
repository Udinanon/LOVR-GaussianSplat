in vec3 color;
in vec3 conic;
in vec2 coordxy;
in float alpha;
in vec2 render_index;

Constants{     
    float scale_modifier; 
    vec3 hfovxy_focal;
    int render_mode;
};

vec4 lovrmain(){
    vec4 out_color = vec4(0.);
    // realy out for specfic rendering modes
    if (render_mode == -2)
    {
        out_color = vec4(color, 1.f);
        return out_color;
    }
    if (render_mode == -1)
    {
        out_color = vec4(color, 1.f);
        return out_color;
    }

    // computes a dropout from the gaussians center based on the conic paramters from the vertex shader
    float power = -0.5f * (conic.x * coordxy.x * coordxy.x + conic.z * coordxy.y * coordxy.y) + conic.y * coordxy.x * coordxy.y * 0;
    // Discard irrelevant splats
    if (power > 0.f)
        discard;
    float opacity = min(0.99f, alpha * exp(power));
    // Cull those with too low opacity
    if (opacity < 1.f / 255.f)
        discard;
    // Normal rendering
    if (render_mode >= 0)
        out_color = vec4(color, opacity);

    
    // handling special shading effect
    
    if (render_mode == -3) // Billboards
    {
        out_color = vec4(color, opacity);
        out_color.a = out_color.a > 0.22 ? 1 : 0;
    }
    
    if (render_mode == -4) // Opaque balls
    {
        out_color = vec4(color, opacity);
        out_color.a = out_color.a > 0.22 ? 1 : 0;
        out_color.rgb = out_color.rgb * exp(power);
    }

    if (render_mode == -5) // visualize opacity
        out_color = vec4(opacity, 0, 0, 1);
    if (render_mode == -6) // visualize in quad pixel coordinates
    {
        out_color = vec4(coordxy, 0, 1);
    }
    if (render_mode == -7) // Visualize power component
    {
        out_color = vec4(-power, 0, 0, 1);
    }  
    if (render_mode == -8) // visualize render index and sorting effect
    {
        // custom values digmoids allow us to squeeze the values into the [0,1] range smoothly
        float flattened = (2 /( 1 + exp(-render_index.x/10000))) -1;
        float flattened_2 = (2 /( 1 + exp(-render_index.y/10000))) -1;
        out_color = vec4(flattened, flattened_2, 0, 1);
    }
    return out_color;
}