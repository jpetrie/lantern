local M = {}

local json = require("lantern.json")

--- @param string string
--- @param macros table<string, string>
--- @return string
local function apply_macros(string, macros)
  local result = string
  for key, value in pairs(macros) do
    result = result:gsub("${" .. key .. "}", value)
  end

  return result
end

--- @param presets_path string
--- @param macros table<string, string>
--- @return table
local function load_presets(presets_path, macros)
  local presets_json = json.read(presets_path)
  local result = {}
  for _, configure_preset in ipairs(presets_json.configurePresets) do
    if not configure_preset.hidden then
      local item = {
        name = configure_preset.name,
        binary_directory = apply_macros(configure_preset.binaryDir, macros),
      }

      table.insert(result, item)
    end
  end

  return result
end

--- @param directory string
--- @return table?
M.load = function(directory)
  vim.validate("directory", directory, "string")
  directory = vim.fs.abspath(directory)

  local presets_path = vim.fs.joinpath(directory, "CMakePresets.json")
  if vim.fn.filereadable(presets_path) == 0 then
    return nil
  end

  -- See https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#macro-expansion for additional detail.
  -- Currently, only a subset of macros are supported.
  local macros = {
    sourceDir = directory,
    sourceParentDir = vim.fs.dirname(directory),
    sourceDirName = vim.fs.basename(directory),
  }

  return load_presets(presets_path, macros)
end

return M

