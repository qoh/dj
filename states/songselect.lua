local gamestate = require "lib.hump.gamestate"
local util = require "lib.util"
local state = {}

-- experiment
-- local scale = 2.5
--
-- function love.window.toPixels(x, y)
--     x = x * scale
--
--     if y then
--         y = y * scale
--     end
--
--     return x, y
-- end
--
-- function love.window.fromPixels(x, y)
--     x = x / scale
--
--     if y then
--         y = y / scale
--     end
--
--     return x, y
-- end

function state:run(callback)
    local lookup = {}

    local songs = {}
    local loads = {}

    local function explore(directory)
        local items = love.filesystem.getDirectoryItems(directory)

        for i, leaf in ipairs(items) do
            local path = directory .. "/" .. leaf

            if love.filesystem.isDirectory(path) then
                explore(path)
            elseif not loads[path] and love.filesystem.isFile(path) and path:sub(-6) == ".track" then
                local load = love.filesystem.load(path)

                if load ~= nil then
                    loads[path] = load()
                    local audio = util.filepath(path) .. loads[path].audio

                    if not lookup[audio] then
                        lookup[audio] = {}
                        table.insert(songs, lookup[audio])
                    end

                    table.insert(lookup[audio], path)
                    -- table.insert(songs, path)
                end
            end
        end
    end

    explore("songs")

    table.sort(songs, function(a, b)
        -- local i = loads[a].title .. " - " .. loads[a].author
        -- local j = loads[b].title .. " - " .. loads[b].author
        local i = loads[a[1]].title .. " - " .. loads[a[1]].author
        local j = loads[b[1]].title .. " - " .. loads[b[1]].author
        return i < j
    end)

    gamestate.push(self, callback, songs, loads)
end

function state:init()
    self.headerFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", love.window.toPixels(36))
    self.titleFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", love.window.toPixels(24))
    self.detailFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", love.window.toPixels(16))
    self.smallFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", love.window.toPixels(14))

    -- self.imageNavGamepad = love.graphics.newImage("assets/keys-gamepad/dpad.png")
    -- self.imageSelGamepad = love.graphics.newImage("assets/keys-gamepad/a.png")
    -- self.imageNavKeyboard = love.graphics.newImage("assets/keys-keyboard/arrows.png")
    -- self.imageSelKeyboard = love.graphics.newImage("assets/keys-keyboard/enter.png")
end

