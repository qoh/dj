local util = require "lib.util"
local state = {}

function state:init()
    local scale = love.window.getPixelScale()

    self.headerFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", love.window.toPixels(36))
    self.itemFont = love.graphics.newFont("assets/fonts/Montserrat-Regular.ttf", love.window.toPixels(24))

    self.sounds = {
        click = love.audio.newSource("assets/sounds/ui/click3.wav"),
        rollover = love.audio.newSource("assets/sounds/ui/rollover2.wav"),
    }

    self.prompts = {
        keyboard = {
            back = love.graphics.newImage("assets/prompts/Keyboard & Mouse/Keyboard_White_Esc.png"),
            apply = love.graphics.newImage("assets/prompts/Keyboard & Mouse/Keyboard_White_Enter_Alt.png"),
            alternate = love.graphics.newImage("assets/prompts/Keyboard & Mouse/Keyboard_White_Tab.png")
        },
        xbox360 = {
            back = love.graphics.newImage("assets/prompts/Xbox 360/360_B.png"),
            apply = love.graphics.newImage("assets/prompts/Xbox 360/360_A.png"),
            alternate = love.graphics.newImage("assets/prompts/Xbox 360/360_Y.png")
        }
    }

    self.vignette = love.graphics.newImage("assets/vignette.png")

    local mods = {speed = 1}

    -- self.items = {
    --     {"Play", function()
    --         states.songselect:run(function(filename, song, data)
    --         	gamestate.switch(states.game, filename, song, data, mods)
    --         end)
    --     end},
    --     {"Edit a track", function()
    --         states.songselect:run(function(filename, song, data)
    --         	gamestate.switch(states.editor, filename, song, data, mods)
    --         end)
    --     end},
    --     {"Help & controls", function() gamestate.switch(states.help) end},
    --     {"Settings", function() gamestate.switch(states.settings) end},
    --     {"Exit", love.event.quit}
    -- }

    self.screenProps = {
        exit = {
            {
                text = "Back",
                prompt = "back",
                activate = function() self:setScreen("main") end,
                pos = function(w, h) return w / 14, h / 6 * 5 end
            },
            {
                text = "Exit to desktop",
                prompt = "apply",
                activate = love.event.quit,
                pos = function(w, h) return w / 14 * 13 - 300, h / 6 * 5 end
            }
        },
        main = {
            title = "Placeholder",
            {
                text = "Exit",
                prompt = "back",
                activate = function() self:setScreen("exit") end,
                pos = function(w, h) return w / 14, h / 6 * 5 end
            },
            {
                text = "Play a song",
                keyfocus = true,
                activate = function()
                    states.songselect:run(function(filename, song, data)
                    	gamestate.switch(states.game, filename, song, data, mods)
                    end)
                end,
                pos = function(w, h) return w / 14, h / 2 end
            },
            {
                text = "Open editor",
                keyfocus = true,
                activate = function()
                    states.songselect:run(function(filename, song, data)
                    	gamestate.switch(states.editor, filename, song, data, mods)
                    end)
                end,
                pos = function(w, h) return w / 14, h / 2 + 40 end
            },
            {
                text = "Help & controls",
                keyfocus = true,
                activate = function() self:setScreen("help") end,
                pos = function(w, h) return w / 14, h / 2 + 80 end
            },
            {
                text = "Settings",
                keyfocus = true,
                activate = function() self:setScreen("settings") end,
                pos = function(w, h) return w / 14, h / 2 + 120 end
            },
        },
        help = {
            title = "Help & controls",
            {
                text = "Back",
                prompt = "back",
                activate = function() self:setScreen("main", 4) end,
                pos = function(w, h) return w / 14, h / 6 * 5 end
            },
        },
        settings = {
            title = "Settings",
            {
                text = "Back",
                prompt = "back",
                activate = function() self:setScreen("main", 5) end,
                pos = function(w, h) return w / 14, h / 6 * 5 end
            },
            {
                text = "Apply changes",
                prompt = "apply",
                activate = function() end,
                pos = function(w, h) return w / 14 * 13 - 300, h / 6 * 5 end
            }
        }
    }
end

function state:enter()
    self.worms = {}
    self.waste = {}
    --
    -- self.selection = 1
    -- self:setControlScheme("mouse")

    self.controlScheme = "mouse"
    self.focused = nil
    self.screen = self.screenProps.main

    love.keyboard.setKeyRepeat(true)
    love.graphics.setBackgroundColor(75, 75, 75)
end

function state:setScreen(name, focus)
    self.screen = self.screenProps[name]
    self.focused = nil

    if self.controlScheme ~= "mouse" then
        if focus then
            self:setFocus(focus, true)
        else
            self:next(true)
        end
    end
end

function state:setControlScheme(scheme)
    if scheme ~= self.controlScheme and (scheme == "mouse" or self.controlScheme == "mouse") then
        self.focused = nil
    end

    love.mouse.setVisible(scheme == "mouse")
    self.controlScheme = scheme
end

function state:leave()
    love.keyboard.setKeyRepeat(false)
    -- self.worms = nil
    -- self.waste = nil
end

