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
    gamestate.registerEvents()
    gamestate.switch(states.menu)
end
