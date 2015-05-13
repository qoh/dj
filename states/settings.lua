local state = {}

function state:init()
    self.headerFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", 36)
    self.itemFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 26)

    self.items = {
        {
            "Use keyboard input even when a gamepad is detected",
            "ignoreGamepad"
        },
        {
            "Show an overlay with which buttons are pressed in-game",
            "showInput"
        }
    }
end

function state:enter()
    self.selection = 1

    love.keyboard.setKeyRepeat(true)
    love.graphics.setBackgroundColor(48, 48, 48)
end

function state:leave()
    love.keyboard.setKeyRepeat(false)
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
    local setting = self.items[self.selection][2]
    settings[setting] = not settings[setting]

    love.filesystem.write("settings.lua", require("lib.ser")(settings))
end

function state:gamepadpressed(joystick, key)
    if key == "b" then
        gamestate.switch(states.menu)
    elseif key == "a" then
        self:activate()
    elseif key == "dpdown" then
        self:next()
    elseif key == "dpup" then
        self:prev()
    end
end

function state:keypressed(key, unicode)
    if key == "escape" then
        gamestate.switch(states.menu)
    elseif key == "return" or key == " " then
        self:activate()
    elseif key == "down" then
        self:next()
    elseif key == "up" then
        self:prev()
    end
end

function state:update(dt)
end

function state:draw()
    local width, height = love.graphics.getDimensions()

    love.graphics.setColor(200, 200, 200)
    love.graphics.setFont(self.headerFont)
    love.graphics.printf("Settings", width / 2 - 400, 50, 800, "center")

    love.graphics.setFont(self.itemFont)
    love.graphics.setColor(200, 200, 200)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("fill", 200, 250 + (self.selection - 1) * (32 + 16 + 4), width - 400, (32 + 16))

    for i, item in ipairs(self.items) do
        if i == self.selection then
            love.graphics.setColor(50, 50, 50)
        else
            love.graphics.setColor(200, 200, 200)
        end

        if settings[self.items[i][2]] then
            love.graphics.print("×", 200 + 8 + 1, 250 + (i - 1) * (32 + 16 + 4) + 8)
        end

        love.graphics.rectangle("line", 200 + 8, 250 + (i - 1) * (32 + 16 + 4) + 8 + 7, 16, 16)
        love.graphics.print(item[1], 200 + 8 + 16 + 8 + 4, 250 + (i - 1) * (32 + 16 + 4) + 8 + 1)
    end
end

return state
