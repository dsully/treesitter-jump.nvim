local M = {}

local tree = require("treesitter-jump.tree")

-- TODO: Is there a better way to get these type names?
---@param n TSNode
---@return boolean
local function is_block_parent(n)
    local type = n:type()
    return type == "if_statement" or type == "function_definition"
end

--- Collect Lua block nodes
--- @param start_node TSNode
--- @param bufnr integer
--- @return TSNode[]
M.collect_block_nodes = function(start_node, bufnr)
    local nodes = {}
    local parent = tree.find_ancestor(start_node, is_block_parent)

    if not parent then
        return nodes
    end

    local parent_type = parent:type()

    if parent_type == "if_statement" then
        -- Order is: if, else (inside else_statement), end
        local elses, ends = {}, {}

        for i = 0, parent:child_count() - 1 do
            local child = parent:child(i)
            local text = tree.short_text(child, bufnr, 4)

            if text == "if" then
                table.insert(nodes, child)
            elseif text == "end" then
                table.insert(ends, child)
            elseif child:type() == "else_statement" then
                for j = 0, child:child_count() - 1 do
                    local else_child = child:child(j)
                    if tree.short_text(else_child, bufnr, 4) == "else" then
                        table.insert(elses, else_child)
                        break
                    end
                end
            end
        end

        vim.list_extend(nodes, elses)
        vim.list_extend(nodes, ends)
    elseif parent_type == "function_definition" then
        --
        -- For both regular and local functions
        local is_local = false

        for i = 0, parent:child_count() - 1 do
            local child = parent:child(i)
            if child:type() == "local" then
                is_local = true
                break
            end
        end

        -- Find function and end nodes
        for i = 0, parent:child_count() - 1 do
            local child = parent:child(i)
            if child:type() == "function" then
                --
                if is_local then
                    -- For local functions, adjust the position
                    local row, col = child:range()

                    local virtual_node = {
                        range = function()
                            -- FIXME: These shouldn't be hardcoded, but 🤷
                            return row, 9, row, col + 8
                        end,
                    }

                    table.insert(nodes, virtual_node)
                else
                    -- For regular functions, use the node as is
                    table.insert(nodes, child)
                end
            elseif child:type() == "end" then
                table.insert(nodes, child)
            end
        end
    end

    return nodes
end

--- Handle Lua block navigation
--- @param node TSNode
--- @param bufnr integer
--- @param row integer
--- @param col integer
function M.handle_block(node, bufnr, row, col)
    local block_nodes = M.collect_block_nodes(node, bufnr)

    if #block_nodes > 0 then
        -- Find current position and jump
        local current_idx

        for i, n in ipairs(block_nodes) do
            if tree.is_cursor_at_node(n, row, col) then
                current_idx = i
                break
            end
        end

        if current_idx then
            local next_idx = current_idx < #block_nodes and current_idx + 1 or 1
            local next_node = block_nodes[next_idx]

            if next_node then
                local next_row, next_col = next_node:range()

                vim.api.nvim_win_set_cursor(0, { next_row + 1, next_col })
            end
        end

        return true
    end

    return false
end

return M
