local state = {}

function state:init()
  self.sound = love.audio.newSource("assets/Laser_Shoot12.wav")

  self.font1 = love.graphics.newFont(20)
  self.font2 = love.graphics.newFont(24)
end

function state:enter(_, callback)
  love.graphics.setBackgroundColor(255, 255, 255)

  self.time = 0
  self.delay = 0
  self.callback = callback

  self.offsetTotal = 0
  self.offsetCount = 0
end

function state:continue()
  self.callback(self.delay)
end

function state:hit()
  local active = math.floor(self.time + 0.5)
  local offset = self.time - active

  self.offsetTotal = self.offsetTotal + offset
  self.offsetCount = self.offsetCount + 1

  self.delay = self.offsetTotal / self.offsetCount
end

function state:keypressed(key)
  if self.offsetCount > 0 and key == "return" then
    self:continue()
  else
    self:hit()
  end
end

function state:gamepadpressed(_, button)
  if self.offsetCount > 0 and button == "start" then
    self:continue()
  else
    self:hit()
  end
end

function state:update(dt)
  local prev = self.time
  self.time = self.time + dt

  if self.time - math.floor(self.time) < prev - math.floor(prev) then
    self.sound:play()
  end
end

function state:draw()
  local width, height = love.graphics.getDimensions()
  local lineY1 = height / 2 - 128
  local lineY2 = height / 2 + 128

  love.graphics.push()
  love.graphics.translate(width / 2, 0)
  love.graphics.translate(-128 * (self.time - math.floor(self.time)), 0)
  love.graphics.setColor(0, 0, 0, 127)
  love.graphics.setLineWidth(1)

  local ticks = math.ceil(width / 128 / 2)

  for i=-ticks, ticks do
    local x = i * 128
    love.graphics.line(x, lineY1, x, lineY2)
  end

  love.graphics.pop()

  local beatPower = (1 - (self.time - math.floor(self.time))) ^ 8
  love.graphics.setColor(0, 0, 0)
  love.graphics.setLineWidth(2 + beatPower * 2)
  love.graphics.line(width / 2, lineY1 - 64 - beatPower * 8, width / 2, lineY2 + 64 + beatPower * 8)

  love.graphics.setFont(self.font1)
  love.graphics.printf(
    "Tap a button on your input device (keyboard or gamepad) along with the beat to calibrate the delay.",
    200, 150, width - 400, "center")

  if self.offsetCount > 0 then
    love.graphics.printf(
      "Press Enter or Start to continue.",
      200, height - 50 - 20, width - 400, "center")
  end

  love.graphics.setFont(self.font2)
  love.graphics.printf(
    "Offset in milliseconds:\n" .. math.floor(self.delay * 1000000000 + 0.5) / 1000000,
    200, height - 150 - 24, width - 400, "center"
  )
end

return state
