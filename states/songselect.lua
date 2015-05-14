-- local threaded = ...
--
-- if threaded == true then
--     require "love.sound"
--     require "love.graphics"
--
--     local requests = love.thread.getChannel("songselect-requests")
--     local response = love.thread.getChannel("songselect-response")
--
--     while true do
--         local request = requests:demand()
--
--         if request == false then
--             response:supply(false)
--             break
--         end
--
--         local type = request[1]
--         local path = request[2]
--
--         print("Trying to load " .. type .. ": " .. path)
--
--         local resource
--
--         if type == "image" then
--             print("yeah, loading!")
--             -- resource = love.graphics.newImage(path)
--             local status, result = pcall(function() love.graphics.newImage(path) end)
--             print(status, result)
--             resource = result
--             print("woo")
--         elseif type == "sound" then
--             resource = love.sound.newSoundData(path)
--         end
--
--         print("OK")
--
--         response:push{type, path, resource}
--     end
--
--     return
-- end
--
-- local thisFile = (...):gsub("%.", "/") .. ".lua"
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

    self.fadingSounds = {}
    self.fadingImages = {}

    self.durations = {}
    self.images = {}

    -- for name, load in pairs(self.loads) do
    --     if load.image then
    --         local file = filepath(name) .. load.image
    --
    --         if self.dataImage[file] == nil then
    --             self.dataImage[file] = false
    --         end
    --     end
    -- end

    self:select(1)

    -- self.loader = love.thread.newThread(thisFile)
    -- self.loader:start(true)
    -- self.loaderBusy = false
    -- self.loaderDone = false

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

-- function love.threaderror(a, b, c)
--     print("threaderror")
--     print(a, b, c)
-- end

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
    -- if self.loader then
    --     local error = self.loader:getError()
    --
    --     if error then
    --         print("------------")
    --         print("Error in loader: " .. error)
    --         self.loader = nil
    --     end
    -- end
    --
    -- if self.loader and self.loader:isRunning() then
    --     local response = love.thread.getChannel("songselect-response"):pop()
    --
    --     if self.loaderBusy and response then
    --         print("Loaded " .. response[1] .. ": " .. response[2])
    --
    --         local type = response[1]
    --         local file = response[2]
    --         local data = response[3]
    --
    --         if type == "image" then
    --             self.dataImage[file] = data
    --         elseif type == "sound" then
    --             self.dataSound[file] = data
    --
    --             local name = self.songs[self.selected]
    --             local desired = filepath(name) .. self.loads[name].audio
    --
    --             if file == desired and not self.source then
    --                 self.source = love.audio.newSource(response[2])
    --                 self.source:play()
    --                 self.source:seek(30.5)
    --                 self.source:setVolume(0)
    --             end
    --         end
    --
    --         self.loaderBusy = false
    --     end
    --
    --     if not self.loaderBusy and not self.loaderDone then
    --         print("Making request")
    --         local request = false
    --
    --         -- First, check if the currently selected song is done loading
    --         local name = self.songs[self.selected]
    --         local path = filepath(name)
    --         local load = self.loads[name]
    --
    --         if load.image and self.dataImage[path .. load.image] == false then
    --             request = {"image", path .. load.image}
    --         elseif self.dataSound[path .. load.audio] == false then
    --             request = {"sound", path .. load.audio}
    --         else -- Pick an arbitrary one
    --             -- This is pretty bad.
    --             for key, value in pairs(self.dataSound) do
    --                 if value == false then
    --                     request = {"sound", key}
    --                     break
    --                 end
    --             end
    --
    --             if request == false then
    --                 for key, value in pairs(self.dataImage) do
    --                     if value == false then
    --                         request = {"image", key}
    --                         break
    --                     end
    --                 end
    --             end
    --         end
    --
    --         if request == false then
    --             self.loaderDone = true
    --             print("Done loading")
    --         else
    --             self.loaderBusy = true
    --             print("Requesting " .. request[1] .. ": " .. request[2])
    --         end
    --
    --         love.thread.getChannel("songselect-requests"):push(request)
    --     end
    --
    --     -- local requests = love.thread.getChannel("songselect-requests")
    --     --
    --     -- if response then
    --     --     print("Loaded " .. response[1])
    --     --     self.datas[response[1]] = response[2]
    --     --
    --     --     if self.songs[self.selected] == response[1] and not self.source then
    --     --         self.source = love.audio.newSource(response[2])
    --     --         self.source:play()
    --     --         self.source:seek(30.5)
    --     --         self.source:setVolume(0)
    --     --     end
    --     -- end
    -- end

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

        -- local data = self.datas[file]
        -- local data = nil
        -- local detail
        local detail = ""

        detail = detail .. util.secondsToTime(math.ceil(load.length))
        detail = detail .. "     " .. load.bpm .. " BPM"
        detail = detail .. "     " .. #load.notes .. " notes"
        detail = detail .. "     " .. #load.lanes .. " fades"

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
