local state = {}

function state:init()
    local scale = love.window.getPixelScale()

    self.headerFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", 36 * scale)
    self.itemFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 24 * scale)

    local mods = {speed = 1}

    self.items = {
        {"Play", function()
            states.songselect:run(function(filename, song, data)
            	gamestate.switch(states.game, filename, song, data, mods)
            end)
        end},
        {"Edit a track", function()
            states.songselect:run(function(filename, song, data)
            	gamestate.switch(states.editor, filename, song, data, mods)
            end)
        end},
        {"Help & controls", function() gamestate.switch(states.help) end},
        {"Settings", function() gamestate.switch(states.settings) end},
        {"Exit", love.event.quit}
    }
end

function state:enter()
    self.worms = {}
    self.waste = {}

    self.selection = 1

    love.keyboard.setKeyRepeat(true)
    love.graphics.setBackgroundColor(48, 48, 48)
end

function state:leave()
    love.keyboard.setKeyRepeat(false)
    self.worms = nil
    self.waste = nil
end

function state:next()
    if self.selection == #self.items then
        self.selection = 1
    else
        self.selection = self.selection + 1
    end
end

function state:prev()
    if self.selection == 1 then
        self.selection = #self.items
    else
        self.selection = self.selection - 1
    end
end

function state:activate()
    self.items[self.selection][2]()
end

function state:gamepadpressed(joystick, key)
    if key == "a" then
        self:activate()
    elseif key == "dpdown" then
        self:next()
    elseif key == "dpup" then
        self:prev()
    end
end

function state:keypressed(key, unicode)
    if key == "return" then
        self:activate()
    elseif key == "down" then
        self:next()
    elseif key == "up" then
        self:prev()
    end
end

function state:touchpressed(id, x, y, pressure)
    if y < 1 / 3 then
        self:prev()
    elseif y > 2 / 3 then
        self:next()
    else
        self:activate()
    end
end

local function round_worm_dir(dx, dy)
    local length = math.sqrt(dx^2 + dy^2)
    local theta = math.atan2(dy / length, dx / length)

    -- Rotate 45 degrees
    -- theta = theta + (math.pi * 8)
    --
    -- if theta < -math.pi then
    --     theta = theta + math.pi * 2
    -- elseif theta > math.pi then
    --     theta = theta - math.pi * 2
    -- end

    -- Round to nearest 90 degrees
    local round = math.pi / 4
    theta = math.floor(theta / round + 0.5) * round
    return math.cos(theta), math.sin(theta)
end

function state:update(dt)
    local w, h = love.graphics.getDimensions()
    local scale = love.window.getPixelScale()

    local colors = {
        {127, 255,  50},
        {255,  50,  50},
        {  0, 127, 255},
    }

    if #self.worms == 0 or (#self.worms < 15 and love.math.random() < 0.02) then
        local x, y

        if love.math.random() < 0.5 then
            y = math.floor(love.math.random() * (h + 8)) - 4

            if love.math.random() < 0.5 then
                x = -4
            else
                x = w + 3
            end
        else
            x = math.floor(love.math.random() * (w + 8)) - 4

            if love.math.random() < 0.5 then
                y = -4
            else
                y = h + 3
            end
        end

        table.insert(self.worms, {
            tag = love.timer.getTime(),
            color = colors[love.math.random(1, #colors)],
            path = {x, y, x, y},
            dx = 0,
            dy = 0
        })
    end

    local i = 1

    while i <= #self.worms do
        local worm = self.worms[i]

        local x = worm.path[#worm.path - 1]
        local y = worm.path[#worm.path]

        if x < -5 or y < -5 or x >= w + 5 or y >= h + 5 then
            table.insert(self.waste, {path = worm.path, color = worm.color, life = 1})
            table.remove(self.worms, i)
        else
            local dx, dy = round_worm_dir(
                love.math.noise(love.timer.getTime() / 3, 0, worm.tag) * 2 - 1,
                love.math.noise(0, love.timer.getTime() / 3, worm.tag) * 2 - 1)

            if dx ~= worm.dx or dy ~= worm.dy then
                if worm.path[#worm.path - 1] ~= worm.path[#worm.path - 3] or worm.path[#worm.path] ~= worm.path[#worm.path - 2] then
                    table.insert(worm.path, x)
                    table.insert(worm.path, y)
                end

                worm.dx = dx
                worm.dy = dy
            end

            x = x + dx * dt * 100 * scale
            y = y + dy * dt * 100 * scale

            worm.path[#worm.path - 1] = x
            worm.path[#worm.path    ] = y

            i = i + 1
        end
    end

    i = 1

    while i <= #self.waste do
        local life = self.waste[i].life - dt / 4

        if life <= 0 then
            table.remove(self.waste, i)
        else
            self.waste[i].life = life
            i = i + 1
        end
    end
end

function state:draw()
    local width, height = love.graphics.getDimensions()
    local scale = love.window.getPixelScale()
    width = width / scale
    height = height / scale

    local time = love.timer.getTime()
    local strength = 1 - (time - math.floor(time))
    strength = strength ^ 3

    love.graphics.setLineWidth((2 + 2 * strength) * scale)

    for i, entry in ipairs(self.waste) do
        love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], entry.life * 255)
        love.graphics.line(entry.path)
    end

    for i, entry in ipairs(self.worms) do
        love.graphics.setColor(entry.color)
        love.graphics.line(entry.path)
    end

    love.graphics.push()
    love.graphics.translate(width / 2 * scale, height / 2 * scale)

    love.graphics.setColor(200, 200, 200)
    love.graphics.setFont(self.headerFont)
    love.graphics.printf(love.window.getTitle(), -200 * scale, -150 * scale, 400 * scale, "center")

    love.graphics.setFont(self.itemFont)
    love.graphics.setColor(200, 200, 200)
    love.graphics.rectangle("fill", -200 * scale, (-60 + (self.selection - 1) * 36) * scale, 400 * scale, 32 * scale)

    for i, item in ipairs(self.items) do
        if i == self.selection then
            love.graphics.setColor(50, 50, 50)
        else
            love.graphics.setColor(200, 200, 200)
        end

        love.graphics.print(item[1], (-200 + 4) * scale, (-60 + (i - 1) * 36 + 2) * scale)
    end

    love.graphics.pop()
end

return state
