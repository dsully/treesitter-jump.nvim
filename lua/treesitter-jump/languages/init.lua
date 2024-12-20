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
function M.handle_brackets(node, bufnr)
    local text = vim.treesitter.get_node_text(node, bufnr)
    local root = node:tree():root()
    local brackets = {}

    local function collect_brackets(n)
        local t = vim.treesitter.get_node_text(n, bufnr)

        if vim.tbl_contains(config.brackets, t) then
            table.insert(brackets, n)
        end

        for child in n:iter_children() do
            collect_brackets(child)
        end
    end

    collect_brackets(root)

    -- Find current bracket position
    local current_idx

    for i, n in ipairs(brackets) do
        if n == node then
            current_idx = i
            break
        end
    end

    if current_idx then
        --
        if M.is_opening_bracket(text) then
            -- Search forward for matching closing bracket
            local depth = 1

            for i = current_idx + 1, #brackets do
                local next_text = vim.treesitter.get_node_text(brackets[i], bufnr)

                if next_text == text then
                    depth = depth + 1
                elseif M.is_matching_pair(text, next_text) then
                    depth = depth - 1

                    if depth == 0 then
                        local next_row, next_col = brackets[i]:range()
                        vim.api.nvim_win_set_cursor(0, { next_row + 1, next_col })
                        return
                    end
                end
            end
        else
            -- Search backward for matching opening bracket
            local depth = 1

            for i = current_idx - 1, 1, -1 do
                local prev_text = vim.treesitter.get_node_text(brackets[i], bufnr)

                if prev_text == text then
                    depth = depth + 1
                elseif M.is_matching_pair(prev_text, text) then
                    depth = depth - 1
                    if depth == 0 then
                        local next_row, next_col = brackets[i]:range()
                        vim.api.nvim_win_set_cursor(0, { next_row + 1, next_col })
                        return
                    end
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
    if M.languages[ft] and M.languages[ft].handle_block then
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

return setmetatable(M, {
    __index = M.languages,
})
