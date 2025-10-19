--- @class (exact) lantern.Options
--- @field project_root_markers string[]
--- @field project_search_depth number
--- @field exclude_binary_directory_patterns string[]
--- @field exclude_configuration_name_patterns string[]
--- @field exclude_target_name_patterns string[]
--- @field run_task fun(table)?
--- @field client_name string

--- @class (exact) lantern.Target
--- @field name string
--- @field artifacts string[]

--- @class (exact) lantern.Configuration
--- @field name string
--- @field directory string
--- @field targets table<string, lantern.Target>
--- @field default_target string?

--- @class (exact) lantern.Project
--- @field name string
--- @field directory string
--- @field configurations table<string, lantern.Configuration>
--- @field default_configuration string?

--- @class (exact) lantern.State
--- @field current_project lantern.Project?
--- @field current_configuration_key string?
--- @field current_target_key string?

local json = require("lantern.json")
local presets = require("lantern.presets")

local M = {
  --- @type lantern.Options
  options = {
    scope = "global",

    project_root_markers = {"CMakePresets.json", "CMakeUserPresets.json", ".git"},
    project_search_depth = 2,
    exclude_binary_directory_patterns = {},
    exclude_configuration_name_patterns = {},
    exclude_target_name_patterns = {},

    run_task = nil,
    client_name = "lantern",
  },

  --- @type table
  state = {},
}

local function any_matches(value, patterns)
  for _, pattern in ipairs(patterns) do
    if value:match(pattern) then
      return true
    end
  end

  return false
end

--- @return lantern.State
local function state()
  local key = 1
  if M.options.scope == "window" then
    key = vim.api.nvim_get_current_win()
  elseif M.options.scope == "tab" then
    key = vim.api.nvim_get_current_tabpage()
  end

  if M.state[key] == nil then
    M.state[key] = {
      current_project = nil,
      current_configuration_key = nil,
      current_target_key = nil,
    }
  end

  return M.state[key]
end

--- @param build_directory string
--- @param target_json table
local function load_target(build_directory, target_json)
  local target = {
    name = target_json.name,
    artifacts = {},
  }

  for _, artifact in ipairs(target_json.artifacts or {}) do
    table.insert(target.artifacts, vim.fs.joinpath(build_directory, artifact.path))
  end

  return target
end

--- @param build_directory string
--- @param configuration_json table
local function load_configuration(build_directory, configuration_json)
  local configuration = {
    name = configuration_json.name,
    directory = build_directory,
    targets = {},
    default_target = nil,
  }

  local reply = vim.fs.joinpath(build_directory, ".cmake/api/v1/reply")
  for _, target_json in ipairs(configuration_json.targets) do
    local target = load_target(build_directory, json.read(vim.fs.joinpath(reply, target_json.jsonFile)))
    if not any_matches(target.name, M.options.exclude_target_name_patterns) then
      configuration.targets[target.name] = target
      if configuration.default_target == nil then
        configuration.default_target = target.name
      end
    end
  end

  return configuration
end

--- @param command_line table
local function default_run_task(command_line)
  local current_window = vim.api.nvim_get_current_win()
  vim.cmd("botright new")
  vim.fn.jobstart(command_line, {term = true})
  vim.cmd("normal! G")
  vim.api.nvim_set_current_win(current_window)
end

--- @param task string
M.run = function(task)
  local configuration = M.configuration()
  if configuration == nil then
    return
  end

  local target = M.target()
  if target == nil then
    return
  end

  local command_line = {"cmake"}
  if task == "clean" then
    vim.list_extend(command_line, {"--build", configuration.directory, "--target", "clean", "--config", configuration.name})
  elseif task == "build" then
    vim.list_extend(command_line, {"--build", configuration.directory, "--target", target.name, "--config", configuration.name})
  elseif task == "run" then
    command_line = {target.artifacts[1]}
  else
    vim.notify("Error: " .. task .. " is not a valid task.", vim.log.levels.ERROR)
    return
  end

  local runner = M.options.run_task or default_run_task
  runner(command_line)
end

