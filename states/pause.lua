local gamestate = require "lib.hump.gamestate"
local state = {}

function state:init()
    self.headerFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", love.window.toPixels(36))
    self.itemFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", love.window.toPixels(24))

    self.items = {
        {"Resume", function() self.closing = true end},
        {"Restart song", function()
            gamestate.switch(states.game, self.previous.filename, self.previous.song, self.previous.audioData)
        end},
        {"Play another song", function()
            states.songselect:run(function(filename, song, data)
            	gamestate.switch(states.game, filename, song, data, mods)
            end)
        end},
        {"Back to menu", function() gamestate.switch(states.menu) end},
        {"Exit game", love.event.quit}
    }
end

function state:enter(previous)
    self.previous = previous
    self.closing = false
    self.selection = 1
    self.visibility = 0

    love.keyboard.setKeyRepeat(true)
end

function state:leave()
    love.keyboard.setKeyRepeat(false)
end

function state:update(dt)
    if self.closing then
        self.visibility = math.min(1, self.visibility - dt * 6)

        if self.visibility < 0 then
            gamestate.pop()
            return
        end
    else
        self.visibility = math.min(1, self.visibility + dt * 6)
    end
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
    if key == "start" then
        self.closing = true
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
        self.closing = true
    elseif key == "return" then
        self:activate()
    elseif key == "down" then
        self:next()
    elseif key == "up" then
        self:prev()
    end
end

function state:selectFromMouse(x, y)
    x = x - love.window.fromPixels(love.graphics.getWidth() / 2)
    y = y - love.window.fromPixels(love.graphics.getHeight() / 2)

    if x < -200 * self.visibility or x > 200 * self.visibility or y < -60 * self.visibility then
        return false
    end

    local f = (y + 60 * self.visibility) / (36 * self.visibility) + 1
    local i = math.floor(f)

    if i < 1 or i > #self.items or f - i > 32 / 36 then
        return false
    end

    self.selection = math.floor(i)
    return true
end

function state:mousemoved(x, y, dx, dy)
    self:selectFromMouse(love.window.fromPixels(x, y))
end

function state:mousepressed(x, y, button)
    x, y = love.window.fromPixels(x, y)

    if button == "l" then
        local i = x - love.window.fromPixels(love.graphics.getWidth() / 2)
        local j = y - love.window.fromPixels(love.graphics.getHeight() / 2)
        
        if math.abs(i) > 300 * self.visibility and math.abs(y) > 200 * self.visibility then
            self.closing = true
        elseif self:selectFromMouse(x, y) then
            self:activate()
        end
    end
end

function state:draw()
    self.previous:draw()

    local width, height = love.window.fromPixels(love.graphics.getDimensions())

    love.graphics.setColor(0, 0, 0, self.visibility * 127)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.push()
    love.graphics.translate(love.window.toPixels(width / 2, height / 2))
    love.graphics.scale(self.visibility)

    love.graphics.setColor(200, 200, 200)
    love.graphics.rectangle("fill", -300, -200, 600, 400)

    love.graphics.setColor(50, 50, 50)
    love.graphics.setFont(self.headerFont)
    love.graphics.printf("PAUSED", love.window.toPixels(-200), love.window.toPixels(-150), love.window.toPixels(400), "center")

    love.graphics.setFont(self.itemFont)
    love.graphics.setColor(90, 90, 90)
    love.graphics.rectangle("fill", love.window.toPixels(-200), love.window.toPixels(-60 + (self.selection - 1) * 36), love.window.toPixels(400, 32))

    for i, item in ipairs(self.items) do
        if i == self.selection then
            love.graphics.setColor(240, 240, 240)
        else
            love.graphics.setColor(110, 110, 110)
        end

        love.graphics.print(item[1], love.window.toPixels(-200 + 4, -60 + (i - 1) * 36 + 2))
    end

    love.graphics.pop()
end

return state
