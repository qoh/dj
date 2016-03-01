local gamestate = require "lib.hump.gamestate"
local config = require "lib.config"
local menu = require "states.menu"
local delaytest = require "states.delaytest"

function love.load()
  if love.filesystem.isFused() then
    local dir = love.filesystem.getSourceBaseDirectory()
    local success = love.filesystem.mount(dir, "")

    if not success then
      print("Failed to mount source base directory in fused mode")
    end
  end

  love.mouse.setCursor(love.mouse.newCursor("assets/cursor_pointer3D_shadow.png", 0, 0))

  if love.filesystem.isFile("assets/gamecontrollerdb.txt") then
    love.joystick.loadGamepadMappings("assets/gamecontrollerdb.txt")
    print("Loaded assets/gamecontrollerdb.txt mappings")
  end

  gamestate.registerEvents()

  -- config.delay = nil
  if config.delay == nil then
    gamestate.switch(delaytest, function(delay)
      config.delay = delay
      config()
      gamestate.switch(menu)
    end)
  else
    gamestate.switch(menu)
  end
end
