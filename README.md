# cool-notifications.nvim

## Overview

This plugin overrides Neovim's `vim.notify` function. Based on the value of `vim.log.levels`, the border of the window will use a different color to represent the log level. Additionally, the notification has animations for sliding on to and off of the editor.

## Installation

Assuming the plugin is in the _runtimepath_, the setup function can be called with `require("cool-notifications").setup({})` (or with your preferred plugin manager). Currently, there are no available options, but support for customization will be added in future updates.  

## AI Usage

AI was used to generate the animations for the notifications, as well as to resize the windows based on the contents of the notification. 
