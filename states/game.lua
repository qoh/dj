require "lib.luafft"

local util = require "lib.util"
local gamestate = require "lib.hump.gamestate"
local state = {}

function state:init()
    self.regularFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 14)
    self.strongFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", 18)
    self.messageFont = love.graphics.newFont("assets/fonts/Roboto-Bold.ttf", 24)
    self.comboFont = love.graphics.newFont("assets/fonts/Roboto-Regular.ttf", 24)
end

function state:enter(previous, filename, song, data, mods, startFromEditor)
    self.mods = mods or {}

    self.filename = filename
    self.song = song

    self.stats = {
        score = 0,
        totalOffset = 0,
        noteCount = #song.notes,
        hitCount = 0,
        missCount = 0,
        bestCombo = 0,
        lostCombo = 0
    }

    self.startTimer = 3
    self.startStart = false
    self.fade = 0
    self.combo = 0
    self.rewind = false
    self.noteUsed = {}
    self.scratchUsed = {}
    self.heldNotes = {}
    self.fadeUsed = {}
    self.laneUsed = {
        [1] = false,
        [2] = false,
        [3] = false
    }

    self.faderErrorAccum = 0
    self.faderPointCount = 0
    self.faderPointTime = 0
    self.faderAnimLeft  = 1
    self.faderAnimRight = 0
    self.messageText = ""
    self.messageTime = 0
    self.shakeHit = 0
    self.shakeMiss = 0
    self.hitEffects = {}
    self.laneFillAnim = {
        [1] = 0,
        [2] = 0,
        [3] = 0
    }

    self.audioData = data
    self.audioSource = love.audio.newSource(self.audioData)
    self.audioSource:setPitch(self.mods.speed or 1)
    self.audioSource:play()

    -- Set up the audio analysis stuff
    self.frequencies = {}
    self.frequencyCount = 2048

    for i=1, self.frequencyCount do
        self.frequencies[i] = 0
    end

    if startFromEditor then
        self.startFromEditor = true
        self.startTimer = 0
        self.audioSource:seek(startFromEditor * (1 / (self.song.bpm / 60)))
    else
        self.audioSource:pause()
    end
end

function state:leave()
    self.startFromEditor = false
    self.song = nil

    self.audioSource:stop()
    self.audioSource = nil
    self.audioData = nil

    local joystick = love.joystick:getJoysticks()[1]
    if joystick then
        joystick:setVibration()
    end
end

function state:pause()
    self.audioSource:pause()

    local joystick = love.joystick:getJoysticks()[1]
    if joystick then
        joystick:setVibration()
    end
end

function state:resume()
    if self.startTimer <= 0 then
        self.audioSource:play()
    end
end

function state:getBeatScale()
    return self.song.beatScale or 64
end

function state:getCurrentPosition()
    local time = self.audioSource:tell("seconds") - self.startTimer - (self.song.offset or 0)
    return time / (1 / (self.song.bpm / 60))
end

function state:getWindow()
    return self.song.window or 0.5
end

function state:getMultiplier()
    return math.min(4, 1 + math.floor(self.combo / 8))
end

function state:loseCombo()
    if self.combo == 0 then
        return
    end

    self.shakeMiss = math.min(1, self.shakeMiss + self.combo / 8)
    self.stats.lostCombo = self.stats.lostCombo + 1
    self.combo = 0
end

function state:increaseCombo()
    self.combo = self.combo + 1
    self.stats.bestCombo = math.max(self.stats.bestCombo, self.combo)

    if self.combo > 0 and self.combo % 50 == 0 then
        self.messageTime = 2
        self.messageText = self.combo .. " note streak!"
    end

    if self.combo > 0 and self.combo % 60 == 0 and not self.rewind then
        self.rewind = true

        self.messageTime = 2
        self.messageText = "Rewind ready!"
    end
end

function state:noteHit(note, offset)
    self.shakeHit = math.min(1, self.shakeHit + 0.3)

    self.stats.hitCount = self.stats.hitCount + 1
    self.stats.totalOffset = self.stats.totalOffset + offset
    self.stats.score = self.stats.score + 100 * self:getMultiplier()

    self:increaseCombo()

    if note[2] == 1 or note[2] == 2 then
        self.laneUsed[1] = true
    elseif note[2] == 4 or note[2] == 5 then
        self.laneUsed[3] = true
    elseif note[2] == 3 then
        self.laneUsed[2] = true
    end

    table.insert(self.hitEffects, {0, note[2]})
end

function state:noteMiss(note)
    self:loseCombo()
    self.stats.missCount = self.stats.missCount + 1

    if note[2] == 1 or note[2] == 2 then
        self.laneUsed[1] = false
    elseif note[2] == 4 or note[2] == 5 then
        self.laneUsed[3] = false
    elseif note[2] == 3 then
        self.laneUsed[2] = false
    end
end

function state:fadeHit(fade, offset)
    self.shakeHit = math.min(1, self.shakeHit + 0.12)

    -- self.stats.hitCount = self.stats.hitCount + 1
    -- self.stats.totalOffset = self.stats.totalOffset + offset
    self.stats.score = self.stats.score + 100 * self:getMultiplier()

    self:increaseCombo()
end

function state:setFade(offset)
    if self.song.mode == "5key" then
        return
    end

    self.fade = math.max(-1, math.min(1, offset))
    local position = self:getCurrentPosition()

    for i, fade in ipairs(self.song.lanes) do
        local offset = fade[1] - position

        if offset > self:getWindow() then
            break
        end

        if offset > -self:getWindow() and fade[2] == self.fade and not self.fadeUsed[fade] then
            self.fadeUsed[fade] = true
            self:fadeHit(fade, offset)
            return
        end
    end

    local noteAccessible = {
        offset == -1,
        offset ~= -1,
        true,
        offset ~= 1,
        offset == 1
    }

    local i = 1

    while i <= #self.heldNotes do
        if not noteAccessible[self.heldNotes[i][1][2]] then
            table.remove(self.heldNotes, i)
        else
            i = i + 1
        end
    end
end

