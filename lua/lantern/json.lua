local M = {}

--- @param file string
--- @returns table
M.read = function(file)
  local text = vim.fn.join(vim.fn.readfile(file), "")
  return vim.json.decode(text)
end

return M

