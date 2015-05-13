gamestate = require "lib.hump.gamestate"

states = {
    delaytest = require "states.delaytest",
    songselect = require "states.songselect",
    game = require "states.game",
    editor = require "states.editor"
}

function love.load()
    gamestate.registerEvents()

    states.songselect:run(function(filename, song, data)
        gamestate.switch(states.game, filename, song, data)
        --gamestate.switch(states.editor, filename, song, data)
    end)
end
