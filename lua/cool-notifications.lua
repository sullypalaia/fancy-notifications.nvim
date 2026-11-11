local M = {}

function M.setup(opts)
  local pending = {}
  local active = false
  local show_next

  --redraw when using cmd line mode to prevent notifications from being frozen
  local function redraw_cmdline()
    if vim.api.nvim_get_mode().mode == "c" then
      vim.cmd.redraw()
    end
  end

  --fit text by screen columns, preserving multibyte characters.
  local function fit_text(text, width)
    local result = ""
    text = text:gsub("\t", "    ")
    for i = 0, vim.fn.strchars(text) - 1 do
      local next_text = result .. vim.fn.strcharpart(text, i, 1)
      if vim.fn.strdisplaywidth(next_text) > width then break end
      result = next_text
    end
    return result, vim.fn.strdisplaywidth(result)
  end

  --namespace for the border for highlighting use
  local border_ns = vim.api.nvim_create_namespace("notification-border")

  local function show_notification(msg, level, noti_opts, done)
    local labels = {
      [vim.log.levels.DEBUG] = "Debug",
      [vim.log.levels.ERROR] = "Error",
      [vim.log.levels.INFO] = "Info",
      [vim.log.levels.TRACE] = "Trace",
      [vim.log.levels.WARN] = "Warn"
    }

    --set the border color based on the log level
    local border_color = ""
    if level == vim.log.levels.DEBUG then
      border_color = "#3271a8"
    elseif level == vim.log.levels.ERROR then
      border_color = "#b53a46"
    elseif level == vim.log.levels.INFO then
      border_color = "#44cf38"
    elseif level == vim.log.levels.WARN then
      border_color = "#f8ff36"
    else
      border_color = "#5d28d1"
    end

    vim.api.nvim_set_hl(0, "BorderColors", { fg = border_color, bg = "NONE" })
    vim.api.nvim_set_hl(0, "NotificationsBackground", { bg = "NONE" })

    --find the dimensions of the notifications
    local width = math.max(3, math.min(72, vim.o.columns))
    local padding = math.min(3, math.floor((width - 3) / 2))
    local text_width = width - 2 - padding * 2
    local source = vim.split(msg, "\n", { plain = true })
    local available_height = math.max(3, vim.o.lines - vim.o.cmdheight)
    local text_height = math.min(#source, available_height - 2)
    local vertical_padding = math.min(2, math.floor((available_height - text_height - 2) / 2))
    local title, title_width = fit_text((labels[level] or "Warn") .. " Message", width - 2)
    local title_left = math.floor((width - 2 - title_width) / 2)
    local lines = {
      "┌" .. string.rep("─", title_left) .. title
      .. string.rep("─", width - 2 - title_width - title_left) .. "┐"
    }
    local blank = "│" .. string.rep(" ", width - 2) .. "│"
    for _ = 1, vertical_padding do lines[#lines + 1] = blank end
    for i = 1, text_height do
      local text, columns = fit_text(source[i], text_width)
      lines[#lines + 1] = "│" .. string.rep(" ", padding) .. text
          .. string.rep(" ", text_width - columns + padding) .. "│"
    end
    for _ = 1, vertical_padding do lines[#lines + 1] = blank end
    lines[#lines + 1] = "└" .. string.rep("─", width - 2) .. "┘"

    --draw the border in the buffer so it clips at the screen edge with the text.
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    for row, line in ipairs(lines) do
      local function highlight(first, last)
        vim.api.nvim_buf_set_extmark(buf, border_ns, row - 1, first, {
          end_col = last, hl_group = "BorderColors"
        })
      end
      if row == 1 or row == #lines then
        highlight(0, #line)
      else
        highlight(0, #"│")
        highlight(#line - #"│", #line)
      end
    end

    --create a window for the buffer
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      anchor = "NW",
      row = 0,
      col = math.max(0, vim.o.columns - width),
      width = math.min(width, vim.o.columns),
      height = #lines,
      style = "minimal",
      border = "none",
      focusable = false,
      hide = true,
      zindex = 50,
      noautocmd = true
    })
    vim.wo[win].winhighlight = "Normal:NotificationsBackground"
    vim.wo[win].winblend = 50
    vim.wo[win].wrap = false
    vim.wo[win].scrolloff = 0
    vim.wo[win].sidescrolloff = 0

    --duration and frame time for the animation
    local duration_ms, frame_ms = 1000, 16
    local finished = false
    local function finish()
      if finished then return end
      finished = true
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
      redraw_cmdline()
      done()
    end

    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = tostring(win),
      once = true,
      callback = function() vim.schedule(finish) end
    })

    local previous_col, previous_width, previous_height

    --function for rendering the notification window
    local function render(offset)
      if not vim.api.nvim_win_is_valid(win) then
        finish()
        return false
      end
      local col = math.max(0, vim.o.columns - width) + offset
      local visible_width = math.min(width, vim.o.columns - col)
      local height = math.max(1, math.min(#lines, vim.o.lines - vim.o.cmdheight))
      if col ~= previous_col or visible_width ~= previous_width or height ~= previous_height then
        if visible_width <= 0 then
          vim.api.nvim_win_set_config(win, { hide = true })
        else
          vim.api.nvim_win_set_config(win, {
            relative = "editor",
            anchor = "NW",
            hide = false,
            row = 0,
            col = col,
            width = visible_width,
            height = height
          })
        end
        previous_col, previous_width, previous_height = col, visible_width, height
        redraw_cmdline()
      end
      return true
    end

    --function for animating the notification window
    local function animate(entering, complete)
      local started = vim.uv.hrtime()
      local function tick()
        if finished then return end
        local elapsed_ms = (vim.uv.hrtime() - started) / 1e6
        local progress = math.min(1, elapsed_ms / duration_ms)
        local eased = 1 - (1 - progress) ^ 3
        local distance = math.min(width, vim.o.columns)
        local offset = entering and math.ceil(distance * (1 - eased)) or math.floor(distance * eased)
        if not render(offset) then return end
        if progress >= 1 then complete() else vim.defer_fn(tick, frame_ms) end
      end
      tick()
    end

    animate(true, function()
      vim.defer_fn(function()
        if not finished then animate(false, finish) end
      end, math.max(0, tonumber(opts.timeout) or 1000))
    end)
  end

  show_next = function()
    if active or #pending == 0 then return end
    active = true
    local item = table.remove(pending, 1)
    local message = item.msg
    if item.count > 1 then message = message .. " (×" .. item.count .. ")" end
    show_notification(message, item.level, item.opts, function()
      active = false
      vim.schedule(show_next)
    end)
  end

  --redefine vim.notify to use the new notification system
  vim.notify = function(msg, level, opts)
    local function enqueue()
      msg = tostring(msg)
      level = level or vim.log.levels.INFO
      opts = opts or {}
      local last = pending[#pending]
      if last and last.msg == msg and last.level == level and last.opts.timeout == opts.timeout then
        last.count = last.count + 1
      else
        pending[#pending + 1] = { msg = msg, level = level, opts = opts, count = 1 }
      end
      show_next()
    end
    --LSP and timer callbacks may arrive outside Neovim's main loop.
    if vim.in_fast_event() then vim.schedule(enqueue) else enqueue() end

    --save to message history
    vim.api.nvim_echo({ { msg, "Normal" } }, true, {})
  end
end

return M
