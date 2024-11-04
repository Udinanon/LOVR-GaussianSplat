pprint = require("pprint")

---Split string on separator, here a newline
---@param inputstr string
---@return table
function mysplit(inputstr)
    -- https://stackoverflow.com/questions/1426954/split-string-in-lua
    local t = {}
    for str in string.gmatch(inputstr, "[^\r\n]+") do
        table.insert(t, str)
    end
    return t
end

---Sigmoid function = 1/(1 + np.exp(- opacities))
---@param value number
function sigmoid(value)
    return 1/(1 + math.exp(-value))
end

---Load PLY ASCII file from path and preprocess values to be loaded in shader
---@param filename string
---@return table
---@return table
---@return table
---@return table
---@return table
function load_ply(filename)
    -- real file contents
    local full_text, file_size = lovr.filesystem.read("some_ascii.ply")
    print("READ FILE, SIZE:", file_size)
    local split_text = mysplit(full_text)
    -- 67 is the number of non data lines, it's hardcoded
    print("PARSED DATA INCLUDES AT LEAST ", #split_text-67, " POINTS")
    
    local data_start_line_number = 67
    local positions = {}
    local colors = {}
    local opacities = {}
    local scales = {}
    local rotations = {}
    
    -- process each line
    for n = data_start_line_number, n_points - 1 + data_start_line_number do
        -- split line in single values
        local l = {}
        for str in string.gmatch(split_text[n], "([^%s]+)") do
            table.insert(l, tonumber(str))
        end
        -- values need to be preprocessed, like normalizing their rotations or rescaling opacities via the sigmoid 
        table.insert(positions, {l[1], -l[2], l[3]})
        table.insert(colors, {l[7], l[8], l[9]})
        table.insert(opacities, sigmoid(l[55]))
        table.insert(scales, { math.exp(l[56]), math.exp(l[57]), math.exp(l[58]) })
        local norm_factor = math.sqrt(l[59] * l[59] + l[60] * l[60] + l[61] * l[61] + l[62] * l[62])
        table.insert(rotations, { l[59] / norm_factor, l[60] / norm_factor, l[61] / norm_factor, l[62] / norm_factor })
    end 
    return positions, colors, opacities, rotations, scales
end

--- Ordering gaussians by depth
---@param indices_buffer lovr.Buffer
---@param positions table
function sort_gaussians(indices_buffer, positions)
    -- Compute distance for each 
    local view_matrix = pass_view_matrix
    local distances = {}
    for i, position in ipairs(positions) do
        local depth = view_matrix:mul(vec4(position[1], position[2], position[3], 1))
        table.insert(distances, { i, depth[3] })
    end
    -- sort based on the distance
    table.sort(distances, function(a, b)
        return a[2] < b[2]
    end)
    -- extract the indices
    local depth_index = {}
    for i, dist in ipairs(distances) do
        -- the -1 is due to the difference in dindexing between GLSL and Lua
        table.insert(depth_index, dist[1]-1) 
    end
    -- update the buffer
    indices_buffer:setData(depth_index)
end

function load_demo()
    positions = {
            { 0, 0, 0 },
            { 1, 0, 0 },
            { 0, 1, 0 },
            { 0, 0, 1 },
        }
    rotations = {
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 },
            { 1, 0, 0, 0 },
        }
    scales = {
            { 0.03, 0.03, 0.03 },
            { 0.2,  0.03, 0.03 },
            { 0.03, 0.2,  0.03 },
            { 0.03, 0.03, 0.2 },
        }
    opacities = {
            1., .5, 1., .5
        }
    colors = {
            { 1, 0, 1 },
            { 1, 0, 0 },
            { 0, 1, 0 },
            { 0, 0, 1 },
        }
    n_points = 4
    return positions, colors, opacities, rotations, scales
end

function lovr.load()

    lovr.graphics.setTimingEnabled(true)
    -- load data from disk
    n_points = 559263
    positions, colors, opacities, rotations, scales = load_ply("some_ascii.ply")
    ---load_demo()
    
    print("Fully loaded datapoints: ", #positions)
    local indices = {} 
    for i = 0, #positions do
        table.insert(indices, i)
    end
    -- Load and comppile shaders
    shader = lovr.graphics.newShader("gsplat.vert", "gsplat.frag")

    -- Structure of the gaussian data
    --     vec3 g_pos[];
    --     vec4 g_rot[];
    --     vec3 g_scale[];
    --     float g_opacity[];
    --     vec3 g_sh[];

    -- Buffers for the data

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
    indices_buffer = lovr.graphics.newBuffer(
        { "int", layout = "std430" },
        indices) 
    --debug = lovr.graphics.newBuffer(
    --    { "float", layout = "std430" },
    --    128
    --)

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
    -- select the current rendering mode
    render_mode_selector = 0
end


function lovr.keyreleased(key, scancode)
    -- update rendering sort, too slow to be done at each frame as of now
    if key=="u" then
        sort_gaussians(indices_buffer, positions)
    end
    -- move between rendering modes
    if key == "k" then
        render_mode_selector = render_mode_selector + 1
        print(render_mode_selector)
    end 
    if key == "j" then
        render_mode_selector = render_mode_selector - 1
        print(render_mode_selector)
    end
end

function lovr.update()
    -- update rendering sort, too slow to be done at each frame as of now
    if lovr.headset.wasPressed("hand/right", "a") then
        sort_gaussians(indices_buffer, positions)
    end
    -- move between rendering modes
    if lovr.headset.wasPressed("hand/left", "x") then
        render_mode_selector = render_mode_selector + 1
        print(render_mode_selector)
    end
    if lovr.headset.wasPressed("hand/left", "y") then
        render_mode_selector = render_mode_selector - 1
        print(render_mode_selector)
    end
end

function lovr.draw(pass)
    -- might help reduce performance costs
    pass:setViewCull(true)
    pass:setCullMode("none")

    -- Controls blending
    pass:setBlendMode("alpha", "alphamultiply")

    -- Load Splatting shader and pass data
    pass:setShader(shader)
    pass:send("scale_modifier", 1.0)
    pass:send("Positions", positions_buffer)
    pass:send("Rotations", rotations_buffer)
    pass:send("Scales", scales_buffer)
    pass:send("Opacities", opacities_buffer)
    pass:send("Colors", colors_buffer)
    pass:send("Indeces", indices_buffer)

    -- These should be generated based on window data, to be tested
    pass:send("hfovxy_focal", vec3(1.777, 1, 360))

    pass:send("render_mode", render_mode_selector)

    -- Debug buffer to aide in GPU work
    --pass:send("Debug", debug)

    -- Instance a quad for each gaussian
    pass:draw(quad, mat4(), n_points)

    -- -- Read from buffer and print results
    -- local readback = indices_buffer:newReadback()
    -- readback:wait()
    -- if readback:isComplete() then
    --     print("DEBUG READBACK:")
    --     print(readback:getData()
    -- end

    -- needed to sort the gaussians later
    pass_view_matrix = pass:getViewPose(1, lovr.math.newMat4(), true)

    local stats = pass:getStats()
    print(('Rendering takes %f milliseconds'):format(stats.gpuTime * 1e3))
    pprint.pprint(stats)
end