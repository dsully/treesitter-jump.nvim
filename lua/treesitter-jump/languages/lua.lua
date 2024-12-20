local M = {}

local tree = require("treesitter-jump.tree")

--- Collect Lua block nodes
--- @param start_node TSNode
--- @param bufnr integer
--- @return TSNode[]
M.collect_block_nodes = function(start_node, bufnr)
    local nodes = {}
    local parent = start_node:parent()

    if not parent then
        return nodes
    end

    -- Get either if_statement or function_declaration node
    -- TODO: Is there a better way to get these type names?
    while parent and not (parent:type() == "if_statement" or parent:type() == "function_definition") do
        parent = parent:parent()
    end

    if not parent then
        return nodes
    end

    local parent_type = parent:type()

    if parent_type == "if_statement" then
        --
        -- Collect nodes in order
        for child in parent:iter_children() do
            --
            local text = vim.treesitter.get_node_text(child, bufnr)

            if text == "if" then
                table.insert(nodes, child)
            end
        end

        -- Look for else inside else_statement
        for child in parent:iter_children() do
            --
            if child:type() == "else_statement" then
                --
                for else_child in child:iter_children() do
                    local text = vim.treesitter.get_node_text(else_child, bufnr)

                    if text == "else" then
                        table.insert(nodes, else_child)
                        break
                    end
                end
            end
        end

        for child in parent:iter_children() do
            local text = vim.treesitter.get_node_text(child, bufnr)

            if text == "end" then
                table.insert(nodes, child)
            end
        end
    elseif parent_type == "function_definition" then
        --
        -- For both regular and local functions
        local is_local = false

        for child in parent:iter_children() do
            if child:type() == "local" then
                is_local = true
                break
            end
        end

        -- Find function and end nodes
        for child in parent:iter_children() do
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
