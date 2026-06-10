local M = {}

M.check = function()
  local lantern = require("lantern")

  vim.health.start("Dependencies")
  local cmake_exe = vim.fn.exepath("cmake")
  if #cmake_exe > 0 then
    vim.health.ok("Found CMake: " .. cmake_exe)
  else
    vim.health.error("Could not find CMake.")
  end

  vim.health.start("Configuration")
  if lantern.options.log_file ~= nil then
    vim.health.ok("Logging to: " .. vim.fs.abspath(lantern.options.log_file))
  else
    vim.health.info("Logging not enabled.")
  end

  vim.health.start("Active Project")
  local project = lantern.project()
  if project ~= nil then
    vim.health.ok(project.name)
  else
    vim.health.info("No active project.")
  end
end

return M