function state:lanePressed(lane)
    local position = self:getCurrentPosition()

    for i, note in ipairs(self.song.notes) do
        local offset = note[1] - position

        if offset > self:getWindow() then
            break
        end

        if note[2] == lane and not self.noteUsed[note] then
            self.noteUsed[note] = true
            self:noteHit(note, offset)

            if note[3] then
                table.insert(self.heldNotes, {note, 0, 0})
            end

            return
        end
    end

    self:loseCombo()

    if lane == 1 or lane == 2 then
        self.laneUsed[1] = false
    elseif lane == 4 or lane == 5 then
        self.laneUsed[3] = false
    elseif lane == 3 then
        self.laneUsed[2] = false
    end
end

function state:laneReleased(lane)
    for i, note in ipairs(self.heldNotes) do
        if note[1][2] == lane then
            table.remove(self.heldNotes, i)
            break
        end
    end
end

function state:activateEuphoria()
end

function state:escape()
    if self.startFromEditor then
        gamestate.pop()
    else
        gamestate.push(states.pause)
    end
end

function state:keypressed(key, unicode)
    if key == "escape" then
        self:escape()
    elseif key == "kpenter" or key == "application" then
        self:activateEuphoria()
    elseif self.song.mode == "5key" then
        if key == "a" then
            self:lanePressed(1)
        elseif key == "s" then
            self:lanePressed(2)
        elseif key == "d" then
            self:lanePressed(3)
        elseif key == "f" then
            self:lanePressed(4)
        elseif key == "g" then
            self:lanePressed(5)
        end
    else
        if key == "kp1" or key == "," then
            self:lanePressed(self.fade == -1 and 1 or 2)
        elseif key == "kp2" or key == "." then
            self:lanePressed(3)
        elseif key == "kp3" or key == "/" then
            self:lanePressed(self.fade == 1 and 5 or 4)
        elseif key == "kp4" then
            self:laneScratched(self.fade == -1 and 1 or 2, -1)
        end
    end
end

-- -1 iz up, 0 iz random, 1 iz down
function state:laneScratched(lane, dir)
    local position = self:getCurrentPosition()
    print(lane)

    for i, note in ipairs(self.song.notes) do
        if position < note[1] then
            break
        end

        if note[3] and note[4] and note[2] == lane and position < note[1] + note[3] then
        -- if note[3] and note[4] and note[2] == lane then
            for i, scratch in ipairs(note[4]) do
                local d = position - note[1] - scratch[1]

                if not self.scratchUsed[scratch] and (scratch[2] == dir or scratch[2] == 0) and math.abs(d) < 0.5 then
                    self.scratchUsed[scratch] = note
                    self:noteHit(note, d)
                end
            end

            break
        end
    end
end

function state:keyreleased(key, unicode)
    if self.song.mode == "5key" then
        if key == "a" then
            self:laneReleased(1)
        elseif key == "s" then
            self:laneReleased(2)
        elseif key == "d" then
            self:laneReleased(3)
        elseif key == "f" then
            self:laneReleased(4)
        elseif key == "g" then
            self:laneReleased(5)
        end
    else
        if key == "kp1" or key == "," then
            self:laneReleased(self.fade == -1 and 1 or 2)
        elseif key == "kp2" or key == "." then
            self:laneReleased(3)
        elseif key == "kp3" or key == "/" then
            self:laneReleased(self.fade == 1 and 5 or 4)
        elseif key == "kp4" then
            self:laneScratched(self.fade == -1 and 1 or 2, 1)
        end
    end
end

function state:gamepadpressed(joystick, key)
    if key == "start" then
        self:escape()
    elseif key == "x" then
        self:lanePressed(self.fade == -1 and 1 or 2)
    elseif key == "a" then
        self:lanePressed(3)
    elseif key == "b" then
        self:lanePressed(self.fade == 1 and 5 or 4)
    elseif key == "y" then
        self:lanePressed(self.fade == -1 and 1 or 2)
        self:lanePressed(self.fade == 1 and 5 or 4)
    elseif key == "leftshoulder" then
        self:lanePressed(self.fade == -1 and 1 or 2)
        self:lanePressed(3)
    elseif key == "rightshoulder" then
        self:lanePressed(3)
        self:lanePressed(self.fade == 1 and 5 or 4)
    elseif key == "back" then
        self:activateEuphoria()
    end
end

function state:gamepadreleased(joystick, key)
    if key == "x" then
        self:laneReleased(self.fade == -1 and 1 or 2)
    elseif key == "a" then
        self:laneReleased(3)
    elseif key == "b" then
        self:laneReleased(self.fade == 1 and 5 or 4)
    elseif key == "y" then
        self:laneReleased(self.fade == -1 and 1 or 2)
        self:laneReleased(self.fade == 1 and 5 or 4)
    elseif key == "leftshoulder" then
        self:laneReleased(self.fade == -1 and 1 or 2)
        self:laneReleased(3)
    elseif key == "rightshoulder" then
        self:laneReleased(3)
        self:laneReleased(self.fade == 1 and 5 or 4)
    end
end

function state:isLanePressed(lane)
    if self.song.mode == "5key" then
        if lane == 1 then
            return love.keyboard.isDown("a")
        elseif lane == 2 then
            return love.keyboard.isDown("s")
        elseif lane == 3 then
            return love.keyboard.isDown("d")
        elseif lane == 4 then
            return love.keyboard.isDown("f")
        elseif lane == 5 then
            return love.keyboard.isDown("g")
        end
    end

    local joystick = love.joystick.getJoysticks()[1]

    if settings.ignoreGamepad then
        joystick = nil
    end

    if lane == 1 then
        return love.keyboard.isDown("kp1") or (joystick and joystick:isGamepadDown("x"))
    elseif lane == 2 then
        return love.keyboard.isDown("kp2") or (joystick and joystick:isGamepadDown("a"))
    elseif lane == 3 then
        return love.keyboard.isDown("kp3") or (joystick and joystick:isGamepadDown("b"))
    end
end

local complex = require "lib.complex"
require "lib.luafft"

function state:getFrequencyBucket(freq)
    return freq * self.frequencyCount / 44100 + 1
end