function state:enter(previous, callback, songs, loads)
    self.callback = callback
    self.songs = songs
    self.loads = loads

    self.indexSong = nil
    self.indexVersion = nil

    self.stickScrollTime = nil
    self.timeSinceClick = nil
    self.isMouseScroll = false

    self.scrollValue = 0
    self.scrollSpeed = 0

    self.source = nil
    self.image = nil
    self.fadingSounds = {}
    self.fadingImages = {}

    if #self.songs > 0 then
        self:select(love.math.random(1, #self.songs), 1)
    end

    love.graphics.setBackgroundColor(50, 50, 50)
    love.keyboard.setKeyRepeat(true)
end

function state:leave()
    love.keyboard.setKeyRepeat(false)

    for i, source in ipairs(self.fadingSounds) do
        source:stop()
    end

    self.fadingSounds = nil
    self.fadingImages = {}

    if self.source then
        self.source:stop()
    end

    self.source = nil
    self.image = nil

    self.songs = nil
    self.loads = nil

    collectgarbage()
end

function state:continue()
    local name = self.songs[self.indexSong][self.indexVersion]
    local load = self.loads[name]

    gamestate.push(states.loadsong,
        util.filepath(name) .. load.audio,
        function(soundData)
            self.callback(name, load, soundData)
        end
    )
end

function state:update(dt)
    if self.timeSinceClick then
        self.timeSinceClick = self.timeSinceClick + dt
    end

    self.scrollValue = self.scrollValue + self.scrollSpeed * dt
    self.scrollSpeed = self.scrollSpeed - self.scrollSpeed * dt * 8

    local height = love.window.fromPixels(love.graphics.getHeight())

    -- local minimum = 68 * #self.songs - 8 - height / 8
    -- local maximum = math.max(minimum, height / 8)
    local minimum = 0
    local maximum = 68 * #self.songs - 8

    if self.scrollValue < minimum then
        self.scrollValue = self.scrollValue + (minimum - self.scrollValue) * dt * 16
    elseif self.scrollValue > maximum then
        self.scrollValue = self.scrollValue + (maximum - self.scrollValue) * dt * 16

        if self.scrollValue < maximum then
            self.scrollValue = maximum
        end
    end

    local joystick = love.joystick.getJoysticks()[1]

    if not settings.ignoreGamepad and joystick then
        local value = joystick:getGamepadAxis("lefty")
        local speed = 1 - (math.abs(value) - 0.25) / 0.75 + 0.05

        if math.abs(value) > 0.25 then
            local delta = value < 0 and -1 or 1

            if self.stickScrollTime then
                while self.stickScrollTime <= 0 do
                    self:select(math.max(1, math.min(#self.songs, self.indexSong + delta)), 1)
                    self.stickScrollTime = self.stickScrollTime + speed
                end

                self.stickScrollTime = self.stickScrollTime - dt
            else
                self:select(math.max(1, math.min(#self.songs, self.indexSong + delta)), 1)
                self.stickScrollTime = 0.4
            end
        else
            self.stickScrollTime = nil
        end
    end

    -- Fade out images
    local i = 1

    while i <= #self.fadingImages do
        local opacity = self.fadingImages[i][2] - dt * 4

        if opacity <= 0 then
            table.remove(self.fadingImages, i)
        else
            self.fadingImages[i][2] = opacity
            i = i + 1
        end
    end

    -- Fade out music
    local i = 1

    while i <= #self.fadingSounds do
        local volume = self.fadingSounds[i]:getVolume() - dt * 2

        if volume <= 0 then
            self.fadingSounds[i]:stop()
            table.remove(self.fadingSounds, i)
        else
            self.fadingSounds[i]:setVolume(volume)
            i = i + 1
        end
    end

    -- Fade in music
    if self.source ~= nil then
        local volume = self.source:getVolume() + dt * 2
        self.source:setVolume(math.min(1, volume))
    end
end

function state:select(indexSong, indexVersion)
    local prevImage, currImage
    local prevSound, currSound

    if self.indexSong and self.songs[self.indexSong] then
        local load = self.loads[self.songs[self.indexSong][self.indexVersion]]
        prevImage = load.image and util.filepath(self.songs[self.indexSong][self.indexVersion]) .. load.image
        prevSound = util.filepath(self.songs[self.indexSong][self.indexVersion]) .. load.audio
    end

    self.indexSong = indexSong
    self.indexVersion = indexVersion

    do
        local load = self.loads[self.songs[self.indexSong][self.indexVersion]]
        currImage = load.image and util.filepath(self.songs[self.indexSong][self.indexVersion]) .. load.image
        currSound = util.filepath(self.songs[self.indexSong][self.indexVersion]) .. load.audio
    end

    if prevImage ~= currImage then
        if self.image ~= nil then
            table.insert(self.fadingImages, {self.image, 1})
        end

        if currImage then
            self.image = love.graphics.newImage(currImage)
        end
    end

    if prevSound ~= currSound then
        if self.source then
            table.insert(self.fadingSounds, self.source)
        end

        self.source = love.audio.newSource(currSound, "stream")
        self.source:setLooping(true)
        self.source:setVolume(0)
        self.source:play()
        self.source:seek(30.5)
    end

    local target = self:getEntryY(indexSong, true) + 30
    local distance = target - self.scrollValue

    self.scrollSpeed = distance * 8
end

function state:keypressed(key, unicode)
    if key == "down" then
        if self.indexSong == #self.songs then
            self:select(1, 1)
        else
            self:select(self.indexSong + 1, 1)
        end
    elseif key == "up" then
        if self.indexSong == 1 then
            self:select(#self.songs, 1)
        else
            self:select(self.indexSong - 1, 1)
        end
    elseif key == "left" then
        local versions = self.songs[self.indexSong]

        if self.indexVersion == 1 then
            self:select(self.indexSong, #versions)
        else
            self:select(self.indexSong, self.indexVersion - 1)
        end
    elseif key == "right" then
        local versions = self.songs[self.indexSong]

        if self.indexVersion == #versions then
            self:select(self.indexSong, 1)
        else
            self:select(self.indexSong, self.indexVersion + 1)
        end
    elseif key == "return" then
        self:continue()
    elseif key == "escape" then
        gamestate.pop()
    end
end

function state:gamepadpressed(joystick, key)
    if key == "dpdown" then
        if self.indexSong == #self.songs then
            self:select(1, 1)
        else
            self:select(self.indexSong + 1, 1)
        end
    elseif key == "dpup" then
        if self.indexSong == 1 then
            self:select(#self.songs, 1)
        else
            self:select(self.indexSong - 1, 1)
        end
    elseif key == "dpleft" then
        local versions = self.songs[self.indexSong]

        if self.indexVersion == 1 then
            self:select(self.indexSong, #versions)
        else
            self:select(self.indexSong, self.indexVersion - 1)
        end
    elseif key == "dpright" then
        local versions = self.songs[self.indexSong]

        if self.indexVersion == #versions then
            self:select(self.indexSong, 1)
        else
            self:select(self.indexSong, self.indexVersion + 1)
        end
    elseif key == "a" then
        self:continue()
    elseif key == "b" then
        gamestate.pop()
    end
end

-- function state:touchpressed(id, x, y, pressure)
--     if y < 1 / 3 then
--         self:select(self.selected - 1, 1)
--     elseif y > 2 / 3 then
--         self:select(self.selected + 1, 1)
--     else
--         self:continue()
--     end
-- end

function state:mousemoved(x, y, dx, dy)
    if love.mouse.isDown("l") then
        self.isMouseScroll = true
        self.scrollSpeed = love.window.fromPixels(-dy) / love.timer.getDelta()
    end
end

function state:mousepressed(x, y, button)
    if button == "wd" then
        self.scrollSpeed = self.scrollSpeed + 288 * 2
    elseif button == "wu" then
        self.scrollSpeed = self.scrollSpeed - 288 * 2
    end

    self.isMouseScroll = false
end

function state:mousereleased(x, y, button)
    if button == "l" and not self.isMouseScroll then
        local index = self:findEntryColliding(love.window.fromPixels(x, y))

        if index then
            if index == self.indexSong then
                if self.timeSinceClick and self.timeSinceClick < 0.2 then
                    self:continue()
                end
            else
                self:select(index, 1)
            end

            -- if index == self.indexSong and self.timeSinceClick and self.timeSinceClick < 0.2 then
            --     self:continue()
            -- else
            --     self:select(index, 1)
            -- end
        end

        self.timeSinceClick = 0
    end

    self.isMouseScroll = false
end

function state:findEntryColliding(x, y)
    if x < 32 or x > 32 + 600 then
        return
    end

    y = y - love.window.fromPixels(love.graphics.getHeight()) / 2
    y = (y + self.scrollValue) / 68 + 1

    if y < 1 or math.floor(y) > #self.songs or y - math.floor(y) > 60 / 68 then
        return
    end

    return math.floor(y)
end

function state:getEntryY(index, excludeTranslate)
    local y = 68 * (index - 1)

    if not excludeTranslate then
        y = y + love.window.fromPixels(love.graphics.getHeight()) / 2 - self.scrollValue
    end

    return y
end

function state:draw()
    local width, height = love.window.fromPixels(love.graphics.getDimensions())

    if self.image then
        local w, h = love.window.fromPixels(self.image:getDimensions())
        local scale = math.max(width / w, height / h)

        w = w * scale
        h = h * scale

        love.graphics.setColor(255, 255, 255)
        love.graphics.draw(self.image, love.window.toPixels(width / 2 - w / 2), love.window.toPixels(height / 2 - h / 2), 0, scale, scale)
    end

    for i, entry in ipairs(self.fadingImages) do
        local image = entry[1]
        local opacity = entry[2]

        local w, h = love.window.fromPixels(image:getDimensions())
        local scale = math.max(width / w, height / h)

        w = w * scale
        h = h * scale

        love.graphics.setColor(200, 200, 200, 255 * opacity)
        love.graphics.draw(image, width / 2 - w / 2, height / 2 - h / 2, 0, scale, scale)
    end

    love.graphics.push()
    love.graphics.translate(0, math.floor(love.window.toPixels(height / 2) + 0.5))
    love.graphics.translate(0, math.floor(love.window.toPixels(-self.scrollValue) + 0.5))

    love.graphics.setLineWidth(love.window.toPixels(2))

    for i, song in ipairs(self.songs) do
        -- Each entry in the list of songs is a box containing (vertically):
        -- -- 8dp padding
        -- -- 24dp title
        -- -- 4dp padding
        -- -- 16dp detail
        -- -- 8dp padding
        -- Entries are 60dp tall and have 8dp padding on the bottom
        -- This makes them exactly 68dp tall
        local x = 32
        local y = self:getEntryY(i, true)

        love.graphics.setColor(63, 63, 63, i == self.indexSong and 224 or  63)
        love.graphics.rectangle("fill", love.window.toPixels(x), love.window.toPixels(y), love.window.toPixels(600, 60))
        love.graphics.setColor(63, 63, 63, i == self.indexSong and 255 or 127)
        love.graphics.rectangle("line", love.window.toPixels(x), love.window.toPixels(y), love.window.toPixels(600, 60))

        local title
        local detail

        if i == self.indexSong then
            local load = self.loads[song[self.indexVersion]]
            title = load.title .. " - " .. load.author

            if load.difficulty then
                title = title .. " (" .. load.difficulty .. ")"
            end

            detail =
                util.secondsToTime(math.ceil(load.length or 0))
                .. "     " .. #load.notes .. " notes"
                .. "     " .. #load.lanes .. " fades"

            if load.wip then
                detail = detail .. "     Track not complete"
            end
        else
            local load = self.loads[song[1]]
            title = load.title .. " - " .. load.author
            detail = util.secondsToTime(math.ceil(load.length or 0))

            if #song > 1 then
                detail = detail .. "     " .. #song .. " difficulties"
            end
        end

        love.graphics.setColor(255, 255, 255)
        love.graphics.setFont(self.titleFont)
        love.graphics.print(title, love.window.toPixels(x + 8, y + 8))
        love.graphics.setFont(self.detailFont)
        love.graphics.print(detail, love.window.toPixels(x + 8, y + 36))
    end

    love.graphics.pop()

    love.graphics.setFont(self.headerFont)
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf("Select a track", love.window.toPixels(32), love.window.toPixels(32), love.window.toPixels(width - 64), "right")

    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf("Left/Right to change difficulty",
        love.window.toPixels(32),
        love.window.toPixels(height - 12 - 32),
        love.window.toPixels(width - 64),
        "right")
end

return state