--- @param directory string? The directory to initiate the scan from. If nil or empty, the current directory is used.
M.scan = function(directory)
  if directory == nil or #directory == 0 then
    directory = vim.uv.cwd() or vim.env.PWD
  else
    directory = vim.fs.abspath(directory)
  end

  directory = vim.fs.root(directory, M.options.project_root_markers)
  if directory ~= nil then
    M.load(directory)
  end
end

--- @param directory string? The directory to load. If nil or empty, the current directory will be used.
M.load = function(directory)
  if directory == nil or #directory == 0 then
    directory = vim.uv.cwd() or vim.env.PWD
  else
    directory = vim.fs.abspath(directory)
  end

  local project = {
    name = vim.fs.basename(directory),
    directory = directory,
    configurations = {},
    default_configuration = nil,
  }

  local presets_json = presets.load(project.directory)
  for _, preset in ipairs(presets_json or {}) do
    if not any_matches(preset.binary_directory, M.options.exclude_binary_directory_patterns) then
      local configuration = {
        name = preset.name,
        directory = preset.binary_directory,
        targets = {},
      }

      -- Configurations loaded by presets won't have any target information unless they are replaced, but they will have
      -- enough information to eventually enable a query to be written into them (and for the configure task to be run for
      -- them, thus generating reply information).
      project.configurations[configuration.name] = configuration
    end
  end

  local glob = project.directory
  for _ = 1, M.options.project_search_depth do
    glob = vim.fs.joinpath(glob, "*")
  end

  glob = vim.fs.joinpath(glob, "CMakeCache.txt")
  for _, path in ipairs(vim.fn.glob(glob, true, true)) do
    local binary_directory = vim.fs.dirname(path)
    if not any_matches(binary_directory, M.options.exclude_binary_directory_patterns) then
      local reply_directory = vim.fs.joinpath(binary_directory, ".cmake/api/v1/reply")
      local index_files = vim.fn.glob(vim.fs.joinpath(reply_directory, "index-*.json"), true, true)
      if #index_files > 0 then
        -- The CMake specification says that the largest index file in lexicographical order is the current file.
        table.sort(index_files, function (left, right) return left > right end)

        local index_json = json.read(index_files[1])
        local responses = vim.tbl_get(index_json, "reply", "client-" .. M.options.client_name, "query.json", "responses")
        for _, response in ipairs(responses or {}) do
          if response["kind"] == "codemodel" then
            local model_json = json.read(vim.fs.joinpath(reply_directory, response.jsonFile))
            for _, configuration_json in ipairs(model_json.configurations) do
              local configuration = load_configuration(binary_directory, configuration_json)
              if not any_matches(configuration.name, M.options.exclude_configuration_name_patterns) then
                project.configurations[configuration.name] = configuration
                if project.default_configuration == nil then 
                  project.default_configuration = configuration.name
                end
              end
            end
          end
        end
      end
    end
  end

  state().current_project = project
  M.set_configuration(project.default_configuration)
end

--- @return lantern.Project?
M.project = function()
  return state().current_project
end

--- @return lantern.Configuration?
M.configuration = function()
  local current_project = M.project()
  if current_project == nil then
    return nil
  end

  return current_project.configurations[state().current_configuration_key]
end

--- @param configuration string?
M.set_configuration = function(configuration)
  state().current_configuration_key = configuration
  if configuration ~= nil then
    state().current_target_key = M.configuration().default_target
  else
    state().current_target_key = nil
  end
end

--- @return lantern.Target?
M.target = function()
  local current_configuration = M.configuration()
  if current_configuration == nil then
    return nil
  end

  return current_configuration.targets[state().current_target_key]
end

--- @param target string?
M.set_target = function(target)
  state().current_target_key = target
end

--- @param options lantern.Options
M.setup = function(options)
  -- Ensure that calling setup() at different points with different values for the scope option produces defined
  -- behavior. The previous scope is cached here, and if changes after options are applied, Lantern's state is reset.
  local previous_scope = M.options.scope

  vim.validate("options", options, "table")
  M.options = vim.tbl_extend("keep", options, M.options)

  if M.options.scope ~= previous_scope then
    M.state = {}
  end
end

return M

