# fancy-notifications.nvim

## Overview

This plugin overrides Neovim's `vim.notify` function. Based on the value of `vim.log.levels`, the border of the window will use a different color to represent the log level. Additionally, the notification has animations for sliding on to and off of the editor.

## Installation

Assuming the plugin is in the _runtimepath_, the setup function can be called with `require("fancy-notifications").setup({...})` (or with your preferred plugin manager).  

## Features

Through `opts`, you can configure features:

- `debug_color`: the color used for debug notifications (default: `"#3271a8"`)
- `error_color`: the color used for error notifications (default: `"#b53a46"`)
- `info_color`: the color used for info notifications (default: `"#44cf38"`)
- `warn_color`: the color used for warning notifications (default: `"#f8ff36"`)
- `trace_color`: the color used for trace notifications (default: `"#5d28d1"`)
- `timeout`: the time in milliseconds before the notification is automatically closed (default: `1000`)

## AI Usage

AI was used to generate the animations for the notifications, as well as to resize the windows based on the contents of the notification. 
