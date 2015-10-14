local ser = require "lib.ser"

local filename = "config.lua"

local config = {
  delay = nil,
  fullscreen = false,
  vsync = true,
  msaa = 8,
  ignoreGamepad = false,
  showInput = false
}

setmetatable(config, {
  __call = function(t)
    love.filesystem.write(filename, ser(t))
  end
})

if love.filesystem.isFile(filename) then
  local function patch(t, target)
    for key, value in pairs(t) do
      if type(value) == "table" and type(target[key]) == "table" then
        patch(value, target[key])
      else
        target[key] = value
      end
    end
  end

  local user = love.filesystem.load(filename)()
  patch(user, config)
end

return config
