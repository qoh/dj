local util = require "lib.util"
local ser = require "lib.ser"

local state = {}

function state:init()
    self.markerFont = love.graphics.newFont(12)
    self.timeFont = love.graphics.newFont(16)
    self.hitSound = love.audio.newSource("assets/Laser_Shoot12.wav")
    self.fadeSound = love.audio.newSource("assets/Hit_Hurt8.wav")
end

function state:enter(previous, filename, song, data)
    self.filename = filename
    -- self.song = love.filesystem.load(filename)()
    self.song = song

    -- self.audioData = love.sound.newSoundData("songs/" .. self.song.audio)
    self.audioData = data
    self.audioSource = love.audio.newSource(self.audioData)

    self.audioSource:play()
    self.audioSource:pause()

    self.lastPosition = 0

    self.mouseLane = nil
    self.mouseBeat = nil

    love.keyboard.setKeyRepeat(true)
end

function state:leave()
    love.keyboard.setKeyRepeat(false)
end

function state:pause()
    love.keyboard.setKeyRepeat(false)
    self.audioSource:pause()
end

function state:getPosition()
    local time = self.audioSource:tell("seconds") - (self.song.offset or 0)
    return time / (1 / (self.song.bpm / 60))
end

function state:seek(beats)
    local target = (self:getPosition() + beats) * (1 / (self.song.bpm / 60))
    local limit = self.audioData:getDuration("seconds")

    self.audioSource:seek(math.max(0, math.min(limit, target)))
    self.lastPosition = self:getPosition()
end

local BEAT_SCALE = 64

function state:getSelectedNote(limit)
    limit = limit or 0.25
    local index, selected, record

    for i, note in ipairs(self.song.notes) do
        if note[2] == self.mouseLane then
            local distance = math.abs(note[1] - self.mouseBeatSoft)

            if distance <= limit and (not record or distance < record) then
                index = i
                selected = note
                record = distance
            end
        end
    end

    return index, selected, record
end

function state:keypressed(key, unicode)
    if key == "escape" then
        gamestate.switch(states.menu)
    elseif key == " " then
        if self.audioSource:isPlaying() then
            self.audioSource:pause()
        else
            self.audioSource:play()
        end
    elseif key == "home" then
        self.audioSource:seek(self.audioData:getSampleCount() - 1, "samples")
        self.lastPosition = self:getPosition()
    elseif key == "end" then
        self.audioSource:seek(0)
        self.lastPosition = self:getPosition()
    elseif key == "pageup" then
        self:seek(10)
    elseif key == "pagedown" then
        self:seek(-10)
    elseif love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        if key == "s" then
            -- Prune juice
            local i = 1
            local f = 0

            while i <= #self.song.lanes do
                if self.song.lanes[i][2] == f then
                    table.remove(self.song.lanes, i)
                else
                    f = self.song.lanes[i][2]
                    i = i + 1
                end
            end

            table.sort(self.song.notes, function(a, b)
                return a[1] < b[1]
            end)

            self.song.length = self.audioData:getDuration()

            -- Write it out
            local real = love.filesystem.getRealDirectory(self.filename) .. "/" .. self.filename
            local file = io.open(real, "w")

            file:write(ser(self.song))
            file:close()

            print("Saved!")
        elseif key == "p" then
            gamestate.push(states.game, self.song, self.audioData, self:getPosition())
        end
    end
end

function state:mousepressed(x, y, button)
    if button == "l" then
        if self.mouseLane then
            -- Find the right position
            local index = #self.song.notes

            for i, note in ipairs(self.song.notes) do
                if note[1] > self.mouseBeat then
                    break
                end

                index = i
            end

            table.insert(self.song.notes, {self.mouseBeat, self.mouseLane})
        end
    elseif button == "r" then
        local index = self:getSelectedNote()

        if index then
            table.remove(self.song.notes, index)
        end
    elseif button == "wd" then
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            local index, note = self:getSelectedNote()

            if note and note[3] then
                if note[3] == 0 then
                    note[3] = nil
                else
                    note[3] = note[3] - 1
                end
            end
        else
            self:seek(1)
        end
    elseif button == "wu" then
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            local index, note = self:getSelectedNote()

            if note then
                if not note[3] then
                    note[3] = 1
                else
                    note[3] = note[3] + 1
                end
            end
        else
            self:seek(-1)
        end
    end
end

