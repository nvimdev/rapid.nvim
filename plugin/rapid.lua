if vim.g.loaded_rapid then
  return
end

vim.g.loaded_rapid = true

local api = vim.api

api.nvim_set_hl(0, 'RapidComplete', { bold = true, fg = 'orange' })
api.nvim_set_hl(0, 'RapidTimeTaken', { bold = true, fg = 'violet' })
api.nvim_set_hl(0, 'RapidFile', { bold = true, fg = 'blue' })
api.nvim_set_hl(0, 'RapidTargetPos', { bold = true, fg = 'green' })

api.nvim_create_user_command('Rapid', function(args)
  require('rapid').compile(args)
end, {})

