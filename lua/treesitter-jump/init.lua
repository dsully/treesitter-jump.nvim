local M = {}

local config = require("treesitter-jump.config")

--- Setup function to configure plugin
--- @param opts table
function M.setup(opts)
    config.setup(opts)
end

--- Main jump function
function M.jump()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

    local node, text = require("treesitter-jump.tree").get_node_at_pos(bufnr, row, col)

    if not node then
        return
    end

    local languages = require("treesitter-jump.languages")

    -- Handle brackets
    if require("treesitter-jump.tree").bracket_set()[text] then
        languages.handle_brackets(node, bufnr, text)
        return
    end

    languages.handle_language(node, bufnr, row, col, ft)
end

return M
