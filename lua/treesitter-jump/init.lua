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
    local ft = vim.bo[bufnr].filetype

    local node = require("treesitter-jump.tree").get_node_at_pos(bufnr, row, col)

    if not node then
        return
    end

    local text = vim.treesitter.get_node_text(node, bufnr)
    local languages = require("treesitter-jump.languages")

    -- Handle brackets
    if vim.tbl_contains(config.brackets, text) then
        languages.handle_brackets(node, bufnr)
        return
    end

    languages.handle_language(node, bufnr, row, col, ft)
end

return M
