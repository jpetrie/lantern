local M = {}

local json = require("lantern.json")

--- @param macros table<string, string>
--- @param string string?
--- @return string?
local function apply_macros(macros, string)
  if string == nil then
    return nil
  end

  local result = string
  for key, value in pairs(macros) do
    result = result:gsub("${" .. key .. "}", value)
  end

  return result
end

--- @param presets_path string
--- @param macros table<string, string>
--- @param results table
local function load_presets(presets_path, macros, results)
  local presets_json = json.read(presets_path)
  for _, configure_preset in ipairs(presets_json.configurePresets) do
    -- None of these initial values can be inherited, so they can be set here.
    local result = {
      name = configure_preset.name,
      hidden = configure_preset.hidden,
      inherits = configure_preset.inherits,
      description = configure_preset.description,
      displayName = configure_preset.displayName,
    }

    if result.inherits ~= nil and vim.tbl_contains(results, result.inherits) then
      result = vim.tbl_deep_extend("keep", results[result.inherits])
    end

    result.binary_directory = apply_macros(macros, configure_preset.binaryDir or result.binary_directory)
    table.insert(results, result)
  end
end

--- @param directory string
--- @return table
M.load = function(directory)
  vim.validate("directory", directory, "string")
  directory = vim.fs.abspath(directory)

  -- See https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#macro-expansion for additional detail.
  -- Currently, only a subset of macros are supported.
  local macros = {
    sourceDir = directory,
    sourceParentDir = vim.fs.dirname(directory),
    sourceDirName = vim.fs.basename(directory),
  }

  local results = {}
  local preset_names = { "CMakePresets.json", "CMakeUserPresets.json" }
  for _, preset_name in ipairs(preset_names) do
    local presets_path = vim.fs.joinpath(directory, preset_name)
    if vim.fn.filereadable(presets_path) ~= 0 then
      load_presets(presets_path, macros, results)
    end
  end

  return results
end

return M
