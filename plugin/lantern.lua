--- @param options string[]
--- @param prefix string
--- @return string[]
local function filter_options(options, prefix)
  return vim.iter(options):filter(function(option) return option:find(prefix) ~= nil end):totable()
end


local function command_config(command)
  local lantern = require("lantern")
  lantern.set_configuration(command.fargs[1])
end

local function complete_config(prefix)
  local project = require("lantern").project()
  if project ~= nil then
    local options = vim.tbl_keys(project.configurations)
    return filter_options(options, prefix)
  end

  -- There are no configurations available if no project is active.
  return {}
end

local function command_target(command)
  local lantern = require("lantern")
  lantern.set_target(command.fargs[1])
end

local function complete_target(prefix)
  local configuration = require("lantern").configuration()
  if configuration ~= nil then
    local options = vim.tbl_keys(configuration.targets)
    return filter_options(options, prefix)
  end

  -- There are no targets available if no configuration is active.
  return {}
end

vim.api.nvim_create_user_command("Config", command_config, {
  nargs = 1,
  complete = complete_config,
  desc = "Lantern: set configuration"
})

vim.api.nvim_create_user_command("Target", command_target, {
  nargs = 1,
  complete = complete_target,
  desc = "Lantern: set target"
})