function state:update(dt)
    if self.audioSource:isStopped() then
        self.audioSource:play()
        self.audioSource:pause()
        self.audioSource:seek(self.audioData:getSampleCount() - 1, "samples")
        self.lastPosition = self:getPosition()
    end

    local kl = love.keyboard.isDown("left")
    local kr = love.keyboard.isDown("right")

    if kl and kr then
        kl, kr = false, false
    end

    if (kl and kr) or (not kl and not kr) then
        self.audioSource:setPitch(1)
    elseif kl then
        self.audioSource:setPitch(0.25)
    elseif kr then
        self.audioSource:setPitch(4)
    end

    local a = self.lastPosition
    local b = self:getPosition()

    self.lastPosition = b

    -- Play note hit sounds
    for i, note in ipairs(self.song.notes) do
        if a <= note[1] and b > note[1] then
            self.hitSound:clone():play()
            break
        end
    end

    -- Play lane switch sounds
    local last = 0

    for i, lane in ipairs(self.song.lanes) do
        if lane[2] ~= last and a <= lane[1] and b > lane[1] then
            self.fadeSound:clone():play()
            break
        end

        last = lane[2]
    end

    -- Update temporary note position
    local width, height = love.graphics.getDimensions()

    local lane = 3 + math.floor((love.mouse.getX() - width / 2) / 64 + 0.5)
    local beat = self:getPosition() + (height - 64 - love.mouse.getY()) / BEAT_SCALE

    self.mouseLane = math.max(1, math.min(5, lane))
    self.mouseBeat = math.max(0, beat)

    -- Snap to nearest half beat for now
    local snap = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 4 or 2

    if love.keyboard.isDown("lalt") then
        snap = snap * 0.5
    end

    self.mouseBeatSoft = self.mouseBeat
    self.mouseBeat = math.floor(self.mouseBeat * snap + 0.5) / snap

    -- Add lane changes
    if love.mouse.isDown("m") then
        local f_set = 0
        local f_legal = {[-1] = false, [0] = false, [1] = false}

        if self.mouseLane == 1 then
            f_set = -1
            f_legal[-1] = true
        elseif self.mouseLane == 5 then
            f_set = 1
            f_legal[1] = true
        else
            f_legal[0] = true

            if self.mouseLane == 2 then
                f_legal[1] = true
            elseif self.mouseLane == 4 then
                f_legal[-1] = true
            end
        end

        local i_prev, l_prev
        local i_next, l_next
        local i_self, l_self

        for i, lane in ipairs(self.song.lanes) do
            if lane[1] > self.mouseBeat then
                i_next = i
                l_next = lane
                break
            end

            if lane[1] == self.mouseBeat then
                i_self = i
                l_self = lane
            else
                i_prev = i
                l_prev = lane
            end
        end

        if i_self then
            if not f_legal[l_self[2]] then
                l_self[2] = f_set

                -- if i_next and l_next[2] == f_set then
                --     table.remove(self.song.lanes, i_next)
                -- end

                if (i_prev and l_prev[2] == f_set) or (not i_prev and f_set == 0) then
                    table.remove(self.song.lanes, i_self)
                end
            end
        elseif i_prev then
            if not f_legal[l_prev[2]] then
                table.insert(self.song.lanes, i_prev + 1, {self.mouseBeat, f_set})
            end
        elseif not f_legal[0] then
            table.insert(self.song.lanes, 1, {self.mouseBeat, f_set})
        end
    end
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

