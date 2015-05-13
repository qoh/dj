local threaded = ...

if threaded == true then
    require "love.sound"

    local requests = love.thread.getChannel("songselect-requests")
    local response = love.thread.getChannel("songselect-response")

    while true do
        local request = requests:pop()

        if not request then
            response:supply(false)
            break
        end

        response:push({request[1], love.sound.newSoundData(request[2])})
    end

    return
end

local thisFile = (...):gsub("%.", "/") .. ".lua"
local util = require "lib.util"
local state = {}

function state:run(callback)
    -- callback("songs/noisia-groundhog.track")
    -- do return end

    local songs = {}
    local loads = {}

    local items = love.filesystem.getDirectoryItems("songs")

    for i, leaf in ipairs(items) do
        local file = "songs/" .. leaf

        if not loads[file] and love.filesystem.isFile(file) and file:sub(-6) == ".track" then
            local load = love.filesystem.load(file)

            if load ~= nil then
                loads[file] = load()
                table.insert(songs, file)
            end
        end
    end

    table.sort(songs, function(a, b)
        local i = loads[a].title .. " - " .. loads[a].author
        local j = loads[b].title .. " - " .. loads[b].author
        return i < j
    end)

    gamestate.switch(self, callback, songs, loads)
end

function state:init()
    self.headerFont = love.graphics.newFont(36)
    self.titleFont = love.graphics.newFont(24)
    self.detailFont = love.graphics.newFont(16)
end

local function filepath(file)
    local index = file:find("/", 2)

    if index then
        return file:sub(1, index)
    end

    return "/"
end

function state:enter(previous, callback, songs, loads)
    self.callback = callback
    self.songs = songs
    self.loads = loads
    self.datas = {}
    self.selected = 1
    self.source = nil
    self.sourceFade = nil

    local requests = love.thread.getChannel("songselect-requests")

    for name, load in pairs(self.loads) do
        requests:push({name, filepath(name) .. load.audio})
    end

    self.loader = love.thread.newThread(thisFile)
    self.loader:start(true)

    love.graphics.setBackgroundColor(50, 50, 50)
end

function state:leave()
    if self.sourceFade then
        self.sourceFade:stop()
        self.sourceFade = nil
    end

    if self.source then
        self.source:stop()
        self.source = nil
    end

    -- Clean up the large amounts of memory these take
    self.songs = nil
    self.loads = nil
    self.datas = nil

    collectgarbage()
end

function state:select(index)
    local selected = self.selected
    self.selected = math.max(1, math.min(#self.songs, index))

    if self.selected ~= selected then
        if self.source then
            self.sourceFade = self.source
            self.source = nil
        end

        local data = self.datas[self.songs[self.selected]]

        if data then
            self.source = love.audio.newSource(data)
            self.source:play()
            self.source:seek(30.5)
            self.source:setVolume(0)
        end
    end
end

function state:continue()
    local name = self.songs[self.selected]
    local load = self.loads[name]
    local data = self.datas[name]

    if data == nil then
        self.loader = nil
        data = love.sound.newSoundData(filepath(name) .. load.audio)
    end

    if self.sourceFade then
        self.sourceFade:stop()
        self.sourceFade = nil
    end

    if self.source then
        self.source:stop()
        self.source = nil
    end

    self.callback(name, load, data)
end

function state:gamepadpressed(joystick, key)
    if key == "dpdown" then
        self:select(self.selected + 1)
    elseif key == "dpup" then
        self:select(self.selected - 1)
    elseif key == "a" or key == "start" then
        self:continue()
    end
end

function state:keypressed(key, unicode)
    if key == "down" then
        self:select(self.selected + 1)
    elseif key == "up" then
        self:select(self.selected - 1)
    elseif key == "return" then
        self:continue()
    end
end

function state:update(dt)
    if self.loader and self.loader:isRunning() then
        local response = love.thread.getChannel("songselect-response"):pop()

        if response then
            print("Loaded " .. response[1])
            self.datas[response[1]] = response[2]

            if self.songs[self.selected] == response[1] and not self.source then
                self.source = love.audio.newSource(response[2])
                self.source:play()
                self.source:seek(30.5)
                self.source:setVolume(0)
            end
        end
    end

    if self.sourceFade ~= nil then
        local volume = self.sourceFade:getVolume() - dt * 2

        if volume <= 0 then
            self.sourceFade:stop()
            self.sourceFade = nil
        else
            self.sourceFade:setVolume(volume)
        end
    end

    if self.source ~= nil then
        local volume = self.source:getVolume() + dt * 2
        self.source:setVolume(math.min(1, volume))
    end
end

function state:draw()
    love.graphics.setFont(self.headerFont)
    love.graphics.setColor(255, 255, 255)
    love.graphics.print("Select a track", 32, 32)

    for i, file in ipairs(self.songs) do
        local x = 48
        local y = 96 + (i - 1) * 72

        if i == self.selected then
            love.graphics.setColor(0, 0, 0, 100)
            love.graphics.rectangle("fill", x, y, 400, 66)
        end

        local load = self.loads[file]

        local title = load.title or love.path.leaf(file)
        local author = load.author or "Unknown artist"
        local difficulty = ""

        if load.difficulty then
            difficulty = " (" .. load.difficulty .. ")"
        end

        love.graphics.setFont(self.titleFont)
        love.graphics.setColor(255, 255, 255)
        love.graphics.print(title .. " - " .. author .. difficulty, x + 8, y + 8)

        local data = self.datas[file]
        local detail

        if data then
            local seconds = data:getDuration()
            detail = util.secondsToTime(math.floor(seconds)) .. " - "
        else
            detail = "Loading... - "
        end

        detail = detail .. "BPM: " .. load.bpm .. ", " .. #load.notes .. " notes"

        love.graphics.setFont(self.detailFont)
        love.graphics.setColor(255, 255, 255, 200)
        love.graphics.print(detail, x + 8, y + 38)
    end
end

return state
