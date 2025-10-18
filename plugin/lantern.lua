local commands = {
  config = {
    callback = function(arguments) require("lantern").set_configuration(arguments[1]) end,
    completion = function(prefix)
      local options = vim.tbl_keys(require("lantern").project().configurations)
      return vim.iter(options):filter(function(option) return string.find(option, prefix) ~= nil end):totable()
    end
  },

  target = {
    callback = function(arguments) require("lantern").set_target(arguments[1]) end,
    completion = function(prefix)
      local configuration = require("lantern").configuration()
      if configuration ~= nil then
        local options = vim.tbl_keys(configuration.targets)
        return vim.iter(options):filter(function(option) return string.find(option, prefix) ~= nil end):totable()
      end
    end
  },
}

local function lantern_command(command)
  local arguments = command.fargs
  local action = arguments[1]
  local definition = commands[action]
  if definition ~= nil and definition.callback ~= nil then
    definition.callback(vim.list_slice(arguments, 2, #arguments))
  else
    vim.notify("Lantern: Unknown action: " .. action, vim.log.levels.ERROR)
  end
end

local function lantern_complete(prefix, command, _)
  local action, argument_prefix = string.match(command, "^['<,'>]*Lantern[!]*%s(%S+)%s(.*)$")
  if action ~= nil and argument_prefix ~= nil then
    local entry = commands[action]
    if entry ~= nil and entry.completion ~= nil then
      return entry.completion(argument_prefix)
    end
  end

  if string.match(command, "^['<,'>]*Lantern[!]*%s+%w*$") then
    local keys = vim.tbl_keys(commands)
    return vim.iter(keys):filter(function(key) return string.find(key, prefix) ~= nil end):totable()
  end
end

vim.api.nvim_create_user_command("Lantern", lantern_command, {
  nargs = "+",
  complete = lantern_complete,
  desc = "Control Lantern",
})

