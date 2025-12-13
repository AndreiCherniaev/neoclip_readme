--[[
    neoclip - Neovim clipboard provider
    Last Change:    2025 Dec 13
    License:        https://unlicense.org
    URL:            https://github.com/matveyt/neoclip
--]]


local function neo_check()
    local vim = vim
    local fn, h = vim.fn, vim.health or {
        start = require"health".report_start,
        info = require"health".report_info,
        ok = require"health".report_ok,
        warn = require"health".report_warn,
        error = require"health".report_error,
    }
    h.start"neoclip"

    if fn.has"clipboard" == 0 then
        h.error("Clipboard provider is disabled", {
            "Registers + and * will not work",
        })
        return
    end

    local neoclip = _G.package.loaded.neoclip
    if not neoclip then
        h.error("Not found", {
            "Do you |require()| it?",
            "Refer to |neoclip-build| on how to build from source code",
            "OS Windows, macOS and *nix (with X11 or Wayland) are supported",
        })
        return
    end

    local driver = neoclip.driver
    if not driver then
        h.error("No driver module loaded", neoclip.issues or {
            "Have you run |neoclip.setup()|?",
        })
        return
    end

    local clipboard_id = fn["provider#clipboard#Executable"]()
    local driver_id = driver.id()
    if clipboard_id == driver_id then
        h.ok(string.format("*%s* driver is in use", driver_id))

        local display = nil
        if vim.endswith(driver_id, "Wayland") then
            display = vim.env.WAYLAND_DISPLAY
        elseif vim.endswith(driver_id, "X11") then
            display = vim.env.DISPLAY
        end
        if display then
            h.info(string.format("Running on display `%s`", display))
        end
    else
        h.warn(string.format("*%s* driver is loaded but not properly registered",
            driver_id), {
            "Do not install another clipboard provider",
            "Check list of issues",
            "Try |neoclip.register()|",
        })
    end

    if not driver.status() then
        h.warn("Driver module stopped", {
            "|neoclip.driver.start()| to restart",
        })
    end

    if neoclip.issues then
        h.warn("Found issues", neoclip.issues)
    end

    local uv = vim.uv or vim.loop
    local now = tostring(uv.now())
    local reg_plus, line_plus = fn.getreginfo"+", "Red lorry, yellow lorry"
    local reg_star, line_star = fn.getreginfo"*", "Red leather, yellow leather"

    if not driver.set("+", { now, line_plus }, "\22") then
        h.warn"Driver failed to set register +"
    end
    if not driver.set("*", { now, line_star }, "\22") then
        h.warn"Driver failed to set register *"
    end

    -- for "cache_enabled" provider
    uv.sleep(200)

    local test_plus = fn.getreginfo"+"
    fn.setreg("+", reg_plus)
    fn.setreg("*", reg_star)

    if #test_plus.regcontents == 2 and test_plus.regcontents[1] == now and
        (test_plus.regcontents[2] == line_plus or test_plus.regcontents[2] == line_star)
        then
        h.ok"Clipboard test passed"

        if test_plus.regcontents[2] == line_star then
            h.info"NOTE registers + and * are always equal"
        end

        if test_plus.regtype:sub(1, 1) ~= "\22" then
            h.warn(string.format("Block type has been changed to %q", test_plus.regtype),
            {
                string.format("It looks like %s does not support Vim's native blocks",
                    clipboard_id),
            })
        end
    else
        h.error("Clipboard test failed", {
            "Sometimes, it happens because of `cache_enabled` setting",
            "Repeat |:checkhealth| again before reporting a bug",
        })
    end
end


return { check = neo_check }
