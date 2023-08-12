## Rapid.nvim

async build/run on neovim and more useful

![Untitled](https://github.com/nvimdev/rapid.nvim/assets/41671631/e3ae1afd-dad5-418c-9841-45cc9952831a)

## Requirement

neovim 0.10+

## Install

install with any plugin management or use `packadd`. then invoke `setup` function.

```lua
require('rapid').setup()
```

then bind a keymap for `rapid` by using `vim.keymap.set` 

```lua
vim.keymap.set('n', '<leader>r', '<cmd>Rapid<CR>')
```

## Options

- timeout  integer default is 10000
- open     string  default is `<CR>`

## Usage

support single and pipe commands like when using gcc

- single `Compile Command: gcc test.c`

- pipe `Compile Command: gcc test.c && ./a.out`

- '%' flag for current file like `Compile Command: gcc %`


## License MIT