function state:draw()
    local width, height = love.graphics.getDimensions()
    local position = self:getPosition()

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

    local colorsByLane = {
        [1] = colors[1],
        [2] = colors[1],
        [3] = colors[2],
        [4] = colors[3],
        [5] = colors[3]
    }

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

        if y - offset * BEAT_SCALE < 0 then
            break
        end

        if offset <= 0 then
            vertices_left  = {lanes[fading == -1 and 1 or 2], y}
            vertices_right = {lanes[fading ==  1 and 5 or 4], y}
        elseif offset > 0 then
            -- Do we need to shift insert a point in the left lane?
            if (last_fading == -1 and fading ~= -1) or (last_fading ~= -1 and fading == -1) then
                table.insert(vertices_left,  lanes[last_fading == -1 and 1 or 2])
                table.insert(vertices_left,  y - offset * BEAT_SCALE)
                table.insert(vertices_left,  lanes[     fading == -1 and 1 or 2])
                table.insert(vertices_left,  y - offset * BEAT_SCALE)
            end

            if (last_fading ==  1 and fading ~=  1) or (last_fading ~=  1 and fading ==  1) then
                table.insert(vertices_right, lanes[last_fading ==  1 and 5 or 4])
                table.insert(vertices_right, y - offset * BEAT_SCALE)
                table.insert(vertices_right, lanes[     fading ==  1 and 5 or 4])
                table.insert(vertices_right, y - offset * BEAT_SCALE)
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

    -- Draw scratchboard
    love.graphics.setColor(30, 30, 30)
    love.graphics.rectangle("fill", x - 192, 0, 384, height)

    -- Draw beat lines
    local beatX1 = x - 192
    local beatX2 = x + 192

    love.graphics.setColor(255, 255, 255, 20)
    love.graphics.setLineWidth(1)

    love.graphics.push()
    love.graphics.translate(0, -64 * (1 - (position - math.floor(position))))

    for i=0, height / 64 do
        love.graphics.line(beatX1, height - i * 64, beatX2, height - i * 64)
    end

    love.graphics.pop()

    -- Lane helpers
    for i=1, 5 do
        love.graphics.line(lanes[i], 0, lanes[i], y)
    end

    -- Draw controls for fading and notes
    love.graphics.setLineWidth(2)
    draw_fader_back(lanes[1], y)
    draw_fader_back(lanes[4], y)
    --draw_button(lanes[1] + 64, y, nil, colors[1])
    draw_button(lanes[3]     , y, nil, colors[2])
    --draw_button(lanes[4] +  0, y, nil, colors[3])

    -- Draw lanes
    local beat_strength = 1 - (position / 2 - math.floor(position / 2))
    beat_strength = beat_strength ^ 2

    love.graphics.setLineWidth(2 + 2 * beat_strength)
    love.graphics.setColor(colors[2])
    love.graphics.line(vertices_mid)

    love.graphics.setLineWidth(2 + 2 * beat_strength)
    love.graphics.setColor(colors[1])
    love.graphics.line(vertices_left)

    love.graphics.setLineWidth(2 + 2 * beat_strength)
    love.graphics.setColor(colors[3])
    love.graphics.line(vertices_right)

    -- Draw lane switches
    local last_beat
    local last_fade = 0

    for i, lane in ipairs(self.song.lanes) do
        local offset = lane[1] - position

        if offset >= 0 and lane[2] ~= last_fade then
            if lane[1] == last then
                love.graphics.setColor(255, 0, 0)
                love.graphics.setLineWidth(4)
            else
                love.graphics.setColor(255, 0, 255)
                love.graphics.setLineWidth(1)
            end

            love.graphics.line(x - 192, y - offset * BEAT_SCALE, x + 192, y - offset * BEAT_SCALE)
        end

        last_beat = lane[1]
        last_fade = lane[2]
    end

    -- Draw notes
    for i, note in ipairs(self.song.notes) do
        local offset = note[1] - position

        if note[3] then
            local last = offset + note[3]

            if last >= 0 then
                local color = colorsByLane[note[2]]
                local length = note[3]

                if offset < 0 then
                    length = length + offset
                    offset = 0
                end

                love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
                love.graphics.circle("fill", lanes[note[2]], y - last * BEAT_SCALE, 16, 32)
                love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                love.graphics.circle("line", lanes[note[2]], y - last * BEAT_SCALE, 16, 32)
                love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
                love.graphics.rectangle("fill", lanes[note[2]] - 16, y - last * BEAT_SCALE, 32, length * BEAT_SCALE)
                love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                love.graphics.line(lanes[note[2]] - 16, y - last * BEAT_SCALE, lanes[note[2]] - 16, y - offset * BEAT_SCALE)
                love.graphics.line(lanes[note[2]] + 16, y - last * BEAT_SCALE, lanes[note[2]] + 16, y - offset * BEAT_SCALE)
                love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
                love.graphics.circle("fill", lanes[note[2]], y - offset * BEAT_SCALE, 16, 32)
                love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
                love.graphics.circle("line", lanes[note[2]], y - offset * BEAT_SCALE, 16, 32)
            end
        elseif offset >= 0 then
            local color = colorsByLane[note[2]]

            love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65)
            love.graphics.circle("fill", lanes[note[2]], y - offset * BEAT_SCALE, 16, 32)
            love.graphics.setColor(color[1] * 0.10, color[2] * 0.10, color[3] * 0.10)
            love.graphics.circle("line", lanes[note[2]], y - offset * BEAT_SCALE, 16, 32)
        end
    end

    -- Draw temporary note
    if self.mouseLane then
        local color = colorsByLane[self.mouseLane]
        local offset = self.mouseBeat - position

        love.graphics.setColor(color[1], color[2], color[3], 127 + 48 * math.sin(love.timer.getTime() * 5))
        love.graphics.circle("fill", lanes[self.mouseLane], y - offset * BEAT_SCALE, 8, 16)
        love.graphics.setColor(255, 255, 255)
        love.graphics.print(self.mouseBeat, lanes[self.mouseLane], y - offset * BEAT_SCALE)
    end

    local bw = width - 16
    local bh = 16
    local bx = 8
    local by = height - bh - 8

    local position = self.audioSource:tell()
    local duration = self.audioData:getDuration()
    local progress = position / duration

    love.graphics.setColor(80, 80, 80)
    love.graphics.rectangle("fill", bx, by, bw, bh)
    love.graphics.setColor(255, 255, 255)
    love.graphics.printf(util.secondsToTime(math.ceil(duration)), bx, by + 1, bw - 2, "right")
    love.graphics.setColor(200, 255, 200)

    local scaled = math.floor(bw * progress)
    love.graphics.rectangle("fill", bx, by, scaled, bh)

    if scaled > 2 then
        love.graphics.setStencil(function()
            love.graphics.rectangle("fill", bx, by, scaled, bh)
        end)

        love.graphics.setColor(40, 40, 40)
        love.graphics.printf(util.secondsToTime(math.floor(position)), bx, by + 1, scaled - 2, "right")

        love.graphics.setStencil()
    end
end

return state
