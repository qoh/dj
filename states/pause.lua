local state = {}

function state:init()
end

function state:enter(previous)
    self.previous = previous
    self.closing = false
    self.visibility = 0
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

function state:keypressed(key, unicode)
    if key == "escape" then
        self.closing = true
    end
end

function state:draw()
    self.previous:draw()

    local width, height = love.graphics.getDimensions()

    love.graphics.setColor(0, 0, 0, self.visibility * 127)
    love.graphics.rectangle("fill", 0, 0, width, height)

    love.graphics.push()
    love.graphics.translate(width / 2, height / 2)
    love.graphics.scale(self.visibility)

    love.graphics.setColor(200, 200, 200)
    love.graphics.rectangle("fill", -300, -200, 600, 400)
    love.graphics.setColor(20, 20, 20)
    love.graphics.printf("PAUSED", -200, -100, 400, "center")

    love.graphics.pop()
end

return state