function state:update(dt)
    if self.audioSource:isStopped() then
        if self.startFromEditor then
            gamestate.pop()
        else
            gamestate.switch(states.win, self.filename, self.song, self.stats)
        end

        return
    end

    -- Update audio analysis
    -- do
    --     local samples = {}
    --     local position = self.audioSource:tell("samples")
    --
    --     if self.audioData:getChannels() == 2 then
    --         for i=position, position + (self.frequencyCount - 1) do
    --             local sample = (self.audioData:getSample(i * 2) + self.audioData:getSample(i * 2 + 1)) * 0.5
    --             table.insert(samples, complex.new(sample, 0))
    --         end
    --     else
    --         for i=position, position + (self.frequencyCount - 1) do
    --             table.insert(samples, complex.new(soundData:getSample(i), 0))
    --         end
    --     end
    --
    --     local spectrum = fft(samples, false)
    --
    --     local bassCutoff = self:getFrequencyBucket(220)
    --     local bassVolume = 0
    --
    --     for i=1, self.frequencyCount do
    --         self.frequencies[i] = math.max(
    --             spectrum[i]:abs() / (self.frequencyCount / 2),
    --             self.frequencies[i] - self.frequencies[i] * dt * 4)
    --
    --         if i < bassCutoff then
    --             bassVolume = bassVolume + 10 ^ (self.frequencies[i] / 20)
    --         end
    --     end
    --
    --     self.beatVolume = (bassVolume - math.floor(bassCutoff)) / (1 / bassCutoff)
    --     -- rotationTime = rotationTime + bassVolume
    -- end

    --
    dt = dt * (self.mods.speed or 1)

    for i=1, 3 do
        if self.laneUsed[i] then
            self.laneFillAnim[i] = math.min(1, self.laneFillAnim[i] + dt)
        else
            self.laneFillAnim[i] = 0
        end
    end

    local position = self:getCurrentPosition()

    -- Handle proper fading
    if self.song.mode ~= "5key" then
        local fade = 0
        local time = 0

        for i, entry in ipairs(self.song.lanes) do
            if entry[1] < position then
                fade = entry[2]
            end
        end

        self.correctFade = fade

        if fade ~= 0 then
            -- Give points
            if self.fade == fade then
                self.faderPointTime = self.faderPointTime - dt

                while self.faderPointTime <= 0 do
                    self.stats.score = self.stats.score + 10 * self:getMultiplier()
                    self.faderPointCount = self.faderPointCount + 1

                    if self.faderPointCount == 5 then
                        self:increaseCombo()
                        self.faderPointCount = 0
                    end

                    self.faderPointTime = self.faderPointTime + 0.2
                end
            end

            -- Drop combo
            if self.fade == fade then
                self.faderErrorAccum = math.max(0, self.faderErrorAccum - dt)
            else
                self.faderErrorAccum = self.faderErrorAccum + dt
                local threshold = 1 / (self.song.bpm / 60) / (self.mods.speed or 1)

                if self.faderErrorAccum > threshold then
                    self.faderErrorAccum = 0
                    self:loseCombo()
                end
            end
        end
    end

    if self.messageTime > 0 then
        self.messageTime = math.max(0, self.messageTime - dt)
    end

    local joystick = love.joystick:getJoysticks()[1]

    if settings.ignoreGamepad then
        joystick = nil
    end

    local i = 1

    while i <= #self.hitEffects do
        local t = self.hitEffects[i][1] + dt * 2

        if t >= 1 then
            table.remove(self.hitEffects, i)
        else
            self.hitEffects[i][1] = t
            i = i + 1
        end
    end

    if self.shakeHit > 0 then
        self.shakeHit = math.max(self.shakeHit - dt / (self.mods.speed or 1), 0)
    end

    if self.shakeMiss > 0 then
        self.shakeMiss = math.max(self.shakeMiss - dt / (self.mods.speed or 1) / 2, 0)
    end

    local started = true
    local spinning = false

    if self.startTimer > 0 then
        if self.startStart then
            self.startTimer = self.startTimer - dt

            if self.startTimer <= 0 then
                self.audioSource:play()
                self.startTimer = 0
            else
                started = false
            end
        else
            self.startStart = true
            started = false
        end
    end

    -- Update stick control
    -- joystick = nil

    local isSpinning = false
    local spinAngle

    if joystick then
        if started then
            -- Spin to win
            local rx = joystick:getGamepadAxis("rightx")
            local ry = joystick:getGamepadAxis("righty")

            local rd = math.min(1, math.sqrt(rx^2 + ry^2))
            local rt = math.atan2(ry / rd, rx / rd)

            isSpinning = rd > 0.34
            spinAngle = rt
        end

        -- Crossfading
        local x = joystick:getGamepadAxis("leftx")
        local fade

        if x < -1/3 then
            fade = -1
        elseif x > 1/3 then
            fade = 1
        else
            fade = 0
        end

        if fade ~= self.fade then
            self:setFade(fade)
        end

        joystick:setVibration(self.shakeMiss * 0.5, self.shakeHit)
    else
        local fade = 0

        if love.keyboard.isDown("z") then
            fade = fade - 1
        end

        if love.keyboard.isDown("x") then
            fade = fade + 1
        end

        if fade ~= self.fade then
            self:setFade(fade)
        end

        local rx = 0
        local ry = 0

        if love.keyboard.isDown("a") then rx = rx - 1 end
        if love.keyboard.isDown("d") then rx = rx + 1 end
        if love.keyboard.isDown("w") then ry = ry - 1 end
        if love.keyboard.isDown("s") then ry = ry + 1 end

        local rd = math.min(1, math.sqrt(rx^2 + ry^2))
        local rt = math.atan2(ry / rd, rx / rd)

        isSpinning = rd > 0.34
        spinAngle = rt
    end

    if started then
        if isSpinning then
            if self.lastSpinAngle then
                local delta = spinAngle - self.lastSpinAngle

                if delta > math.pi then
                    delta = delta - math.pi * 2
                elseif delta < -math.pi then
                    delta = delta + math.pi * 2
                end

                local scrobble = (delta / math.pi) * 4
                local target = self.audioSource:tell("seconds") + scrobble
                local limit = self.audioData:getDuration("seconds")
                self.audioSource:seek(math.max(0, math.min(limit, target)))

                -- Try to revive some notes
                if delta < 0 then
                    local newNoteUsed = {}
                    local position = self:getCurrentPosition()

                    for note in pairs(self.noteUsed) do
                        local offset = note[1] - position

                        if offset < 0 then
                            newNoteUsed[note] = true
                        end
                    end

                    self.noteUsed = newNoteUsed

                    -- Exorcism on scratches
                    local newScratchUsed = {}

                    for scratch, note in pairs(self.scratchUsed) do
                        if position >= note[1] + scratch[1] then
                            newScratchUsed[scratch] = note
                        end
                    end

                    self.scratchUsed = newScratchUsed
                end
            end

            if not self.lastSpinning then
                self.audioSource:pause()
            end

            self.lastSpinAngle = spinAngle
            self.lastSpinning = true

            spinning = true
        elseif self.lastSpinning then
            self.lastSpinAngle = nil
            self.lastSpinning = false

            self.audioSource:play()
        end
    end

    local targetAnimLeft = self.fade == -1 and 0 or 1
    local targetAnimRight = self.fade == 1 and 1 or 0
    local animChange = dt / 0.1

    if self.faderAnimLeft < targetAnimLeft then
        self.faderAnimLeft = math.min(targetAnimLeft, self.faderAnimLeft + animChange)
    elseif self.faderAnimLeft > targetAnimLeft then
        self.faderAnimLeft = math.max(targetAnimLeft, self.faderAnimLeft - animChange)
    end

    if self.faderAnimRight < targetAnimRight then
        self.faderAnimRight = math.min(targetAnimRight, self.faderAnimRight + animChange)
    elseif self.faderAnimRight > targetAnimRight then
        self.faderAnimRight = math.max(targetAnimRight, self.faderAnimRight - animChange)
    end

    -- Handle held notes
    local i = 1

    while i <= #self.heldNotes do
        local item = self.heldNotes[i]
        local note = item[1]

        if position >= note[1] + note[3] then
            table.remove(self.heldNotes, i)
        else
            item[2] = item[2] + dt
            item[3] = item[3] + dt

            if self.shakeHit < 0.2 then
                self.shakeHit = 0.2
            end

            while item[3] >= 0.1 do
                self.stats.score = self.stats.score + 5 * self:getMultiplier()
                item[3] = item[3] - 0.1
            end

            i = i + 1
        end
    end

    -- Check for missed notes
    if started and not spinning then
        for i, note in ipairs(self.song.notes) do
            local offset = note[1] - position

            if offset >= -self:getWindow() then
                break
            end

            if not self.noteUsed[note] then
                self.noteUsed[note] = true
                self:noteMiss(note)
            end
        end
    end

    love.graphics.setBackgroundColor(100, 100, 100)
    -- local v = (self.beatVolume / 8) * 255
    -- love.graphics.setBackgroundColor(v, v, v)
