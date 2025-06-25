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

---@class BracketNode
---@field node TSNode
---@field row integer
---@field col integer

--- Handle matching brackets
---@param node TSNode
---@param bufnr integer
function M.handle_brackets(node, bufnr)
    local text = vim.treesitter.get_node_text(node, bufnr)
    local root = node:tree():root()

    ---@type BracketNode[]
    local brackets = {}

    ---@param n TSNode
    local function collect_brackets(n)
        local t = vim.treesitter.get_node_text(n, bufnr)

        if vim.tbl_contains(config.brackets, t) then
            local start_row, start_col = n:range()
            table.insert(brackets, { node = n, row = start_row, col = start_col })
        end

        for child in n:iter_children() do
            collect_brackets(child)
        end
    end

    collect_brackets(root)

    -- Sort brackets by position (row first, then column)
    table.sort(brackets, function(a, b)
        return a.row < b.row or (a.row == b.row and a.col < b.col)
    end)

    -- Find current bracket position
    ---@type integer?
    local current_idx

    local node_start_row, node_start_col = node:start()

    -- Compare by position
    for i, bracket in ipairs(brackets) do
        local bracket_row, bracket_col = bracket.node:start()

        if bracket_row == node_start_row and bracket_col == node_start_col then
            current_idx = i
            break
        end
    end

    if current_idx then
        if M.is_opening_bracket(text) then
            -- Search forward for matching closing bracket
            local depth = 1

            for i = current_idx + 1, #brackets do
                local bracket = brackets[i]

                if bracket ~= nil then
                    local next_text = vim.treesitter.get_node_text(bracket.node, bufnr)

                    if next_text == text then
                        depth = depth + 1
                    elseif M.is_matching_pair(text, next_text) then
                        depth = depth - 1

                        if depth == 0 then
                            local next_row, next_col = bracket.node:range()
                            vim.api.nvim_win_set_cursor(0, { next_row + 1, next_col })
                            return
                        end
                    end
                end
            end
        else
            -- Search backward for matching opening bracket
            local depth = 1

            for i = current_idx - 1, 1, -1 do
                local bracket = brackets[i]

                if bracket ~= nil then
                    local prev_text = vim.treesitter.get_node_text(bracket.node, bufnr)

                    if prev_text == text then
                        depth = depth + 1
                    elseif M.is_matching_pair(prev_text, text) then
                        depth = depth - 1

                        if depth == 0 then
                            local next_row, next_col = bracket.node:range()
                            vim.api.nvim_win_set_cursor(0, { next_row + 1, next_col })
                            return
                        end
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

return M
