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
    	if arg[2] == "edit" or arg[3] == "edit" then
    		gamestate.switch(states.editor, filename, song, data)
    	else
        	gamestate.switch(states.game, filename, song, data, 0)
        end
    end)
end
