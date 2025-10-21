local M = {}

--- @param file string
--- @returns table
M.read = function(file)
  local text = vim.fn.join(vim.fn.readfile(file), "")
  return vim.json.decode(text)
end

--- @param file string
--- @param object table
M.write = function(file, object)
  local text = vim.json.encode(object)
  vim.fn.writefile({text}, file)
end

return M

