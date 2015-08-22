local gamestate = require "lib.hump.gamestate"
local state = {}

function state:init()
    self.font = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", love.window.toPixels(24))
end

function state:enter(previous, contents, callback)
    self.previous = previous
    self.contents = contents
    self.callback = callback

    self.closing = false
    self.confirmed = false
    self.visibility = 0
end

function state:leave()
end

function state:update(dt)
    if self.closing then
        self.visibility = math.min(1, self.visibility - dt * 6)

        if self.visibility < 0 then
            local confirmed = self.confirmed
            gamestate.pop()

            if confirmed then
                self.callback()
            end

            return
        end
    else
        self.visibility = math.min(1, self.visibility + dt * 6)
    end
end

function state:dismiss()
    self.closing = true
end

function state:confirm()
    if not self.closing then
        self.confirmed = true
    end

    self.closing = true
end

function state:gamepadpressed(joystick, key)
    if key == "a" then
        self:confirm()
    elseif key == "b" then
        self:dismiss()
    end
end

function state:keypressed(key, unicode)
    if key == "escape" then
        self:dismiss()
    elseif key == "return" then
        self:confirm()
    end
end

function state:mousepressed(x, y, button)
    x, y = love.window.fromPixels(x, y)

    if button == 1 then
        local i = x - love.window.fromPixels(love.graphics.getWidth() / 2)
        local j = y - love.window.fromPixels(love.graphics.getHeight() / 2)

        if math.abs(i) > 300 * self.visibility and math.abs(y) > 200 * self.visibility then
            self:dismiss()
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

    love.graphics.setFont(self.font)
    love.graphics.setColor(90, 90, 90)
    love.graphics.printf(self.contents .. "\n\nEnter to confirm, Escape to dismiss.", -200 + 4, -60, 400 - 8, "center")

    love.graphics.pop()
end

return state
