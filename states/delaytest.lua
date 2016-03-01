local state = {}

local util = require 'lib.util'

function state:init()
  self.music = love.audio.newSource("assets/delaytest.ogg")
  self.bpm = 128

  self.font1 = love.graphics.newFont(20)
  self.font2 = love.graphics.newFont(24)
end

function state:enter(_, callback)
  love.graphics.setBackgroundColor(255, 255, 255)

  self.delay = 0
  self.callback = callback

  self.offsets = {}
  self.maxOffsets = 30 -- use a maximum number of offset taps to give the player's timing a chance to improve over time

  self.music:play()
end

function state:leave()
  self.music:stop()
end

function state:continue()
  self.callback(self.delay)
end

function state:hit()
  local tapTime = self.music:tell()
  local nearestBeatTime = util.round(tapTime, 60 / self.bpm)
  local offset = tapTime - nearestBeatTime

  table.insert(self.offsets, offset)
  if #self.offsets > self.maxOffsets then
    table.remove(self.offsets, 1)
  end

  local total = 0
  for i, offset in ipairs(self.offsets) do
    total = total + offset
  end
  self.delay = total / #self.offsets
end

function state:keypressed(key)
  if #self.offsets > 0 and key == "return" then
    self:continue()
  else
    self:hit()
  end
end

function state:gamepadpressed(_, button)
  if #self.offsets > 0 and button == "start" then
    self:continue()
  else
    self:hit()
  end
end

function state:update(dt)
  if not self.music:isPlaying() then
    self.music:play()
  end
end

function state:draw()
  local width, height = love.graphics.getDimensions()
  local lineY1 = height / 2 - 128
  local lineY2 = height / 2 + 128
  local beat = self.music:tell() * (self.bpm / 60)

  love.graphics.push()
  love.graphics.translate(width / 2, 0)
      love.graphics.translate(-128 * (beat - math.floor(beat)), 0)
  love.graphics.setColor(0, 0, 0, 127)
  love.graphics.setLineWidth(1)

  local ticks = math.ceil(width / 128 / 2)

  for i=-ticks, ticks do
    local x = i * 128
    love.graphics.line(x, lineY1, x, lineY2)
  end

  love.graphics.pop()

      local beatPower = (1 - (beat - math.floor(beat))) ^ 8
  love.graphics.setColor(0, 0, 0)
  love.graphics.setLineWidth(2 + beatPower * 2)
  love.graphics.line(width / 2, lineY1 - 64 - beatPower * 8, width / 2, lineY2 + 64 + beatPower * 8)

  love.graphics.setFont(self.font1)
  love.graphics.printf(
    "Tap a button on your input device (keyboard or gamepad) along with the beat to calibrate the delay.",
    200, 150, width - 400, "center")

  if #self.offsets > 0 then
    love.graphics.printf(
      "Press Enter or Start to continue.",
      200, height - 50 - 20, width - 400, "center")
  end

  love.graphics.setFont(self.font2)
  love.graphics.printf(
    "Offset in milliseconds:\n" .. util.round(self.delay * 1000, 0.0001),
    200, height - 150 - 24, width - 400, "center"
  )
end

return state