-- function state:select(index)
--     if index and self.selection ~= index then
--         self.sounds.rollover:clone():play()
--     end
--
--     self.selection = index
-- end
--
-- function state:next()
--     if self.selection == nil or self.selection == #self.items then
--         self:select(1)
--     else
--         self:select(self.selection + 1)
--     end
-- end
--
-- function state:prev()
--     if self.selection == nil or self.selection == 1 then
--         self:select(#self.items)
--     else
--         self:select(self.selection - 1)
--     end
-- end
--
-- function state:activate()
--     if self.selection then
--         self.sounds.click:play()
--         self.items[self.selection][2]()
--     end
-- end

function state:activate(prompt)
    if self.controlScheme ~= "mouse" then
        for i, control in ipairs(self.screen) do
            if control.prompt == prompt then
                self.sounds.click:clone():play()

                if control.activate then
                    control.activate()
                end

                return
            end
        end
    end

    if (self.controlScheme == "mouse" or prompt == "apply") and self.focused then
        self.sounds.click:clone():play()
        local control = self.screen[self.focused]

        if control.activate then
            control.activate()
        end
    end
end

function state:next(quiet)
    for i=(self.focused or 0) + 1, #self.screen do
        if self.screen[i].keyfocus then
            self:setFocus(i, quiet)
            return
        end
    end
end

function state:prev(quiet)
    for i=(self.focused or #self.screen + 1) - 1, 1, -1 do
        if self.screen[i].keyfocus then
            self:setFocus(i, quiet)
            return
        end
    end
end

function state:gamepadpressed(joystick, key)
    self:setControlScheme("xbox360")

    if key == "a" then
        self:activate("apply")
    elseif key == "b" then
        self:activate("back")
    elseif key == "y" then
        self:activate("alternate")
    elseif key == "dpdown" then
        self:next()
    elseif key == "dpup" then
        self:prev()
    end
end

function state:keypressed(key, isrepeat)
    self:setControlScheme("keyboard")

    if key == "return" then
        self:activate("apply")
    elseif key == "escape" then
        self:activate("back")
    elseif key == "tab" then
        self:activate("alternate")
    elseif key == "down" then
        self:next()
    elseif key == "up" then
        self:prev()
    end
end

-- function state:touchpressed(id, x, y, pressure)
--     if y < 1 / 3 then
--         self:prev()
--     elseif y > 2 / 3 then
--         self:next()
--     else
--         self:activate()
--     end
-- end

function state:setFocus(index, quiet)
    if not quiet and index and self.focused ~= index then
        self.sounds.rollover:clone():play()
    end

    self.focused = index
end

function state:findMouseFocus(x, y)
    local width, height = love.window.fromPixels(love.graphics.getDimensions())

    for index, control in ipairs(self.screen) do
        local x1, y1 = control.pos(width, height)
        local x2 = x1 + 300
        local y2 = y1 + 40

        if x >= x1 and y >= y1 and x < x2 and y < y2 then
            return index
        end
    end
end

-- function state:selectFromMouse(x, y)
--     x = x - love.window.fromPixels(love.graphics.getWidth() / 2)
--     y = y - love.window.fromPixels(love.graphics.getHeight() / 2)
--
--     if x < -200 or x > 200 or y < -60 then
--         self:select(nil)
--         return
--     end
--
--     local f = (y + 60) / 36 + 1
--     local i = math.floor(f)
--
--     if i < 1 or i > #self.items or f - i > 32 / 36 then
--         self:select(nil)
--         return
--     end
--
--     self:select(i)
-- end

function state:mousepressed(x, y, button)
    self:setControlScheme("mouse")
    self:setFocus(self:findMouseFocus(love.window.fromPixels(x, y)))
end

function state:mousereleased(x, y, button)
    self:setControlScheme("mouse")
    self:setFocus(self:findMouseFocus(love.window.fromPixels(x, y)))

    if button == "l" then
        self:activate()
    end
end

function state:mousemoved(x, y, dx, dy)
    self:setControlScheme("mouse")
    self:setFocus(self:findMouseFocus(love.window.fromPixels(x, y)))
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
    -- local round = math.pi / 4
    -- theta = math.floor(theta / round + 0.5) * round
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

    local h = (math.sin(math.sin(love.timer.getTime() * 0.04) * math.pi) + 1) / 2
    local s = 0.3
    local v = 0.2 + (math.sin(love.timer.getTime() * 0.1) + 1) / 2 * 0.1

    love.graphics.setBackgroundColor(util.hsvToRgb(h, s, v))
end

function state:draw()
    local time = love.timer.getTime()
    local strength = 1 - (time - math.floor(time))
    strength = strength ^ 3

    love.graphics.setLineWidth(love.window.toPixels(2 + 2 * strength))

    for i, entry in ipairs(self.waste) do
        love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], entry.life * 255)
        love.graphics.line(entry.path)
    end

    for i, entry in ipairs(self.worms) do
        love.graphics.setColor(entry.color)
        love.graphics.line(entry.path)
    end

    love.graphics.setColor(255, 255, 255)
    util.imageFill(self.vignette)

    local width, height = love.window.fromPixels(love.graphics.getDimensions())
    local prompts = self.prompts[self.controlScheme] or {}

    if self.screen.title then
        love.graphics.setFont(self.headerFont)

        for i=2, 0, -1 do
            local value = (1 - i / 2) * 255
            love.graphics.setColor(value, value, value)
            love.graphics.print(self.screen.title, love.window.toPixels(width / 14), love.window.toPixels(height / 5 + 2 * i))
        end
    end

    love.graphics.setFont(self.itemFont)

    for index, control in ipairs(self.screen) do
        local x, y = control.pos(width, height)

        if self.focused == index then
            love.graphics.setColor(255, 255, 255, 50)
            love.graphics.rectangle("fill", x, y, 300, 40)
        end

        if prompts[control.prompt] then
            local size = 32
            local scale = love.window.toPixels(40) / 100

            love.graphics.setColor(255, 255, 255)
            love.graphics.draw(prompts[control.prompt],
                love.window.toPixels(x - 40),
                love.window.toPixels(y),
                0, scale, scale)
        end

        love.graphics.setColor(10, 10, 10)
        love.graphics.print(control.text, love.window.toPixels(x + 7, y + 7))
        love.graphics.setColor(245, 245, 245)
        love.graphics.print(control.text, love.window.toPixels(x + 6, y + 6))
    end
end

return state
