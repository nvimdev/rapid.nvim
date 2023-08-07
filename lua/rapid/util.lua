local M = {}

function M.has_file(lines, start)
  local f_pattern = '([%w/%._\\: -]+%.%w+)'
  local pos_pattern = '%d+:%d+'
  local range = {}
  for i, line in ipairs(lines) do
    local tmp = {}
    local spos, epos = line:find(f_pattern)
    if spos then
      tmp.file = { line = start + i, scol = spos, ecol = epos }
    end
    spos, epos = line:find(pos_pattern)
    if spos then
      tmp.targetPos = {
        line = start + i,
        scol = spos,
        ecol = epos,
      }
    end
    if vim.tbl_count(tmp) > 0 then
      range[#range + 1] = tmp
    end
  end
  return range
end

function M.date_fmt()
  return os.date('%a %b %H:%M:%S')
end

return M