end

local function draw_fader_back(x, y)
    love.graphics.setColor( 50,  50,  50)
    love.graphics.circle("fill", x,      y, 24)
    love.graphics.circle("fill", x + 64, y, 24)
    love.graphics.setColor(150, 150, 150)
    love.graphics.circle("line", x,      y, 24)
    love.graphics.circle("line", x + 64, y, 24)
    love.graphics.setColor( 50,  50,  50)
    love.graphics.rectangle("fill", x, y - 24, 64, 48)
    love.graphics.setColor(150, 150, 150)
    love.graphics.line(x, y - 24, x + 64, y - 24)
    love.graphics.line(x, y + 24, x + 64, y + 24)
end

local function draw_button(x, y, color, dot)
    dot = dot or {130, 130, 130}
    color = color or {255, 255, 255}

    love.graphics.setColor(color[1] * 0.2, color[2] * 0.2, color[3] * 0.2)
    love.graphics.circle("fill", x, y, 20)
    love.graphics.setColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8)
    love.graphics.circle("line", x, y, 20)
    love.graphics.setColor(dot[1], dot[2], dot[3])
    love.graphics.circle("fill", x, y, 6)
end

-- local function draw_held_note(x, y1, y2, position, scale, color, scratches, held)
--     o65 = 0.65 + (flash or 0)
--
--     local tipPrimary = {color[1] * o65, color[2] * o65, color[3] * o65}
--     local tipSecondary = {color[1] * 0.10, color[2] * 0.10, color[3] * 0.10}
--     local shaftPrimary
--     local shaftSecondary
--
--     if not held and position > y1 then
--         shaftPrimary = {60, 60, 60}
--         shaftSecondary = {25, 25, 25}
--     else
--         shaftPrimary = tipPrimary
--         shaftSecondary = tipSecondary
--     end
--
--     love.graphics.setColor(shaftPrimary)
--     love.graphics.circle("fill", x, y2, 16, 32)
--     love.graphics.setColor(shaftSecondary)
--     love.graphics.circle("line", x, y2, 16, 32)
--     love.graphics.setColor(shaftPrimary)
--     love.graphics.rectangle("fill", x - 16, y2, 32, y1 - y2)
--     love.graphics.setColor(shaftSecondary)
--     love.graphics.line(x - 16, y2, x - 16, y1)
--     love.graphics.line(x + 16, y2, x + 16, y1)
--
--     -- Draw some arrows or something
--     if scratches then
--         love.graphics.setColor(255, 255, 255)
--         love.graphics.setLineWidth(4)
--
--         for i, scratch in ipairs(scratches) do
--             local y = y1 - scratch[1] * scale
--
--             if scratch[2] == -1 then
--                 love.graphics.polygon("line", x, y - 10, x - 10, y + 10, x + 10, y + 10)
--             elseif scratch[2] == 1 then
--                 love.graphics.polygon("line", x, y + 10, x - 10, y - 10, x + 10, y - 10)
--             elseif scratch[2] == 0 then
--                 love.graphics.setLineJoin("bevel")
--                 love.graphics.line(x - 12, y, x - 4, y + 10, x - 4, y - 10)
--                 love.graphics.line(x + 12, y, x + 4, y - 10, x + 4, y + 10)
--                 love.graphics.setLineJoin("miter")
--             end
--         end
--
--         love.graphics.setLineWidth(2)
--     end
--
--     -- Draw just the tip
--     love.graphics.setColor(tipPrimary)
--     love.graphics.circle("fill", x, y1, 16, 32)
--     love.graphics.setColor(tipSecondary)
--     love.graphics.circle("line", x, y1, 16, 32)
-- end

