function love.conf(t)
    settings = {
        fullscreen = false,
        vsync = true,
        msaa = 8,
        ignoreGamepad = false,
        showInput = false
    }

    local file = "settings.lua"

    if love.filesystem.isFile(file) then
        local function patch(t, target)
            for key, value in pairs(t) do
                if type(value) == "table" and type(target[key]) == "table" then
                    patch(value, target[key])
                else
                    target[key] = value
                end
            end
        end

        local user = love.filesystem.load(file)()
        patch(user, settings)
    end

    t.console = not love.filesystem.isFused()

    t.window.title = "Placeholder"
    -- t.window.icon = ""
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 192 + 192
    t.window.minheight = 480
    t.window.fullscreen = settings.fullscreen
    t.window.fullscreentype = "desktop"
    t.window.vsync = settings.vsync
    t.window.fsaa = settings.fsaa
    t.window.highdpi = true
end
