local M = {}

local config = require("treesitter-jump.config")

--- Check if the given node is a keyword node based on language pairs
---@param node TSNode
---@param bufnr integer
---@return boolean
function M.is_keyword_node(node, bufnr)
    local ft = vim.bo[bufnr].filetype
    local lang_pairs = config.language_pairs[ft]

    if not lang_pairs then
        return false
    end

    local text = vim.treesitter.get_node_text(node, bufnr)

    -- Check if it's a start keyword
    if lang_pairs[text] then
        return true
    end

    -- Check if it's an end keyword or middle keyword
    for _, info in pairs(lang_pairs) do
        if info.ending == text then
            return true
        end

        if info.middle and info.middle[text] then
            return true
        end
    end

    return false
end

--- Check if the node is a statement node
---@param node TSNode
---@return boolean
function M.is_statement_node(node)
    local type = node:type()
    return type:match("_statement$") or type:match("_declaration$") or type:match("_definition$")
end

--- Get the node at the given position
---@param bufnr integer
---@param row integer
---@param col integer
---@return TSNode|nil
function M.get_node_at_pos(bufnr, row, col)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr)

    if not ok or not parser then
        return nil
    end

    local tree = parser:parse()[1]

    if not tree then
        return nil
    end

    local node = tree:root():descendant_for_range(row, col, row, col + 1)

    while node do
        local text = vim.treesitter.get_node_text(node, bufnr)

        if vim.tbl_contains(config.brackets, text) or M.is_keyword_node(node, bufnr) then
            return node
        end

        node = node:parent()
    end

    return nil
end

--- Check if the cursor is at the node
---@param node TSNode
---@param row integer
---@param col integer
---@return boolean
function M.is_cursor_at_node(node, row, col)
    local srow, scol, erow, ecol = node:range()
    return row >= srow and row <= erow and col >= scol and col < ecol
end

return M
