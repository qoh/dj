gamestate = require "lib.hump.gamestate"

states = {
    menu = require "states.menu",
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
    do return end

    states.songselect:run(function(filename, song, data)
    	if arg[2] == "edit" or arg[3] == "edit" then
    		gamestate.switch(states.editor, filename, song, data)
    	else
        	gamestate.switch(states.game, song, data)
        end
    end)
end