function state:draw()
    local width, height = love.graphics.getDimensions()
    local position = self:getCurrentPosition()

    love.graphics.setFont(self.regularFont)
    love.graphics.setColor(255, 255, 255)
    -- love.graphics.print(math.floor(position * 4) / 4, 2, 2)

    local x = width / 2
    local y = height - 64

    local lanes = {
        [1] = x - 128,
        [2] = x - 64,
        [3] = x,
        [4] = x + 64,
        [5] = x + 128
    }

    local colors = {
        [1] = {127, 255,  50},
        [2] = {255,  50,  50},
        [3] = {  0, 127, 255},
    }

    local colorsByLane

    if self.song.mode == "5key" then
        colorsByLane = {
            [1] = {255, 255,  50},
            [2] = {255, 100, 200},
            [3] = {127, 255,  50},
            [4] = {255, 127,  50},
            [5] = { 50, 200, 255}
        }
    else
        colorsByLane = {
            [1] = colors[1],
            [2] = colors[1],
            [3] = colors[2],
            [4] = colors[3],
            [5] = colors[3]
        }
    end

    love.graphics.push()
    love.graphics.translate((love.math.random() - 0.5) * self.shakeMiss * 2, 0)

    -- Draw scratchboard
    love.graphics.setColor(30, 30, 30)
    love.graphics.rectangle("fill", x - 192, 0, 384, height)

    -- Draw beat lines
    local beatX1 = x - 192
    local beatX2 = x + 192

    love.graphics.setColor(255, 255, 255, 20)
    love.graphics.setLineWidth(1)

    love.graphics.push()
    love.graphics.translate(0, -self:getBeatScale() * (1 - (position - math.floor(position))))

    for i=0, height / self:getBeatScale() do
        love.graphics.line(beatX1, height - i * self:getBeatScale(), beatX2, height - i * self:getBeatScale())
    end

    love.graphics.pop()

    -- Draw combo steps
    for i=1, 7 do
        if self.combo >= 24 or self.combo % 8 >= i then
            love.graphics.setColor(200, 100, 30)
        else
            love.graphics.setColor(50, 50, 60)
        end

        love.graphics.rectangle("fill", x + 168, y - 64 - i * 12, 16, 8)
        love.graphics.setColor(255, 255, 255, 10)
        love.graphics.rectangle("fill", x + 168, y - 64 - i * 12, 16, 4)
    end

    if self.combo >= 8 then
        local mult = math.min(4, 1 + math.floor(self.combo / 8))
        love.graphics.setFont(self.comboFont)
        -- love.graphics.setColor(60, 60, 60)
        -- love.graphics.printf("x" .. mult, x + 119, y - 64 - 7 * 12 - 36, 64, "right")
        love.graphics.setColor(200, 100, 30)
        love.graphics.printf("x" .. mult, x + 120, y - 64 - 7 * 12 - 35, 64, "right")
    end

    if self.rewind then
        love.graphics.setFont(self.regularFont)
        -- love.graphics.setColor(60, 60, 60)
        -- love.graphics.printf("REWIND", x + 119, y - 64 - 7 * 12 - 36 - 24, 64, "right")
        love.graphics.setColor(200, 100, 30)
        love.graphics.printf("REWIND", x + 120, y - 64 - 7 * 12 - 35 - 24, 64, "right")
    end

    -- local rating = (1 - self.stats.missCount / self.stats.noteCount)
    -- rating = math.floor(rating * 1000 + self:getWindow()) / 10
    -- love.graphics.setFont(self.regularFont)
    -- love.graphics.setColor(200, 100, 30)
    -- love.graphics.printf(rating, x + 120 - 200, y - 64 - 7 * 12 - 35 - 24 - 30, 64 + 200, "right")

    -- Draw controls for fading and notes
    love.graphics.setLineWidth(2)

    if self.song.mode == "5key" then
        draw_button(lanes[1], y, self:islanePressed(1) and colorsByLane[1], colorsByLane[1])
        draw_button(lanes[2], y, self:isLanePressed(2) and colorsByLane[2], colorsByLane[2])
        draw_button(lanes[3], y, self:isLanePressed(3) and colorsByLane[3], colorsByLane[3])
        draw_button(lanes[4], y, self:isLanePressed(4) and colorsByLane[4], colorsByLane[4])
        draw_button(lanes[5], y, self:isLanePressed(5) and colorsByLane[5], colorsByLane[5])
    else
        draw_fader_back(lanes[1], y)
        draw_fader_back(lanes[4], y)
        draw_button(lanes[1] + self.faderAnimLeft  * 64, y, self:isLanePressed(1) and colors[1], self.laneUsed[1] and colors[1])
        draw_button(lanes[3]                           , y, self:isLanePressed(2) and colors[2], self.laneUsed[2] and colors[2])
        draw_button(lanes[4] + self.faderAnimRight * 64, y, self:isLanePressed(3) and colors[3], self.laneUsed[3] and colors[3])
    end

    -- Draw lanes
    if self.song.mode ~= "5key" then
        -- Find line segments for left and right lanes
        local vertices_left  = {lanes[2], y}
        local vertices_mid   = {lanes[3], y, lanes[3], 0}
        local vertices_right = {lanes[4], y}

        local i = 1

        local last_offset = 0
        local last_fading = 0

        while i <= #self.song.lanes do
            local offset = self.song.lanes[i][1] - position
            local fading = self.song.lanes[i][2]

            if y - offset * self:getBeatScale() < 0 then
                break
            end

            if offset <= 0 then
                vertices_left  = {lanes[fading == -1 and 1 or 2], y}
                vertices_right = {lanes[fading ==  1 and 5 or 4], y}
            elseif offset > 0 then
                -- Do we need to shift insert a point in the left lane?
                if (last_fading == -1 and fading ~= -1) or (last_fading ~= -1 and fading == -1) then
                    table.insert(vertices_left,  lanes[last_fading == -1 and 1 or 2])
                    table.insert(vertices_left,  y - offset * self:getBeatScale())
                    table.insert(vertices_left,  lanes[     fading == -1 and 1 or 2])
                    table.insert(vertices_left,  y - offset * self:getBeatScale())
                end

                if (last_fading ==  1 and fading ~=  1) or (last_fading ~=  1 and fading ==  1) then
                    table.insert(vertices_right, lanes[last_fading ==  1 and 5 or 4])
                    table.insert(vertices_right, y - offset * self:getBeatScale())
                    table.insert(vertices_right, lanes[     fading ==  1 and 5 or 4])
                    table.insert(vertices_right, y - offset * self:getBeatScale())
                end
            end

            last_offset = offset
            last_fading = fading

            i = i + 1
        end

        table.insert(vertices_left,  lanes[last_fading == -1 and 1 or 2])
        table.insert(vertices_left,  0)
        table.insert(vertices_right, lanes[last_fading ==  1 and 5 or 4])
        table.insert(vertices_right, 0)

        -- Get your wiggle game on
        if (self.correctFade == -1 and self.fade ~= -1) or (self.correctFade ~= -1 and self.fade == -1) then
            vertices_left = util.undulo(vertices_left)
        end

        if (self.correctFade == 1 and self.fade ~= 1) or (self.correctFade ~= 1 and self.fade == 1) then
            vertices_right = util.undulo(vertices_right)
        end

        local beat_strength = 1 - (position / 2 - math.floor(position / 2))
        beat_strength = beat_strength ^ 2

        love.graphics.setLineWidth(2)
        love.graphics.setColor(127, 127, 127)
        love.graphics.line(vertices_mid)
        if self.laneFillAnim[2] > 0 then
            love.graphics.setLineWidth(2 + 2 * beat_strength)
            love.graphics.setColor(colors[2])
            love.graphics.line(util.cutLine(vertices_mid, self.laneFillAnim[2]))
        end

        love.graphics.setLineWidth(2)
        love.graphics.setColor(127, 127, 127)
        love.graphics.line(vertices_left)
        if self.laneFillAnim[1] > 0 then
            love.graphics.setLineWidth(2 + 2 * beat_strength)
            love.graphics.setColor(colors[1])
            love.graphics.line(util.cutLine(vertices_left, self.laneFillAnim[1]))
        end

        love.graphics.setLineWidth(2)
        love.graphics.setColor(127, 127, 127)
        love.graphics.line(vertices_right)
        if self.laneFillAnim[3] > 0 then
            love.graphics.setLineWidth(2 + 2 * beat_strength)
            love.graphics.setColor(colors[3])
            love.graphics.line(util.cutLine(vertices_right, self.laneFillAnim[3]))
        end
    end

    love.graphics.setLineWidth(2)

    -- Draw notes
    for i, note in ipairs(self.song.notes) do
        local offset = note[1] - position

        if y - offset * self:getBeatScale() < -16 then
            break
        end

        if note[3] then
            local last = offset + note[3]

            if last >= 0 then
                local old = false
                local color = colorsByLane[note[2]]
                local length = note[3]

                if offset < 0 then
                    old = true
                    length = length + offset
                    offset = 0
                end

                -- This is very inefficient
                local held

                for i, each in ipairs(self.heldNotes) do
                    if each[1] == note then
                        held = each
                        break
                    end
                end

                local scale = self:getBeatScale()
                -- draw_held_note(lanes[note[2]], y - offset * scale, y - last * scale, scale, color, held and held[2])

                local o65 = 0.65

                if held then
                    o65 = o65 + 0.3 * math.sin(held[2] * math.pi * 5)
                end

                local tipPrimary = {color[1] * o65, color[2] * o65, color[3] * o65}
                local tipSecondary = {color[1] * 0.10, color[2] * 0.10, color[3] * 0.10}
                local shaftPrimary
                local shaftSecondary

                if not held and old then
                    shaftPrimary = {60, 60, 60}
                    shaftSecondary = {25, 25, 25}
                else
                    shaftPrimary = tipPrimary
                    shaftSecondary = tipSecondary
                end

                local x = lanes[note[2]]
                local y2 = y - last * scale
                local y1 = y - offset * scale

                love.graphics.setColor(shaftPrimary)
                love.graphics.circle("fill", x, y2, 16, 32)
                love.graphics.setColor(shaftSecondary)
                love.graphics.circle("line", x, y2, 16, 32)
                love.graphics.setColor(shaftPrimary)
                love.graphics.rectangle("fill", x - 16, y2, 32, y1 - y2)
                love.graphics.setColor(shaftSecondary)
                love.graphics.line(x - 16, y2, x - 16, y1)
                love.graphics.line(x + 16, y2, x + 16, y1)

                -- Draw some arrows or something
                if note[4] then
                    love.graphics.setColor(255, 255, 255)
                    love.graphics.setLineWidth(4)

                    for i, scratch in ipairs(note[4]) do
                        local p = note[1] + scratch[1]

                        if p > position then
                            local yy = y - (p - position) * scale

                            if scratch[2] == -1 then
                                love.graphics.polygon("line", x, yy - 10, x - 10, yy + 10, x + 10, yy + 10)
                            elseif scratch[2] == 1 then
                                love.graphics.polygon("line", x, yy + 10, x - 10, yy - 10, x + 10, yy - 10)
                            elseif scratch[2] == 0 then
                                love.graphics.setLineJoin("bevel")
                                love.graphics.line(x - 12, yy, x - 4, yy + 10, x - 4, yy - 10)
                                love.graphics.line(x + 12, yy, x + 4, yy - 10, x + 4, yy + 10)
                                love.graphics.setLineJoin("miter")
                            end
                        end
                    end

                    love.graphics.setLineWidth(2)
                end

                -- Draw just the tip
                love.graphics.setColor(tipPrimary)
                love.graphics.circle("fill", x, y1, 16, 32)
                love.graphics.setColor(tipSecondary)
                love.graphics.circle("line", x, y1, 16, 32)

                -- if held then
                --     local flash = 0.3 * math.sin(held[2] * math.pi * 5)
                --     draw_held_note(lanes[note[2]], y - offset * scale, y - last * scale, scale, color, note[4], flash)
                -- elseif not old then
                --     draw_held_note(lanes[note[2]], y - offset * scale, y - last * scale, scale, color, note[4])
                -- else
                --     draw_held_note(lanes[note[2]], y - offset * scale, y - last * scale, scale, color, note[4], nil, true)
                -- end

                -- if held then
                --     local flash = 0.3 * math.sin(held[2] * math.pi * 5)
                --     draw_held_note(lanes[note[2]], y - offset * scale, y - last * scale, scale, color, note[4], flash)
                -- elseif not old then
                --     draw_held_note(lanes[note[2]], y - offset * scale, y - last * scale, scale, color, note[4])
                -- else
                --     draw_held_note(lanes[note[2]], y - offset * scale, y - last * scale, scale, color, note[4], nil, true)
                -- end

                -- if held then
                --     local flash = 0.3 * math.sin(held[2] * math.pi * 5)
                --     local o65 = 0.65 + flash
                --
                --     love.graphics.setColor(color[1] * o65, color[2] * o65, color[3] * o65)
                --     love.graphics.circle("fill", lanes[note[2]], y - last * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                --     love.graphics.circle("line", lanes[note[2]], y - last * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(color[1] * o65, color[2] * o65, color[3] * o65)
                --     love.graphics.rectangle("fill", lanes[note[2]] - 16, y - last * self:getBeatScale(), 32, length * self:getBeatScale())
                --     love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                --     love.graphics.line(lanes[note[2]] - 16, y - last * self:getBeatScale(), lanes[note[2]] - 16, y - offset * self:getBeatScale())
                --     love.graphics.line(lanes[note[2]] + 16, y - last * self:getBeatScale(), lanes[note[2]] + 16, y - offset * self:getBeatScale())
                --     love.graphics.setColor(color[1] * o65, color[2] * o65, color[3] * o65)
                --     love.graphics.circle("fill", lanes[note[2]], y - offset * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                --     love.graphics.circle("line", lanes[note[2]], y - offset * self:getBeatScale(), 16, 32)
                -- elseif not old then
                --     love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
                --     love.graphics.circle("fill", lanes[note[2]], y - last * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                --     love.graphics.circle("line", lanes[note[2]], y - last * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
                --     love.graphics.rectangle("fill", lanes[note[2]] - 16, y - last * self:getBeatScale(), 32, length * self:getBeatScale())
                --     love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                --     love.graphics.line(lanes[note[2]] - 16, y - last * self:getBeatScale(), lanes[note[2]] - 16, y - offset * self:getBeatScale())
                --     love.graphics.line(lanes[note[2]] + 16, y - last * self:getBeatScale(), lanes[note[2]] + 16, y - offset * self:getBeatScale())
                --     love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
                --     love.graphics.circle("fill", lanes[note[2]], y - offset * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                --     love.graphics.circle("line", lanes[note[2]], y - offset * self:getBeatScale(), 16, 32)
                -- else
                --     love.graphics.setColor(60, 60, 60)
                --     love.graphics.circle("fill", lanes[note[2]], y - last * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(25, 25, 25)
                --     love.graphics.circle("line", lanes[note[2]], y - last * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(60, 60, 60)
                --     love.graphics.rectangle("fill", lanes[note[2]] - 16, y - last * self:getBeatScale(), 32, length * self:getBeatScale())
                --     love.graphics.setColor(25, 25, 25)
                --     love.graphics.line(lanes[note[2]] - 16, y - last * self:getBeatScale(), lanes[note[2]] - 16, y - offset * self:getBeatScale())
                --     love.graphics.line(lanes[note[2]] + 16, y - last * self:getBeatScale(), lanes[note[2]] + 16, y - offset * self:getBeatScale())
                --     love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
                --     love.graphics.circle("fill", lanes[note[2]], y - offset * self:getBeatScale(), 16, 32)
                --     love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                --     love.graphics.circle("line", lanes[note[2]], y - offset * self:getBeatScale(), 16, 32)
                -- end
            end
        elseif not self.noteUsed[note] and offset >= 0 then
            local color = colorsByLane[note[2]]

            love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
            love.graphics.circle("fill", lanes[note[2]], y - offset * self:getBeatScale(), 16, 32)
            love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
            love.graphics.circle("line", lanes[note[2]], y - offset * self:getBeatScale(), 16, 32)
        end
    end

    love.graphics.pop()

    -- Score..
    love.graphics.setFont(self.comboFont)
    love.graphics.setLineWidth(2)
    -- Draw a rectangle around the score
    love.graphics.setColor(50, 50, 50)
    love.graphics.rectangle("fill", 72, 72, 175, 42)
    love.graphics.setColor(150, 150, 150)
    love.graphics.rectangle("line", 72, 72, 175, 42)
    -- Draw the score number
    love.graphics.setColor(255, 255, 255)
    love.graphics.print(util.addSeparators(self.stats.score), 72 + 8, 72 + 8)
    -- Draw a rectangle around the combo
    love.graphics.setColor(50, 50, 50)
    love.graphics.rectangle("fill", 72, 72 + 42 + 8, 100, 42)
    love.graphics.setColor(150, 150, 150)
    love.graphics.rectangle("line", 72, 72 + 42 + 8, 100, 42)
    -- Draw the combo number
    love.graphics.setColor(255, 255, 255)
    love.graphics.print(util.addSeparators(self.combo), 72 + 8, 72 + 42 + 8 + 8)

    -- Draw hit effects
    love.graphics.setLineWidth(4)

    for i, effect in ipairs(self.hitEffects) do
        local color = colorsByLane[effect[2]]
        local radius = 16 + 12 * effect[1]
        love.graphics.setColor(color[1], color[2], color[3], 255 * (1 - effect[1]))
        love.graphics.circle("line", lanes[effect[2]], y, radius, radius * 2)
    end

    if self.messageTime > 0 then
        local fade = self.messageTime <= 0.5 and self.messageTime / 0.5 or 1

        love.graphics.setColor(255, 255, 255, 255 * fade)
        love.graphics.setFont(self.messageFont)
        love.graphics.printf(self.messageText, 128, height / 3 - 24, width - 256, "center")
    end

    -- Draw song title & author
    if self.startTimer > 0 then
        local fade = math.min(1, self.startTimer)

        love.graphics.setColor(0, 0, 0, 50 * fade)
        love.graphics.rectangle("fill", 128, height / 3 - 24 - 8, width - 256, 56)

        love.graphics.setColor(255, 255, 255, 255 * fade)
        love.graphics.setFont(self.messageFont)
        love.graphics.printf(self.song.author .. " - " .. self.song.title, 128, height / 3 - 24, width - 256, "center")
    end

    -- Draw subtitles
    if self.song.subtitles then
        local subtitle_y = y + 27
        love.graphics.setFont(self.regularFont)
        love.graphics.setColor(255, 255, 255)

        local t_a
        local t_b

        for i, entry in ipairs(self.song.subtitles) do
            if position < entry[1] then
                break
            end

            if position < entry[1] + entry[3] then
                if t_a then
                    if t_b then
                        t_a = t_b
                    end

                    t_b = entry[2]
                else
                    t_a = entry[2]
                end

                -- love.graphics.printf(entry[2], x - 192, subtitle_y, 384, "center")
                -- subtitle_y = subtitle_y + 18
            end
        end

        if t_b then
            love.graphics.printf(t_a, x - 192, subtitle_y, 384, "center")
            love.graphics.printf(t_b, x - 192, subtitle_y + 18, 384, "center")
        elseif t_a then
            love.graphics.printf(t_a, x - 192, subtitle_y + 9, 384, "center")
        end
    end

    -- Draw input overlay
    if settings.showInput then
        local joystick = love.joystick.getJoysticks()[1]

        if settings.ignoreGamepad then
            joystick = nil
        end

        if joystick then
            local function button(x, y, label, state)
                love.graphics.setFont(self.messageFont)
                love.graphics.setColor(150, 150, 150)
                love.graphics.setLineWidth(2)

                if state then
                    love.graphics.circle("fill", x + 16, y + 16, 16, 32)
                    love.graphics.setColor(255, 255, 255)
                end

                love.graphics.circle("line", x + 16, y + 16, 16, 32)
                love.graphics.printf(label, x, y + 3, 32, "center")
            end

            -- love.graphics.setColor(255, 50, 50)
            -- love.graphics.printf("Input overlay for gamepads not done", 0, 16, width - 16, "right")

            -- Draw the left stick
            local sdx = width - 32 - 32 - 8 - 32 - 8 - 32 - 24 - 32 - 16
            local sdy = 32 + 32

            love.graphics.setColor(150, 150, 150)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", sdx, sdy, 32, 64)

            local sx = joystick:getGamepadAxis("leftx")
            local sy = joystick:getGamepadAxis("lefty")
            local sd = math.sqrt(sx ^ 2 + sy ^ 2)
            sx = sx / sd
            sy = sy / sd
            local st = math.atan2(sy, sx)

            if sd > 0.2 then
                love.graphics.setInvertedStencil(function()
                    love.graphics.circle("fill", sdx, sdy, 32 * sd - 8, 64 * sd - 16)
                end)

                love.graphics.setColor(200, 200, 200)
                love.graphics.arc("fill", sdx, sdy, 32 * sd, st - math.pi / 4, st + math.pi / 4, 32 * sd * 2)
                love.graphics.setStencil()
            end

            love.graphics.setColor(150, 150, 150)
            love.graphics.setFont(self.strongFont)
            love.graphics.printf("Left", sdx - 32, 108, 64, "center")

            -- Draw the X/A/B buttons
            button(width - 32 - 32 - 8 - 32 - 8 - 32 + 8, 48, "X", joystick:isGamepadDown("x"))
            button(width - 32 - 32 - 8 - 32, 48 + 32, "A", joystick:isGamepadDown("a"))
            button(width - 32 - 32 - 8 - 32, 48 - 32, "Y", joystick:isGamepadDown("y"))
            button(width - 32 - 32 - 8, 48, "B", joystick:isGamepadDown("b"))
        else
            local function button(x, y, label, state)
                love.graphics.setFont(self.messageFont)
                love.graphics.setColor(150, 150, 150)
                love.graphics.setLineWidth(2)

                if state then
                    love.graphics.rectangle("fill", x, y, 32, 32)
                    love.graphics.setColor(255, 255, 255)
                end

                love.graphics.rectangle("line", x, y, 32, 32)
                love.graphics.printf(label, x, y + 3, 32, "center")
            end

            button(width - 32 - 32 - 8 - 32 - 8 - 32 - 24 - 32 - 8 - 32, 32, "Z", love.keyboard.isDown("z"))
            button(width - 32 - 32 - 8 - 32 - 8 - 32 - 24 - 32, 32, "X", love.keyboard.isDown("x"))
            button(width - 32 - 32 - 8 - 32 - 8 - 32, 32, "1", love.keyboard.isDown("kp1"))
            button(width - 32 - 32 - 8 - 32, 32, "2", love.keyboard.isDown("kp2"))
            button(width - 32 - 32, 32, "3", love.keyboard.isDown("kp3"))

            love.graphics.setColor(150, 150, 150)
            love.graphics.setFont(self.strongFont)
            love.graphics.printf("Numpad", width - 32 - 32 - 8 - 32 - 8 - 32, 72, 114, "center")
        end
    end

    -- love.graphics.setColor(255, 255, 255)
    -- love.graphics.print(love.timer.getFPS(), 2, 2)

    love.graphics.setShader()

    -- love.graphics.setColor(255, 255, 255)
    -- love.graphics.setLineWidth(1)
    --
    -- local y = height / 2
    --
    -- for i=1, 384 do
    --     local x = width / 2 - 192 + i + 0.5
    --     local n = math.floor(self:getFrequencyBucket(220) + i / 384 * (self:getFrequencyBucket(11025) - self:getFrequencyBucket(220)))
    --     love.graphics.line(x, 0, x, self.frequencies[n] * 2000)
    -- end

    -- for i = math.floor(self:getFrequencyBucket(220)), math.floor(math.min(self.frequencyCount, self:getFrequencyBucket(22050))) do
    --     local x = width / 2 - 192 + (i - math.floor(self:getFrequencyBucket(220))) + 0.5
    --     -- love.graphics.setColor(255, 255, 255, math.abs(value) * 10)
    --     love.graphics.line(x, 0, x, self.frequencies[i] * 720)
    -- end
end

return state
