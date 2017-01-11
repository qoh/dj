local gamestate = require "lib.hump.gamestate"
local editor

local state = {
  fields = {
    {name = "Song title", key = "title", type = "string"},
    {name = "Author name", key = "author", type = "string"},
    {name = "Difficulty name", key = "difficulty", type = "string"},
    {name = "Beats per minute", key = "bpm", type = "number"},
    {name = "Beat display scale", key = "beatScale", type = "number", default = 64},
    {name = "Beat offset (?)", key = "offset", type = "number"},
    {name = "Audio filename", key = "audio", type = "string"},
    {name = "Song background image", key = "image", type = "string"},
    {name = "Completion stats image", key = "statsImage", type = "string"},
    {name = "Work in progress", key = "wip", type = "bool"}
  }
}

function state:init()
  editor = require "states.editor"

  self.fontHeader = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", 32)
  self.fontKeyName = love.graphics.newFont("assets/fonts/Roboto-Thin.ttf", 24)
  self.fontKeyValue = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 24)
end

function state:enter(_, song)
  self.song = song
  self.index = 1
  self.editstate = false

  love.keyboard.setKeyRepeat(true)
end

function state:leave()
  love.keyboard.setKeyRepeat(false)
  self.song = nil
end

function state:getvalue(field)
  if self.song[field.key] ~= nil then
    return self.song[field.key]
  end

  if field.default ~= nil then
    return field.default
  end

  if field.type == "string" then
    return ""
  elseif field.type == "number" then
    return 0
  elseif field.type == "boolean" then
    return false
  end
end

function state:keypressed(key)
  local field = self.fields[self.index]

  if self.editstate then
    if key == "escape" then
      self.editstate = false
      self.editvalue = nil
    elseif key == "return" then
      self.song[field.key] = self.editvalue
      editor.unsaved = true

      self.editstate = false
      self.editvalue = nil
    elseif key == "backspace" and field.type == "string" then
      self.editvalue = self.editvalue:sub(1, self.cursorpos - 1) .. self.editvalue:sub(self.cursorpos + 1)
      self.cursorpos = math.max(0, self.cursorpos - 1)
    elseif key == "delete" and field.type == "string" then
      self.editvalue = self.editvalue:sub(1, self.cursorpos) .. self.editvalue:sub(self.cursorpos + 2)
    elseif key == "left" and field.type == "string" then
      self.cursorpos = math.max(0, self.cursorpos - 1)
    elseif key == "right" and field.type == "string" then
      self.cursorpos = math.min(#self.editvalue, self.cursorpos + 1)
    elseif key == "home" and field.type == "string" then
      self.cursorpos = 0
    elseif key == "end" and field.type == "string" then
      self.cursorpos = #self.editvalue
    elseif key == "up" and field.type == "number" then
      if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        self.editvalue = self.editvalue + 0.1
      elseif love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        self.editvalue = self.editvalue + 10
      else
        self.editvalue = self.editvalue + 1
      end
    elseif key == "down" and field.type == "number" then
      if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        self.editvalue = self.editvalue - 0.1
      elseif love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        self.editvalue = self.editvalue - 10
      else
        self.editvalue = self.editvalue - 1
      end
    end
  elseif key == "up" then
    if self.index == 1 then
      self.index = #self.fields
    else
      self.index = self.index - 1
    end
  elseif key == "down" then
    if self.index == #self.fields then
      self.index = 1
    else
      self.index = self.index + 1
    end
  elseif key == "return" then
    if field.type == "bool" then
      local value = self:getvalue(field)
      self.song[field.key] = not value
      editor.unsaved = true
    else
      self.editstate = true
      self.editvalue = self:getvalue(field)

      if field.type == "string" then
        self.cursorpos = #self.editvalue
      end
    end
  elseif key == "escape" then
    gamestate.pop()
  end
end

function state:textinput(text)
  if self.editstate and self.fields[self.index].type == "string" then
    self.editvalue = self.editvalue:sub(1, self.cursorpos) .. text .. self.editvalue:sub(self.cursorpos + 1)
    self.cursorpos = self.cursorpos + #text
  end
end

function state:draw()
  love.graphics.setColor(255, 255, 255)
  love.graphics.setFont(self.fontHeader)
  love.graphics.print("Track metadata editor", 32, 32)
  love.graphics.setFont(self.fontKeyValue)
  love.graphics.print("Escape to exit, return to edit", 32, love.graphics.getHeight() - 32 - 24)

  local baseY = 96
  local eachY = 36
  local keyNameWidth = 384
  local keyValueWidth = 480
  local keyNameX = 64
  local keyValueX = keyNameX + keyNameWidth

  for i, field in ipairs(self.fields) do
    local y = baseY + (i - 1) * eachY
    local value

    if i == self.index then
      love.graphics.setColor(255, 255, 255, 70)

      if self.editstate then
        love.graphics.rectangle("fill", keyValueX - 6, y - 6, keyValueWidth + 12, 24 + 12)

        if field.type == "string" then
          local x = keyValueX + self.fontKeyValue:getWidth(self.editvalue:sub(1, self.cursorpos))
          love.graphics.setColor(255, 255, 255)
          love.graphics.line(x, y - 4, x, y + 24 + 4)
        end
      else
        love.graphics.rectangle("fill", keyNameX - 6, y - 6, keyNameWidth + keyValueWidth + 12, 24 + 12)
      end
    end

    if self.editstate and i == self.index then
      value = self.editvalue
    else
      value = self:getvalue(field)
    end

    if field.type == "bool" then
      if value then
        value = "Yes"
      else
        value = "No"
      end
    elseif field.type == "number" then
      value = tostring(value)
    end

    love.graphics.setColor(255, 255, 255, 200)
    love.graphics.setFont(self.fontKeyName)
    love.graphics.print(field.name, keyNameX, y)
    love.graphics.setColor(255, 255, 255)
    love.graphics.setFont(self.fontKeyValue)
    love.graphics.print(value, keyValueX, y)
  end
end

return state
