// Buffers to receive gaussians data from Lua
layout(set = 2, binding = 0) buffer Positions {
    vec3 positions[];
};
layout(set = 2, binding = 1) buffer Rotations {
    vec4 rotations[];
};
layout(set = 2, binding = 2) buffer Scales {
    vec3 scales[];
};
layout(set = 2, binding = 3) buffer Opacities {
    float opacities[];
};
layout(set = 2, binding = 4) buffer Colors {
    vec3 colors[];
};
layout(set = 2, binding = 5) buffer Debug {
    float debug[128];
};

Constants{     
    float scale_modifier; 
    vec3 hfovxy_focal;
};


// To pass the computed colors to the Fragment shader
out vec4 color;
out vec3 conic;
out vec2 coordxy;
out float alpha;


// Tahen from the Gaussian Viewer, thanks
mat3 computeCov3D(vec3 scale, vec4 q)  // should be correct
{
    mat3 S = mat3(0.f);
    S[0][0] = scale.x;
	S[1][1] = scale.y;
	S[2][2] = scale.z;
	float r = q.x;
	float x = q.y;
	float y = q.z;
	float z = q.w;

    mat3 R = mat3(
		1.f - 2.f * (y * y + z * z), 2.f * (x * y - r * z), 2.f * (x * z + r * y),
		2.f * (x * y + r * z), 1.f - 2.f * (x * x + z * z), 2.f * (y * z - r * x),
		2.f * (x * z - r * y), 2.f * (y * z + r * x), 1.f - 2.f * (x * x + y * y)
	);

    mat3 M = S * R;
    mat3 Sigma = transpose(M) * M;
    return Sigma;
}

vec3 computeCov2D(vec4 mean_view, float focal_x, float focal_y, float tan_fovx, float tan_fovy, mat3 cov3D, mat4 viewmatrix)
{
    vec4 t = mean_view;
    // why need this? Try remove this later
    float limx = 1.3f * tan_fovx;
    float limy = 1.3f * tan_fovy;
    float txtz = t.x / t.z;
    float tytz = t.y / t.z;
    t.x = min(limx, max(-limx, txtz)) * t.z;
    t.y = min(limy, max(-limy, tytz)) * t.z;

    mat3 J = mat3(
        focal_x / t.z, 0.0f, -(focal_x * t.x) / (t.z * t.z),
		0.0f, focal_y / t.z, -(focal_y * t.y) / (t.z * t.z),
		0, 0, 0
    );
    mat3 W = transpose(mat3(viewmatrix));
    mat3 T = W * J;

    mat3 cov = transpose(T) * transpose(cov3D) * T;
    // Apply low-pass filter: every Gaussian should be at least
	// one pixel wide/high. Discard 3rd row and column.
	cov[0][0] += 0.3f;
	cov[1][1] += 0.3f;
    return vec3(cov[0][0], cov[0][1], cov[1][1]);
}
//#define BaseInstance gl_BaseInstance
//#define BaseVertex gl_BaseVertex
//#define DrawIndex gl_DrawIndex
//#define InstanceIndex (gl_InstanceIndex - gl_BaseInstance) -- Whcih instance are we considering
//#define PointSize gl_PointSize
//#define Position gl_Position
//#define VertexIndex gl_VertexIndex // which vertex of the instance

// Our main
vec4 lovrmain(){
    //debug[51+(InstanceIndex*4 + VertexIndex )* 2]=VertexPosition.x;
    //debug[52+(InstanceIndex*4 + VertexIndex )* 2]=VertexPosition.y;
    
    // Load positon data and convert to View space and screen space
    vec4 world_pos = vec4(positions[InstanceIndex], 1.);
    //world_pos.xy = world_pos.xy + + VertexPosition.xy*.1;
    vec4 g_pos_view = ViewFromLocal * world_pos; 
    vec4 g_pos_screen = Projection * g_pos_view;
	g_pos_screen.xyz = g_pos_screen.xyz / g_pos_screen.w;
    g_pos_screen.w = 1.f;
    
    // early culling
	// if (any(greaterThan(abs(g_pos_screen.xyz), vec3(1.3))))
	// {
	// 	gl_Position = vec4(-100, -100, -100, 1);
	// 	return;
	// }
    // // Load rotation scale and opacity
    vec4 g_rot = rotations[InstanceIndex];
	vec3 g_scale = scales[InstanceIndex];
	float g_opacity = opacities[InstanceIndex];

    // Compute 3D covariance martix of the associated gaussian, from rotation and size values
    // In paper it takes R and S and computes /Sigma
    mat3 cov3d = computeCov3D(g_scale * scale_modifier, g_rot);
	// Vec2 encoding screen size
    vec2 wh = 2 * hfovxy_focal.xy * hfovxy_focal.z;
	// Project 3D gaussian onto 2D camera image plane via 2001 Zwicker work
    // In paper produces J and W and combines with /Sigma to produce /Sigma', and selects only upper left 2D componets needed to render to image
    // output is XX, XY YY components of covariance 
    vec3 cov2d = computeCov2D(g_pos_view, 
                              hfovxy_focal.z, 
                              hfovxy_focal.z, 
                              hfovxy_focal.x, 
                              hfovxy_focal.y, 
                              cov3d, 
                              ViewFromLocal);

    // Invert covariance (EWA algorithm)
    // Compute determinant of covariance matrix. If determainanto is 0 then the raows are not unique and the gaussian is not visible (?)
	float det = (cov2d.x * cov2d.z - cov2d.y * cov2d.y);
	if (det == 0.0f)
		gl_Position = vec4(0.f, 0.f, 0.f, 0.f);
    // Invter the determinant
    float det_inv = 1.f / det;
	// Some sort of reordered and rescaled representation of the 2D covariance, for the fragment shader
	conic = vec3(cov2d.z * det_inv, -cov2d.y * det_inv, cov2d.x * det_inv);
	
    // I think this computes the size of the quad in pixels given the 2D gaussian 
    // times 3 vause it's a gaussian interval of 99%??
    vec2 quadwh_scr = vec2(3.f * sqrt(cov2d.x), 3.f * sqrt(cov2d.z));  // screen space half quad height and width
    // Screen dimenions
    wh = vec2(1280, 720);
    // convter from pixel dimensions to normalized screen space
	vec2 quadwh_ndc = quadwh_scr / wh;// * 2;  // in ndc space
    // Create the flat quad by movign the 4 Vetices (VertexPosition) by the size of the covariance (quadwh_ndc) and add them to the center of the gaussian (g_pos_screen
    g_pos_screen.xy = g_pos_screen.xy + VertexPosition.xy * quadwh_ndc;
   
    debug[51+(InstanceIndex*4 + VertexIndex )* 2]=quadwh_ndc.x;
    debug[52+(InstanceIndex*4 + VertexIndex )* 2]=quadwh_ndc.y;
    debug[1+(InstanceIndex*4 + VertexIndex )* 2]=quadwh_scr.x;
    debug[2+(InstanceIndex*4 + VertexIndex )* 2]=quadwh_scr.y;
    // Vertex position in pixels inside the quad 
    coordxy = VertexPosition.xy * quadwh_scr;
    //gl_Position = g_pos_screen;

    alpha = g_opacity;
	// Render depth effect, passing the Z component as color after processing
	//if (render_mod == -1)
	//{
		float depth = -g_pos_view.z;
		depth = depth < 0.05 ? 1 : depth;
		depth = 1 / depth;
		color = vec4(depth, depth, depth, 1.);
		//return g_pos_screen;
	//}


    //color = vec4(colors[InstanceIndex], 1.);
    return g_pos_screen;
}