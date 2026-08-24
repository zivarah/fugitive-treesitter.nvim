-- [nfnl] fnl/fugitive-treesitter/attach.fnl
local render = require("fugitive-treesitter.render")
local highlight = require("fugitive-treesitter.highlight")
local augroup = "fugitive-treesitter"
local generation_key = "fugitive_treesitter_generation"
local function next_generation(buf)
  local generation = (1 + (vim.b[buf][generation_key] or 0))
  vim.b[buf][generation_key] = generation
  return generation
end
local function stale_3f(buf, generation)
  return (not vim.api.nvim_buf_is_valid(buf) or (generation ~= vim.b[buf][generation_key]))
end
local function de_spam(f)
  local scheduled_3f = false
  local function _1_()
    if not scheduled_3f then
      scheduled_3f = true
      local function _2_()
        scheduled_3f = false
        return f()
      end
      return vim.schedule(_2_)
    else
      return nil
    end
  end
  return _1_
end
local function refresh(_3fbuf)
  local buf = (_3fbuf or vim.api.nvim_get_current_buf())
  return render.buffer(buf)
end
local function attach_diff(buf)
  local function _4_()
    if vim.api.nvim_buf_is_valid(buf) then
      return refresh(buf)
    else
      return nil
    end
  end
  return vim.schedule(_4_)
end
local function attach_status(buf)
  local generation = next_generation(buf)
  local rehighlight
  local function _6_()
    if vim.api.nvim_buf_is_valid(buf) then
      return refresh(buf)
    else
      return nil
    end
  end
  rehighlight = de_spam(_6_)
  local function on_lines()
    local stale = stale_3f(buf, generation)
    if not stale then
      rehighlight()
    else
    end
    return stale
  end
  vim.api.nvim_buf_attach(buf, false, {on_lines = on_lines})
  return rehighlight()
end
local attachers = {git = attach_diff, fugitive = attach_status}
local function attach(buf)
  local case_9_ = attachers[vim.api.nvim_get_option_value("filetype", {buf = buf})]
  if (nil ~= case_9_) then
    local attacher = case_9_
    return attacher(buf)
  else
    return nil
  end
end
local function attach_loaded()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      attach(buf)
    else
    end
  end
  return nil
end
local function highlighted_buffers()
  local tbl_26_ = {}
  local i_27_ = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local val_28_
    if (vim.api.nvim_buf_is_loaded(buf) and attachers[vim.api.nvim_get_option_value("filetype", {buf = buf})]) then
      val_28_ = buf
    else
      val_28_ = nil
    end
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function redraw_loaded()
  highlight.invalidate()
  for _, buf in ipairs(highlighted_buffers()) do
    refresh(buf)
  end
  return nil
end
local redraw = de_spam(redraw_loaded)
local function enable()
  do
    local group = vim.api.nvim_create_augroup(augroup, {clear = true})
    local function _14_(ev)
      return attach(ev.buf)
    end
    vim.api.nvim_create_autocmd("FileType", {group = group, pattern = vim.tbl_keys(attachers), callback = _14_})
    vim.api.nvim_create_autocmd("ColorScheme", {group = group, callback = redraw})
    vim.api.nvim_create_autocmd("OptionSet", {group = group, pattern = "background", callback = redraw})
  end
  return attach_loaded()
end
local function retire_listeners()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.b[buf][generation_key] then
      next_generation(buf)
    else
    end
  end
  return nil
end
local function disable()
  pcall(vim.api.nvim_del_augroup_by_name, augroup)
  retire_listeners()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      render.clear(buf)
    else
    end
  end
  return nil
end
return {refresh = refresh, redraw = redraw, enable = enable, disable = disable}
