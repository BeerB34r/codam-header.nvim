---@tag codamheader.header

---@brief [[
---
---This module manages the header.
---
---@brief ]]

local M = {}
local config = require "codamheader.config"
local git = require "codamheader.utils.git"

---Get username.
---@return string|nil
function M.user()
  return vim.g.user or (config.opts.git.enabled and git.user()) or config.opts.user
end

---Get email.
---@return string|nil
function M.email()
  return vim.g.mail or (config.opts.git.enabled and git.email()) or config.opts.mail
end

---Get left and right comment symbols from the buffer.
---@return string, string
function M.comment_symbols()
  local str = vim.api.nvim_get_option_value("commentstring", { scope = "local", buf = 0 })

  -- Checks the buffer has a valid commentstring.
  if str:find "%%s" then
    local left, right = str:match "(.*)%%s(.*)"

    if right == "" then
      right = left
    end

    return vim.trim(left), vim.trim(right)
  end

  return "#", "#" -- Default comment symbols.
end

---Generate a formatted text line for the header.
---@param text string: The text to include in the line.
---@param ascii string: The ASCII art for the line.
---@return string: The formatted header line.
function M.gen_line(text, ascii)
  local max_length = config.opts.length - config.opts.margin * 2 - #ascii

  text = (text):sub(1, max_length)

  local left, right = M.comment_symbols()
  local left_margin = (" "):rep(config.opts.margin - #left)
  local right_margin = (" "):rep(config.opts.margin - #right)
  local spaces = (" "):rep(max_length - #text)

  return left .. left_margin .. text .. spaces .. ascii .. right_margin .. right
end


---generate extended ascii art
---@param ascii table: a table of strings to be turned into ascii art
---@return table: a table containing all lines of extended ascii art
function M.gen_ascii(ascii)
	local extended_ascii = {}
	local left, right = M.comment_symbols()
	local left_margin = (" "):rep(config.opts.margin - #left)
	local right_margin  = (" "):rep(config.opts.margin - #right)
	local left_justified = config.opts.exascii_left

	for _, value in pairs(ascii) do
		local spaces = (" "):rep((config.opts.length - vim.str_utfindex(value)) - config.opts.margin * 2)
		if left_justified then
			table.insert(extended_ascii, left .. left_margin .. value .. spaces .. right_margin .. right)
		else
			table.insert(extended_ascii, left .. left_margin .. spaces .. value .. right_margin .. right)
		end
		if (vim.str_utfindex(extended_ascii[#extended_ascii]) > config.opts.length) then
			vim.notify("Extended ascii art too wide", vim.log.levels.WARN, { title = "Codam Header" })
			return nil
		end
	end

	return extended_ascii
end

---Generate a complete header.
---@return table: A table ontaining all lines of header.
function M.gen_header()
  local ascii = config.opts.asciiart
  local left, right = M.comment_symbols()
  local fill_line = left .. " " .. string.rep("*", config.opts.length - #left - #right - 2) .. " " .. right
  local empty_line = M.gen_line("", "")
  local date = os.date "%Y/%m/%d %H:%M:%S"

	local extended_ascii = M.gen_ascii(config.opts.exascii)

	local out = {
    fill_line,
    empty_line,
    M.gen_line("", ascii[1]),
    M.gen_line(vim.fn.expand "%:t", ascii[2]),
    M.gen_line("", ascii[3]),
    M.gen_line("By: " .. M.user() .. " <" .. M.email() .. ">", ascii[4]),
    M.gen_line("", ascii[5]),
    M.gen_line("Created: " .. date .. " by " .. M.user(), ascii[6]),
    M.gen_line("Updated: " .. date .. " by " .. M.user(), ascii[7]),
    empty_line,
  }
	for _, value in pairs(extended_ascii) do
		table.insert(out, value)
	end
	table.insert(out, fill_line)
	return out
end

---Checks if there is a valid header in the current buffer.
---@param header table: The header to compare with the contents of the existing buffer.
---@return boolean: `true` if the header exists, `false` otherwise.
function M.has_header(header)
  local lines = vim.api.nvim_buf_get_lines(0, 0, #header, false)

  -- Immutable lines that are used for checking.
  for _, v in pairs { 1, 2, 3, 10, #header } do
    if header[v] ~= lines[v] then
      return false
    end
  end

  return true
end

---Insert a header into the current buffer.
---@param header table: The header to insert.
function M.insert_header(header)
  if not vim.api.nvim_get_option_value("modifiable", { buf = 0 }) then
    vim.notify("The current buffer cannot be modified.", vim.log.levels.WARN, { title = "Codam Header" })
    return
  end
  -- If the first line is not empty, the blank line will be added after the header.
  if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= "" then
    table.insert(header, "")
  end

  vim.api.nvim_buf_set_lines(0, 0, 0, false, header)
end

---Update an existing header in the current buffer.
---@param header table: Header to override the current one.
function M.update_header(header)
  local immutable = { 6, 8 }

  -- Copies immutable lines from existing header to updated header.
  for _, value in ipairs(immutable) do
    header[value] = vim.api.nvim_buf_get_lines(0, value - 1, value, false)[1]
  end

  vim.api.nvim_buf_set_lines(0, 0, #header, false, header)
end

---Inserts or updates the header in the current buffer.
function M.stdheader()
  local header = M.gen_header()
  if not M.has_header(header) then
    M.insert_header(header)
  else
    M.update_header(header)
  end
end

return M
