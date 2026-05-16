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

  vim.health.start("Active Project")
  local project = lantern.project()
  if project ~= nil then
    vim.health.ok(project.name)
  else
    vim.health.info("No active project.")
  end
end

return M

