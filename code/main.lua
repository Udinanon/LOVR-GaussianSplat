function lovr.load()
    -- Load and comppile shaders
    shader = lovr.graphics.newShader("gsplat.vert", "gsplat.frag")

    -- Structure of the gaussian data
    --     vec3 g_pos[];
	--     vec4 g_rot[];
	--     vec3 g_scale[];
	--     float g_opacity[];
	--     vec3 g_sh[];
    
    -- Buffers for demo data
    positions = lovr.graphics.newBuffer(
        {"vec3", layout = "std430"},
    {
        {0, 0, 0},
        {1, 0, 0},
        {0, 1, 0}, 
        {0, 0, 1},
    })
    rotations = lovr.graphics.newBuffer(
        { "vec4", layout = "std430" },
        {
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 },
        })
    scales = lovr.graphics.newBuffer(
        { "vec3", layout = "std430" },
        {
            { 0.03, 0.03, 0.03 },
            { 0.2, 0.03, 0.03 },
            { 0.03, 0.2, 0.03 },
            { 0.03, 0.03, 0.2 },
        })
    opacities = lovr.graphics.newBuffer(
        { "float", layout = "std430" },
        {
            1., .5, 1., .5 
        })
    colors = lovr.graphics.newBuffer(
        { "vec3", layout = "std430" },
        {
            { 1, 0, 1},
            { 1, 0, 0},
            { 0, 1, 0},
            { 0, 0, 1},
        })
    debug = lovr.graphics.newBuffer(
        { "float", layout = "std430" },
        128
    )
    n_points = 4
    -- Preparing the Quads used in the rendering
    quad = lovr.graphics.newMesh(
        {
            { 'VertexPosition', 'vec3' }        },
        {
            { -1, 1,  0}, -- upper left
            { 1,  1,  0}, -- upper right
            { -1, -1, 0}, -- lower left
            { 1,  -1, 0}, -- lower right
        }, 'gpu')

    -- 2 triangles
    local indices = { 1, 2, 3, 4, 3, 2 }
    -- Adding the indicies to the vertices
    local indexBuffer = lovr.graphics.newBuffer('index16', indices)
    quad:setIndexBuffer(indexBuffer)
end


function lovr.draw(pass)
    
    -- Controls blending, probably useful in the future
    pass:setBlendMode("alpha", "alphamultiply")
    -- Don't render back of triangles, which will always be hidden
    pass:setCullMode('back')
    
    -- Load Splatting shader and pass data
    pass:setShader(shader)
    pass:send("scale_modifier", 1.0)
    pass:send("Positions", positions)
    pass:send("Rotations", rotations)
    pass:send("Scales", scales)
    pass:send("Opacities", opacities)
    pass:send("Colors", colors)
    -- These should be generated based on window data, to be tested
    pass:send("hfovxy_focal", vec3(1.777, 1, 360))
    
    pass:send("render_mode", -3)
    
    -- Debug buffer to aide in GPU work
    pass:send("Debug", debug)
    
    -- Instance a quad for each gaussian
    pass:draw(quad, mat4(), n_points)

    -- Read from Debug buffer and print results
    local readback = debug:newReadback()
    readback:wait()
    if readback:isComplete() then
        print("DEBUG READBACK:")
        print(unpack(readback:getData()))
    end
    local x, y, z, angle, ax, ay, az = pass:getViewPose(1)
    print("camera position as values")
    print(x, y, z, angle, ax, ay, az)
    
    local matrix = pass:getViewPose(1, mat4())
    print("Camera position as matrix")
    print(matrix)
end