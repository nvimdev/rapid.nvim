local uv, api, lsp = vim.uv, vim.api, vim.lsp
local util = require('rapid.util')
local buf_add_highlight, buf_set_lines = api.nvim_buf_add_highlight, api.nvim_buf_set_lines
local buf_set_extmark = api.nvim_buf_set_extmark
local M = {}
local ns = api.nvim_create_namespace('Rapid')

local function root_dir()
  local curbuf = api.nvim_get_current_buf()
  local clients = lsp.get_clients({ bufnr = curbuf })
  if #clients == 0 then
    return uv.cwd()
  end
  return vim.iter(clients):find(function(client)
    return client.config.root_dir
  end).config.root_dir
end

_G.rapid_complete = function(arglead, _)
  local root = root_dir()
  local beforelead = string.match(arglead, '^.*%s+') or ''
  local pattern = '%.git'
  local files = vim.fs.find(function(name, path)
    return not name:match('pattern') and not path:match(pattern)
  end, {
    path = root,
    limit = math.huge,
    type = 'file',
  })

  files = vim
    .iter(files)
    :map(function(item)
      return item:sub(#root + 2)
    end)
    :totable()

  return vim.tbl_map(function(cand)
    return beforelead .. cand
  end, files)
end

local function create_win()
  local user_define = vim.opt.splitbelow
  vim.opt.splitbelow = true
  vim.cmd.split('compile')
  vim.opt.splitbelow = user_define
  M.buf, M.win = api.nvim_get_current_buf(), api.nvim_get_current_win()
  api.nvim_set_option_value('buftype', 'nofile', { buf = M.buf })
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = M.buf })
  api.nvim_set_option_value('filetype', 'rapid', { buf = M.buf })
end

local function update_buf(data)
  if data then
    local lines = vim.split(data, '\n')
    vim.schedule(function()
      if not M.win or not api.nvim_win_is_valid(M.win) then
        create_win()
      end
      --clean buffer first there may already have a output buffer.
      buf_set_lines(M.buf, 0, -1, false, {})
      local start = api.nvim_buf_line_count(M.buf)
      if start == 1 and #api.nvim_buf_get_lines(M.buf, 0, -1, false)[1] == 0 then
        start = start - 1
      end
      buf_set_lines(M.buf, start, -1, false, lines)
      local range = util.has_file(lines, start)
      if vim.tbl_count(range) == 0 then
        return
      end
      M.range = vim.list_extend(M.range, range)
      for _, item in ipairs(range) do
        if item.file then
          buf_add_highlight(
            M.buf,
            0,
            'RapidFile',
            item.file.line - 1,
            item.file.scol - 1,
            item.file.ecol
          )

          if item.targetPos then
            buf_add_highlight(
              M.buf,
              0,
              'RapidTargetPos',
              item.targetPos.line - 1,
              item.targetPos.scol - 1,
              item.targetPos.ecol
            )
          end
        end
      end
    end)
  end
end

local function apply_map(mainwin)
  vim.keymap.set('n', M.opt.open, function()
    local row, col = unpack(api.nvim_win_get_cursor(M.win))
    for _, range in ipairs(M.range) do
      if
        range.file
        and range.file.line == row
        and col >= range.file.scol - 1
        and col <= range.file.ecol
      then
        local fname = api.nvim_buf_get_text(
          M.buf,
          row - 1,
          range.file.scol - 1,
          row - 1,
          range.file.ecol,
          {}
        )[1]
        local targetpos
        if range.targetPos then
          targetpos = api.nvim_buf_get_text(
            M.buf,
            row - 1,
            range.targetPos.scol - 1,
            row - 1,
            range.targetPos.ecol,
            {}
          )[1]
        end
        api.nvim_set_current_win(mainwin)
        vim.cmd.edit(fname)
        if targetpos then
          local lnum, lcol = targetpos:match('(%d+).(%d+)')
          api.nvim_win_set_cursor(0, { tonumber(lnum), tonumber(lcol) - 1 })
        end
        return
      end
    end
  end, { buffer = M.buf })
end

local function clean()
  api.nvim_create_autocmd('BufWipeout', {
    buffer = M.buf,
    callback = function()
      M.buf, M.winid, M.range = nil, nil, nil
    end,
  })
end

local function on_confirm(input)
  if not input or #input == 0 then
    return
  end
  --TODO: need support pipe also?
  local cmds = vim.split(input, '&&')
  local root = root_dir()
  local cur_fname = api.nvim_buf_get_name(0)
  local now = uv.hrtime()
  local mainwin = api.nvim_get_current_win()
  coroutine.resume(coroutine.create(function()
    local co = coroutine.running()
    for i, cmd in ipairs(cmds) do
      vim.system(
        vim
          .iter(vim.gsplit(cmd, '%s', { trimempty = true }))
          :map(function(item)
            return item == '%' and cur_fname or item
          end)
          :totable(),
        {
          text = true,
          stdin = false,
          stdout = function(_, data)
            update_buf(data)
          end,
          stderr = function(_, data)
            update_buf(data)
          end,
          cwd = root,
        },
        function(obj)
          coroutine.resume(co)
          if i == #cmds then
            local date = util.date_fmt()
            --TODO: better message when have exit signal
            vim.schedule(function()
              buf_set_lines(M.buf, -1, -1, false, { 'Finished' })
              local last = api.nvim_buf_line_count(M.buf)
              buf_add_highlight(M.buf, 0, 'RapidFinished', last - 1, 0, -1)
              buf_set_extmark(M.buf, ns, last - 1, 0, {
                virt_text = {
                  { 'at ' },
                  { date, 'RapidDate' },
                  { ' took ' },
                  { uv.hrtime() - now / 1e6 .. 'ms', 'RapidTake' },
                },
                virt_text_pos = 'eol',
                hl_mode = 'combine',
              })
              vim.bo[M.buf].modifiable = false
              apply_map(mainwin)
            end)
          end
        end
      )
      coroutine.yield()
    end
    api.nvim_set_option_value('modifiable', false, { buf = M.buf })
    clean()
  end))
end

function M.compile()
  vim.ui.input({
    prompt = '> Run Command: ',
    completion = 'customlist,v:lua.rapid_complete',
    highlight = function(input)
      return { { 0, #input, 'String' } }
    end,
  }, on_confirm)
end

local function setup(opt)
  M.opt = vim.tbl_extend('force', opt or {}, {
    timeout = 1000,
    open = '<CR>',
  })
  M.range = {}
end

return setmetatable({
  setup = setup,
}, {
  __index = function(_, k)
    if k == 'compile' then
      return M.compile
    end
  end,
})
