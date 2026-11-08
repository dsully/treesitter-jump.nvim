local M = {}

local config = require("treesitter-jump.config")
local tree = require("treesitter-jump.tree")

--- @class LanguageModule
--- @field handle_block fun(node: TSNode, bufnr: integer, row: integer, col: integer): boolean

--- @type table<string, LanguageModule>
M.languages = {
    lua = require("treesitter-jump.languages.lua"),
    python = require("treesitter-jump.languages.python"),
}

--- Check if the text is an opening bracket
---@param text string
---@return boolean
function M.is_opening_bracket(text)
    return config.opening_brackets[text]
end

--- Check if the open and close brackets are matching pair
---@param open string
---@param close string
---@return boolean
function M.is_matching_pair(open, close)
    return config.bracket_pairs[open] == close
end

--- Handle matching brackets
---@param node TSNode
---@param bufnr integer
---@param text? string node text, if already known
function M.handle_brackets(node, bufnr, text)
    text = text or vim.treesitter.get_node_text(node, bufnr)
    local opening = M.is_opening_bracket(text)
    local is_bracket, maxlen = tree.bracket_set()
    local depth = 1

    for n in tree.walk(node, opening) do
        local t = tree.short_text(n, bufnr, maxlen)

        if t and is_bracket[t] then
            if t == text then
                depth = depth + 1
            elseif opening and M.is_matching_pair(text, t) or not opening and M.is_matching_pair(t, text) then
                depth = depth - 1

                if depth == 0 then
                    local next_row, next_col = n:range()
                    vim.api.nvim_win_set_cursor(0, { next_row + 1, next_col })
                    return
                end
            end
        end
    end
end

--- Handle language-specific block navigation
--- @param node TSNode
--- @param bufnr integer
--- @param row integer
--- @param col integer
--- @param ft string
function M.handle_language(node, bufnr, row, col, ft)
    --
    if M.languages[ft] ~= nil and M.languages[ft].handle_block then
        if M.languages[ft].handle_block(node, bufnr, row, col) then
            return
        end
    end

    -- Fallback to generic handling if no language-specific handler is found
    M.handle_generic_language(node, bufnr, row, col)
end

--- Handle generic language navigation
---@param node TSNode
---@param bufnr integer
---@param row integer
---@param col integer
function M.handle_generic_language(node, bufnr, row, col)
    -- Handle other keywords
    local statement = tree.find_ancestor(node, tree.is_statement_node)

    if not statement then
        return
    end

    -- Collect keywords
    local keywords = {}
    local keyword_set, maxlen = tree.keyword_set(bufnr)

    for i = 0, statement:child_count() - 1 do
        local child = statement:child(i)
        if keyword_set[tree.short_text(child, bufnr, maxlen)] then
            table.insert(keywords, child)
        end
    end

    -- Find current position and jump
    for i, n in ipairs(keywords) do
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
