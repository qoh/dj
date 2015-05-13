local util = require "lib.util"
local state = {}

function state:enter(previous, stats)
    self.stats = stats
    self.flash = 1

    love.graphics.setBackgroundColor(60, 60, 60)
end

function state:keypressed(key, unicode)
    if key == "return" or key == "escape" then
        gamestate.switch(states.menu)
    end
end

function state:gamepadpressed(key, unicode)
    if key == "a" or key == "b" or key == "start" then
        gamestate.switch(states.menu)
    end
end

function state:update(dt)
    self.flash = math.max(0, self.flash - dt)
end

function state:draw()
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf(
        "Final score: " .. self.stats.score .. "\n" ..
        "Best combo: " .. self.stats.bestCombo .. "\n" ..
        "Combo drops: " .. self.stats.lostCombo .. "\n" ..
        "Notes hit: " .. self.stats.hitCount .. "\n" ..
        "Notes missed: " .. self.stats.missCount .. "\n" ..
        "Completion: " .. math.floor((self.stats.hitCount / self.stats.noteCount) * 100 + 0.5) .. "%\n" ..
        "Precision: " .. math.floor((1 - self.stats.totalOffset / (self.stats.noteCount * 0.5)) * 100 + 0.5) .. "%\n" ..
        "Average offset: " .. util.addSeparators(math.floor((self.stats.totalOffset / self.stats.hitCount) * 1000000)) .. " µs",
        32, 32, love.graphics.getWidth() - 64)

    if self.flash > 0 then
        love.graphics.setColor(255, 255, 255, 255 * self.flash)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    end
end

return state
