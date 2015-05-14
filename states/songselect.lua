local util = require "lib.util"
local state = {}

local function filepath(file)
    local index

    while true do
        local search = file:find("/", (index or 1) + 1, true)

        if search then
            index = search
        else
            break
        end
    end

    if index then
        return file:sub(1, index)
    end

    return "/"
end

function state:run(callback)
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
                    table.insert(songs, path)
                    print(path)
                end
            end
        end
    end

    explore("songs")

    table.sort(songs, function(a, b)
        local i = loads[a].title .. " - " .. loads[a].author
        local j = loads[b].title .. " - " .. loads[b].author
        return i < j
    end)

    gamestate.push(self, callback, songs, loads)
end

function state:init()
    self.headerFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", 36)
    self.titleFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 24)
    self.detailFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 16)
    self.smallFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 14)

    self.imageNavGamepad = love.graphics.newImage("assets/keys-gamepad/dpad.png")
    self.imageSelGamepad = love.graphics.newImage("assets/keys-gamepad/a.png")
    self.imageNavKeyboard = love.graphics.newImage("assets/keys-keyboard/arrows.png")
    self.imageSelKeyboard = love.graphics.newImage("assets/keys-keyboard/enter.png")
end

function state:enter(previous, callback, songs, loads)
    self.callback = callback
    self.songs = songs
    self.loads = loads
    self.selected = false
    self.source = nil
    self.stickScrollTime = nil

    self.fadingSounds = {}
    self.fadingImages = {}

    self.images = {}

    self:select(1)

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

    self.images = nil

    if self.source then
        self.source:stop()
        self.source = nil
    end

    self.songs = nil
    self.loads = nil

    collectgarbage()
end

