local state = {}

function state:init()
    self.headerFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", 36)
    self.itemFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 24)
end

function state:enter()
    love.graphics.setBackgroundColor(48, 48, 48)
end

function state:gamepadpressed(joystick, key)
    if key == "b" then
        gamestate.switch(states.menu)
    end
end

function state:keypressed(key, unicode)
    if key == "escape" then
        gamestate.switch(states.menu)
    end
end

function state:draw()
    local width, height = love.graphics.getDimensions()

    love.graphics.setColor(200, 200, 200)
    love.graphics.setFont(self.headerFont)
    love.graphics.printf("Help & controls", width / 2 - 400, 50, 800, "center")

    love.graphics.setFont(self.itemFont)
    love.graphics.setColor(200, 200, 200)
    love.graphics.printf(
        "Hit notes with Numpad 1/2/3 on a keyboard or X/A/B on a gamepad as they come down and reach the bottom of the playing field.\n\n" ..
        "On a gamepad, push the left stick towards the left or right in order to crossfade the track left or right, respectively.\n\n" ..
        "On a keyboard, hold Z to crossfade left or hold X to crossfade right (holding both is the same as holding neither).\n\n" ..
        "\n\n" ..
        "Press Escape or B here and in the Settings to go back to the menu.",
        width / 2 - 450, 150, 900, "left")
end

return state
