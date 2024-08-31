pprint = require("pprint")

-- https://stackoverflow.com/questions/1426954/split-string-in-lua
function mysplit(inputstr)
    local t = {}
    for str in string.gmatch(inputstr, "[^\r\n]+") do
        table.insert(t, str)
    end
    return t
end

function load_ply(filename)
    local full_text, file_size = lovr.filesystem.read("some_ascii.ply", 6435311)
    print("READ FILE, SIZE:", file_size)
    local split_text = mysplit(full_text)
    print("PARSED DATA INCLUDES AT LEAST ", #split_text-67, " POINTS")
    local n_elements = 559263
    local data_start_line_number = 67
    local positions = {}
    local colors = {}
    local opacities = {}
    local scales = {}
    local rotations = {}
    for n = data_start_line_number, 1000 + data_start_line_number do
        local l = {}
        for str in string.gmatch(split_text[n], "([^%s]+)") do
            --print(str)
            table.insert(l, tonumber(str))
        end
        table.insert(positions, {l[1], l[2], l[3]})
        table.insert(colors, {l[7], l[8], l[9]})
        table.insert(opacities, l[55])
        table.insert(scales, {l[56], l[57], l[58]})
        table.insert(rotations, {l[59], l[60], l[61], l[62]})
        if n % 25 == 0 then
            pprint(colors[n-data_start_line_number])
        end
    end 
    return positions, colors, opacities, rotations, scales
end


function lovr.load()
    local positions, colors, opacities, rotations, scales = load_ply("some_ascii.ply")
    
    print("Fully loaded datapoints: ", #positions)

    -- Load and comppile shaders
    shader = lovr.graphics.newShader("gsplat.vert", "gsplat.frag")

    -- Structure of the gaussian data
    --     vec3 g_pos[];
	--     vec4 g_rot[];
	--     vec3 g_scale[];
	--     float g_opacity[];
	--     vec3 g_sh[];
    
    -- Buffers from data

    positions_buffer = lovr.graphics.newBuffer(
        { "vec3", layout = "std430" },
        positions)
    rotations_buffer = lovr.graphics.newBuffer(
        { "vec4", layout = "std430" },
        rotations)
    scales_buffer = lovr.graphics.newBuffer(
        { "vec3", layout = "std430" },
        scales)
    opacities_buffer = lovr.graphics.newBuffer(
        { "float", layout = "std430" },
        opacities)
    colors_buffer = lovr.graphics.newBuffer(
        { "vec3", layout = "std430" },
        colors)
    --debug = lovr.graphics.newBuffer(
    --    { "float", layout = "std430" },
    --    128
    --)
    n_points = 1001
    -- Preparing the Quads used in the rendering
    quad = lovr.graphics.newMesh(
        {
            { 'VertexPosition', 'vec3' } },
        {
            { -1, 1,  0 }, -- upper left
            { 1,  1,  0 }, -- upper right
            { -1, -1, 0 }, -- lower left
            { 1,  -1, 0 }, -- lower right
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
    pass:send("Positions", positions_buffer)
    pass:send("Rotations", rotations_buffer)
    pass:send("Scales", scales_buffer)
    pass:send("Opacities", opacities_buffer)
    pass:send("Colors", colors_buffer)
    -- These should be generated based on window data, to be tested
    pass:send("hfovxy_focal", vec3(1.777, 1, 360))
    
    pass:send("render_mode", -3)
    
    -- Debug buffer to aide in GPU work
    --pass:send("Debug", debug)
    
    -- Instance a quad for each gaussian
    pass:draw(quad, mat4(), n_points)

    -- -- Read from Debug buffer and print results
    -- local readback = debug:newReadback()
    -- readback:wait()
    -- if readback:isComplete() then
    --     print("DEBUG READBACK:")
    --     print(unpack(readback:getData()))
    -- end
    -- local x, y, z, angle, ax, ay, az = pass:getViewPose(1)
    -- print("camera position as values")
    -- print(x, y, z, angle, ax, ay, az)
    
    -- local matrix = pass:getViewPose(1, mat4())
    -- print("Camera position as matrix")
    -- print(matrix)
end