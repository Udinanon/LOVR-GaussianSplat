function lovr.load()
    shader = lovr.graphics.newShader("gsplat.vert", "gsplat.frag")
    --vec3 g_pos[];
	-- vec4 g_rot[];
	-- vec3 g_scale[];
	-- float g_opacity[];
	-- vec3 g_sh[];
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
            { 1, 1, 1, .5 },
        })
    colors = lovr.graphics.newBuffer(
        { "vec4", layout = "std430" },
        {
            { 1, 0, 1, 1 },
            { 1, 0, 0, 1 },
            { 0, 1, 0, 1 },
            { 0, 0, 1, 1 },
        })
    debug = lovr.graphics.newBuffer(
        { "float", layout = "std430" },
        128
    )
    n_points = 4
    quad = lovr.graphics.newMesh(
        {
            { 'VertexPosition', 'vec3' },
            { 'VertexColor',    'vec4' }
        },
        {
            { -1, 1,  0, 1, 0, 0, 1 }, -- upper left
            { 1,  1,  0, 0, 1, 0, 1 }, -- upper right
            { -1, -1, 0, 0, 0, 1, 1 }, -- lower left
            { 1,  -1, 0, 1, 1, 1, 1 }, -- lower right
        }, 'gpu')

    -- 2 triangles
    local indices = { 1, 2, 3, 4, 3, 2 }

    local indexBuffer = lovr.graphics.newBuffer('index16', indices)
    quad:setIndexBuffer(indexBuffer)
end


function lovr.draw(pass)
    pass:setBlendMode()
    pass:setCullMode('back')
    local view_pose = mat4() 
    pass:getViewPose(1, view_pose)
    print("View Matrix: ")
    print(view_pose)
    -- Undefined by default
    -- local x, y, w, h = pass:getScissor()
    -- print("View Scissor: ")
    -- print(x, y, w, h)
    -- local x, y, w, h, dmin, dmax = pass:getViewport()
    -- print("View Port: ")
    -- print(x, y, w, h, dmin, dmax)
    local width, height = pass:getDimensions()
    print("Dimensions")
    print(width, height)
    local left, right, up, down = pass:getProjection(1)
    print("View Projection: " )
    print( left, right, up, down)

    local htany = math.tan(up)
    local htanx = (htany / height) * width
    local focal = height / (2 * htany)
    print("Computed HFOV: ")
    print(htanx, htany, focal)
    --pass:mesh(triangle_vertices)
    pass:setShader(shader)
    pass:send("scale_modifier", 1.0)
    pass:send("Positions", positions)
    pass:send("Rotations", rotations)
    pass:send("Scales", scales)
    pass:send("Opacities", opacities)
    pass:send("Colors", colors)
    pass:send("hfovxy_focal", vec3(1.777, 1, 360))
    --pass:send("hfovxy_focal", vec3(htanx, htany, focal))
    --pass:mesh(n_points)
    --pass:setCullMode('back')
    --pass:setBlendMode()
    --pass:setShader(quick_shader)
    --pass:send('Transforms', transformBuffer)
    pass:send("Debug", debug)
    pass:draw(quad, mat4(), n_points)
    --pass:draw(mesh, mat4(), MONKEYS)
    local readback = debug:newReadback()
    readback:wait()
    if readback:isComplete() then
        print(unpack(readback: getData()))
    end
end