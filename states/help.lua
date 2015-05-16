local state = {}

function state:init()
    self.headerFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", love.window.toPixels(36))
    self.itemFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", love.window.toPixels(24))
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
    local width, height = love.window.fromPixels(love.graphics.getDimensions())

    love.graphics.setColor(200, 200, 200)
    love.graphics.setFont(self.headerFont)
    love.graphics.printf("Help & controls", love.window.toPixels(width / 2 - 400), love.window.toPixels(50), love.window.toPixels(800), "center")

    love.graphics.setFont(self.itemFont)
    love.graphics.setColor(200, 200, 200)
    love.graphics.printf(
        "Hit notes with Numpad 1/2/3 on a keyboard or X/A/B on a gamepad as they come down and reach the bottom of the playing field.\n" ..
        "\n" ..
        "On a gamepad, push the left stick towards the left or right in order to crossfade the track left or right, respectively.\n" ..
        "On a keyboard, hold Z to crossfade left or hold X to crossfade right (holding both is the same as holding neither).\n" ..
        "\n" ..
        "On a gamepad, you can press Y to hit the left and right lane simultaneously.\n" ..
        "\n\n\n" ..
        "Press Escape or B here and in the Settings to go back to the menu.",
        love.window.toPixels(width / 2 - 450), love.window.toPixels(150), love.window.toPixels(900), "left")
end

return state
