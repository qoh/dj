local gamestate = require "lib.hump.gamestate"
local state = {}

function state:init()
    self.canvas1 = love.graphics.newCanvas()
    self.canvas2 = love.graphics.newCanvas()
end

function state:enter(previous, target, length, ...)
    self.previous = previous
    self.previousColor = love.graphics.getBackgroundColor()
    self.target = target
    self.args = {...}
    self.length = length
    self.time = 0

    if target.init then
        target:init()
    end

    if target.enter then
        target:enter(previous, ...)
    end
end

function state:leave()
    self.args = nil -- Possible memory save
end

function state:update(dt)
    self.time = self.time + dt

    if self.time >= self.length then
        self.previous:leave(self.target)
        gamestate.cut(self.target)
    end
end

function state:draw()
    self.canvas1:clear(previousColor)
    self.canvas2:clear(love.graphics.getBackgroundColor())

    love.graphics.setCanvas(self.canvas1)
    self.previous:draw()
    love.graphics.setCanvas(self.canvas2)
    self.target:draw()
    love.graphics.setCanvas()

    love.graphics.setColor(255, 255, 255, 255 * (1 - self.time / self.length))
    love.graphics.draw(self.canvas1)
    love.graphics.setColor(255, 255, 255, 255 * (self.time / self.length))
    love.graphics.draw(self.canvas2)
end

return state
