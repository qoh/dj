local util = require "lib.util"
local state = {}

function state:init()
    self.scoreFont = love.graphics.newFont("assets/fonts/Roboto-Black.ttf", 72)
    self.statsFont = love.graphics.newFont("assets/fonts/Roboto-Medium.ttf", 24)
    self.hintFont = love.graphics.newFont("assets/fonts/Roboto-Medium.ttf", 32)
end

function state:enter(previous, filename, song, stats)
    local image = song.statsImage or song.image
    self.image = image and love.graphics.newImage(util.filepath(filename) .. image)

    self.stats = stats
    self.flash = 1

    love.graphics.setBackgroundColor(60, 60, 60)
end

function state:leave()
    self.image = nil
end

function state:close()
    if self.flash < 0.5 then
        gamestate.switch(states.menu)
    end
end

function state:keypressed(key, unicode)
    if key == "return" then
        self:close()
    end
end

function state:gamepadpressed(joystick, button)
    if button == "a" then
        self:close()
    end
end

function state:update(dt)
    self.flash = math.max(0, self.flash - dt)
end

function state:draw()
    local width, height = love.graphics.getDimensions()

    if self.image then
        local w, h = self.image:getDimensions()
        local scale = math.max(width / w, height / h)

        w = w * scale
        h = h * scale

        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(self.image, width / 2 - w / 2, height / 2 - h / 2, 0, scale, scale)

        love.graphics.setColor(0, 0, 0, 120)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end

    love.graphics.setColor(255, 255, 255)
    love.graphics.setFont(self.scoreFont)
    love.graphics.printf(util.addSeparators(self.stats.score), 50, 50, width - 100)
    love.graphics.printf(math.floor((self.stats.hitCount / self.stats.noteCount) * 1000 + 0.5) / 10 .. "%", 50, 50, width - 100, "right")
    love.graphics.setFont(self.statsFont)
    love.graphics.printf(
        "Best combo: " .. self.stats.bestCombo .. "\n" ..
        "Combo drops: " .. self.stats.lostCombo .. "\n" ..
        "Notes hit: " .. self.stats.hitCount .. "\n" ..
        "Notes missed: " .. self.stats.missCount .. "\n" ..
        "Precision: " .. math.floor((1 - math.abs(self.stats.totalOffset / self.stats.hitCount) / 0.5) * 100 + 0.5) .. "%",
        50 + 50, 50 + 72 + 50, width - 200)

    if self.flash < 0.5 then
        love.graphics.setColor(255, 255, 255, 255 * (1 - self.flash / 0.5))
        love.graphics.setFont(self.hintFont)
        love.graphics.print("Press Enter or A to continue", 50, height - 50 - 32)
    end

    if self.flash > 0 then
        love.graphics.setColor(255, 255, 255, 255 * self.flash)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end
end

return state
