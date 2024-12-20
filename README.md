# Treesitter Jump

![Van Halen Jump Image](assets/jump.jpg)

## Features

- **Bracket Matching**: Jump between matching opening and closing brackets (`()`, `{}`, `[]`, `<>`).
- **Language Constructs Navigation**: Navigate between language-specific blocks like `if`/`else`/`end` in Lua, `if`/`elif`/`else` in Python, and more.
- **Customizable Language Support**: Add or customize support for other languages and their specific syntax structures.

## Languages

- Bash
- Fish
- Lua
- Python
- Zsh

Any bracket / brace language including C, C++, Rust, etc.

## Installation

### Using [lazy.nvim](https://lazy.folke.io)

```lua
{
    "dsully/treesitter-jump.nvim",
    keys = {
        -- stylua: ignore
        { "%", function() require("treesitter-jump").jump() end },
    },
    opts = {},
},
```

## Requirements

- Neovim 0.10 or higher
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) plugin installed and configured for the languages you use.

## Configuration

You can configure the plugin by calling the `setup` function in your Lua configuration file:

```lua
require('treesitter-jump').setup({
    language_pairs = {
        -- Customize language-specific pairs
        lua = {
            ["for"] = {
                ending = "end",
                middle = {},
            },
            -- Add more Lua configurations if needed
        },
        -- Add support for other languages
        javascript = {
            ["if"] = {
                ending = "}",
                middle = {
                    ["else"] = true,
                },
            },
        },
    },
})
```
