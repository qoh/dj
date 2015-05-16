if love.filesystem.isFused() then
    local dir = love.filesystem.getSourceBaseDirectory()
    local success = love.filesystem.mount(dir, "")

    if not success then
        print("Failed to mount source base directory in fused mode")
    end
end

gamestate = require "lib.hump.gamestate"

states = {
    menu = require "states.menu",
    settings = require "states.settings",
    help = require "states.help",
    delaytest = require "states.delaytest",
    songselect = require "states.songselect",
    loadsong = require "states.loadsong",
    pause = require "states.pause",
    game = require "states.game",
    win = require "states.win",
    editor = require "states.editor"
}

function love.load()
    if love.filesystem.isFile("assets/gamecontrollerdb.txt") then
        love.joystick.loadGamepadMappings("assets/gamecontrollerdb.txt")
        print("Loaded assets/gamecontrollerdb.txt mappings")
    end

    gamestate.registerEvents()
    gamestate.switch(states.menu)
end

-- function love.touchpressed(id,x,y,p)
--     gamestate.switch(states.settings)
-- end
