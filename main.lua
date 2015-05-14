-- if love.filesystem.isFused() then
if true then
    local dir = love.filesystem.getSourceBaseDirectory()
    local success = love.filesystem.mount(dir, "")
end

gamestate = require "lib.hump.gamestate"

states = {
    menu = require "states.menu",
    settings = require "states.settings",
    help = require "states.help",
    delaytest = require "states.delaytest",
    songselect = require "states.songselect",
    pause = require "states.pause",
    game = require "states.game",
    win = require "states.win",
    editor = require "states.editor"
}

function love.load()
    love.joystick.loadGamepadMappings("assets/gamecontrollerdb.txt")

    gamestate.registerEvents()
    gamestate.switch(states.menu)
    -- gamestate.switch(states.win, {
    --         score = 1234567,
    --         totalOffset = 123.456,
    --         noteCount = 123,
    --         hitCount = 120,
    --         missCount = 3,
    --         bestCombo = 130,
    --         lostCombo = 5
    --     })
end
