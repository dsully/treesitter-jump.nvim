local M = {}

local tree = require("treesitter-jump.tree")

--- Handle generic language navigation
---@param node TSNode
---@param bufnr integer
---@param row integer
---@param col integer
function M.handle_generic_language(node, bufnr, row, col)
    -- Handle other keywords
    local statement = node:parent()

    while statement and not tree.is_statement_node(statement) do
        statement = statement:parent()
    end

    if not statement then
        return
    end

    -- Collect keywords
    local keywords = {}

    for child in statement:iter_children() do
        if tree.is_keyword_node(child, bufnr) then
            table.insert(keywords, child)
        end
    end

    -- Find current position and jump
    for i, n in ipairs(keywords) do
        --
        if tree.is_cursor_at_node(n, row, col) then
            local next_idx = i < #keywords and i + 1 or 1
            local next_node = keywords[next_idx]

            if next_node then
                local next_row, next_col = next_node:range()
                vim.api.nvim_win_set_cursor(0, { next_row + 1, next_col })
            end

            break
        end
    end
end

return M
