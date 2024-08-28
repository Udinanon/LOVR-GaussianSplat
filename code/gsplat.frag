in vec3 color;
in vec3 conic;
in vec2 coordxy;
in float alpha;

Constants{
    int render_mode;
};

vec4 lovrmain(){
    vec4 out_color = vec4(0.);

    if (render_mode == -2)
    {
        out_color = vec4(color, 1.f);
        return out_color;
    }

    float power = -0.5f * (conic.x * coordxy.x * coordxy.x + conic.z * coordxy.y * coordxy.y) - conic.y * coordxy.x * coordxy.y;
    if (power > 0.f)
        discard;
    float opacity = min(0.99f, alpha * exp(power));
    if (opacity < 1.f / 255.f)
        discard;
    out_color = vec4(color, opacity);

    // handling special shading effect
    if (render_mode == -3)
        out_color.a = out_color.a > 0.22 ? 1 : 0;
    else if (render_mode == -4)
    {
        out_color.a = out_color.a > 0.22 ? 1 : 0;
        out_color.rgb = out_color.rgb * exp(power);
    }
    return out_color;
}