local util = {}

function util.filepath(file)
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

function util.addSeparators(value, forceFraction)
    plain = tostring(math.abs(math.floor(value)))

    local result = ""
    local i = #plain - 2

    while i >= 2 do
        result = "," .. plain:sub(i, i + 2) .. result
        i = i - 3
    end

    result = plain:sub(1, i + 2) .. result

    if value < 0 then
        result = "-" .. result
    end

    local fraction = value - math.floor(value)

    if fraction > 0 then
        result = result .. tostring(fraction):sub(2)
    elseif forceFraction then
        result = result .. ".0"
    end

    return result
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

function util.hsvToRgb(h, s, v, a)
    local r, g, b

    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end

    return r * 255, g * 255, b * 255, (a or 1) * 255
end

function util.printc(text, x, y)
    local font = love.graphics.getFont()
    x = x - love.window.fromPixels(font:getWidth(text)) / 2
    y = y - love.window.fromPixels(font:getHeight(text)) / 2
    love.graphics.print(text, love.window.toPixels(x, y))
end

function util.imageFill(image)
    local sw, sh = love.window.toPixels(love.graphics.getDimensions())
    local iw, ih = love.window.fromPixels(image:getDimensions())
    local scale = math.max(sw / iw, sh / ih)

    iw = iw * scale
    ih = ih * scale

    love.graphics.draw(image,
        love.window.toPixels(sw / 2 - iw / 2),
        love.window.toPixels(sh / 2 - ih / 2),
        0, scale, scale)
end

return util
