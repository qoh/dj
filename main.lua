io.stdout:setvbuf("no")

local gamestate = require "lib.hump.gamestate"
local config = require "lib.config"
local menu = require "states.menu"
local delaytest = require "states.delaytest"

function love.load()
  love.window.setTitle("Beats Me")

  assert(love.window.setMode(1280, 720, {
    fullscreen = config.fullscreen,
    vsync = config.vsync,
    msaa = config.msaa,
    resizable = true,
    minwidth = 192 + 192,
    minheight = 480,
    highdpi = true
  }))

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