function state:select(index)
    local selected = self.selected
    self.selected = math.max(1, math.min(#self.songs, index))

    local prevName
    local prevImageFile
    local prevSoundFile

    if selected then
        prevName = self.songs[selected]
        prevImageFile = self.loads[prevName].image and (filepath(prevName) .. self.loads[prevName].image)
        prevSoundFile = filepath(prevName) .. self.loads[prevName].audio
    end

    local currName = self.songs[self.selected]
    local currImageFile = self.loads[currName].image and (filepath(currName) .. self.loads[currName].image)
    local currSoundFile = filepath(currName) .. self.loads[currName].audio

    if prevImageFile ~= currImageFile and self.images[prevImageFile] ~= nil and self.images[prevImageFile] ~= false then
        table.insert(self.fadingImages, {self.images[prevImageFile], 1})
    end

    if currImageFile then
        if self.images[currImageFile] == nil then
            self.images[currImageFile] = love.graphics.newImage(currImageFile)

            if self.images[currImageFile] == nil then
                self.images[currImageFile] = false
            end
        end
    end

    if prevSoundFile ~= currSoundFile then
        if self.source then
            table.insert(self.fadingSounds, self.source)
            self.source = nil
        end

        self.source = love.audio.newSource(currSoundFile, "stream")
        self.source:setLooping(true)
        self.source:setVolume(0)
        self.source:play()
        self.source:seek(30.5)
    end
end

function state:continue()
    local name = self.songs[self.selected]
    local load = self.loads[name]

    local soundData = love.sound.newSoundData(filepath(name) .. load.audio)
    self.callback(name, load, soundData)
end

function state:gamepadpressed(joystick, key)
    if key == "dpdown" then
        self:select(self.selected + 1)
    elseif key == "dpup" then
        self:select(self.selected - 1)
    elseif key == "a" then
        self:continue()
    elseif key == "b" then
        gamestate.pop()
    end
end

function state:keypressed(key, unicode)
    if key == "down" then
        self:select(self.selected + 1)
    elseif key == "up" then
        self:select(self.selected - 1)
    elseif key == "return" then
        self:continue()
    elseif key == "escape" then
        gamestate.pop()
    end
end

function state:update(dt)
    local joystick = love.joystick.getJoysticks()[1]

    if joystick then
        local value = joystick:getGamepadAxis("lefty")
        local speed = 1 - (math.abs(value) - 0.25) / 0.75 + 0.1

        if math.abs(value) > 0.25 then
            local delta = value < 0 and -1 or 1

            if self.stickScrollTime then
                while self.stickScrollTime <= 0 do
                    self:select(self.selected + delta)
                    self.stickScrollTime = self.stickScrollTime + speed
                end

                self.stickScrollTime = self.stickScrollTime - dt
            else
                self:select(self.selected + delta)
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

function state:draw()
    local width, height = love.graphics.getDimensions()

    do -- Draw stuff regarding the currently selected song
        local file = self.songs[self.selected]
        local load = self.loads[file]

        if load.image then
            local image = self.images[filepath(file) .. load.image]

            if image then
                local w, h = image:getDimensions()
                local scale = math.max(width / w, height / h)

                w = w * scale
                h = h * scale

                love.graphics.setColor(200, 200, 200)
                love.graphics.draw(image, width / 2 - w / 2, height / 2 - h / 2, 0, scale, scale)
            end
        end

        local x = 48
        local y = 96 + (self.selected - 1) * 72

        love.graphics.setColor(0, 0, 0, 100)
        love.graphics.rectangle("fill", x, y, 650, 66)
    end

    -- Draw fading images
    for i, entry in ipairs(self.fadingImages) do
        local image = entry[1]
        local opacity = entry[2]

        local w, h = image:getDimensions()
        local scale = math.max(width / w, height / h)

        w = w * scale
        h = h * scale

        love.graphics.setColor(200, 200, 200, 255 * opacity)
        love.graphics.draw(image, width / 2 - w / 2, height / 2 - h / 2, 0, scale, scale)
    end

    for i, file in ipairs(self.songs) do
        local x = 48
        local y = 96 + (i - 1) * 72

        local load = self.loads[file]
        local shown

        if load.title then
            shown = load.title .. " - " .. (load.author or "Unknown artist")
        else
            shown = love.path.leaf(file)

            if load.author then
                shown = shown .. " - " .. load.author
            end
        end

        if load.difficulty then
            shown = shown .. " (" .. load.difficulty .. ")"
        end

        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(255, 255, 255)
        love.graphics.print(shown, x + 8, y + 8)

        local detail =
            util.secondsToTime(math.ceil(load.length))
            .. "     " .. load.bpm .. " BPM"
            .. "     " .. #load.notes .. " notes"
            .. "     " .. #load.lanes .. " fades"

        love.graphics.setFont(self.detailFont)
        love.graphics.setColor(255, 255, 255, 200)
        love.graphics.print(detail, x + 8, y + 38)
    end

    love.graphics.setFont(self.headerFont)
    love.graphics.setColor(255, 255, 255)
    love.graphics.print("Select a track", 32, 32)

    -- Controls
    local hw = 216
    local hh = 32
    local hx = width - 8 - hw
    local hy = height - 8 - hh

    love.graphics.setColor(0, 0, 0, 127)
    love.graphics.rectangle("fill", hx - 8, hy - 8, hw + 16, hh + 16)
    love.graphics.setColor(255, 255, 255)
    love.graphics.setFont(self.smallFont)

    local joystick = #love.joystick.getJoysticks() > 0

    if settings.ignoreGamepad then
        joystick = nil
    end

    local imageNav = joystick and self.imageNavGamepad or self.imageNavKeyboard
    local imageSel = joystick and self.imageSelGamepad or self.imageSelKeyboard

    love.graphics.draw(imageNav, hx, hy)
    love.graphics.print("Navigate", hx + 36, hy + 8)
    love.graphics.draw(imageSel, hx + 36 + 72, hy)
    love.graphics.print("Confirm", hx + 36 + 72 + 36, hy + 8)
end

return state
