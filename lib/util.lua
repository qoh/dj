local util = {}

function util.secondsToTime(seconds)
    local minutes = math.floor(seconds / 60)
    seconds = tostring((seconds - minutes * 60))

    if #seconds == 0 then
        seconds = "00"
    elseif #seconds == 1 then
        seconds = "0" .. seconds
    end

    return minutes .. ":" .. seconds
end

function util.addSeparators(value)
    value = tostring(math.floor(value))

    local result = ""
    local i = #value - 2

    while i >= 2 do
        result = "," .. value:sub(i, i + 2) .. result
        i = i - 3
    end

    return value:sub(1, i + 2) .. result
end

function util.undulo(segments)
    local result = {}

    for i=1, #segments-2, 2 do
        local x1 = segments[i]
        local y1 = segments[i + 1]
        local x2 = segments[i + 2]
        local y2 = segments[i + 3]

        local length = math.sqrt((x2-x1)^2 + (y2-y1)^2)
        local wiggle = length / 32

        table.insert(result, x1)
        table.insert(result, y1)

        local cx = (x1 + x2) / 2
        local cy = (y1 + y2) / 2

        local rx = cx + (love.math.noise(0, love.timer.getTime() * 6.0) - 0.5) * wiggle
        local ry = cy + (love.math.noise(love.timer.getTime() * 6.0, 0) - 0.5) * wiggle

        table.insert(result, rx)
        table.insert(result, ry)
    end

    table.insert(result, segments[#segments - 1])
    table.insert(result, segments[#segments])

    return result
end

function util.cutLine(segments, fraction)
    local length = 0

    for i=1, #segments-2, 2 do
        local x1 = segments[i]
        local y1 = segments[i + 1]
        local x2 = segments[i + 2]
        local y2 = segments[i + 3]

        length = length + math.sqrt((x2-x1)^2 + (y2-y1)^2)
    end

    local result = {}

    local limit = length * fraction
    local accum = 0

    for i=1, #segments-2, 2 do
        if accum >= limit then
            break
        end

        local x1 = segments[i]
        local y1 = segments[i + 1]
        local x2 = segments[i + 2]
        local y2 = segments[i + 3]

        local dx = x2 - x1
        local dy = y2 - y1

        local piece = math.sqrt(dx^2 + dy^2)

        table.insert(result, x1)
        table.insert(result, y1)

        if accum + piece > limit then
            local left = limit - accum
            table.insert(result, x1 + dx / piece * left)
            table.insert(result, y1 + dy / piece * left)
        end

        accum = accum + piece
    end

    if accum <= limit then
        table.insert(result, segments[#segments - 1])
        table.insert(result, segments[#segments])
    end

    return result
end

return util
