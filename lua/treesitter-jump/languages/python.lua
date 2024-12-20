local M = {}

--- Collect Python block nodes
---@param start_node TSNode
---@return TSNode[]
function M.collect_block_nodes(start_node)
    local nodes = {}
    local parent = start_node:parent()

    if not parent then
        return nodes
    end

    -- Get the statement node (if_statement, try_statement, etc.)
    while parent and not parent:type():match("_statement$") do
        parent = parent:parent()
    end

    if not parent then
        return nodes
    end

    local stmt_type = parent:type()

    if stmt_type == "if_statement" then
        -- First node is 'if'
        local if_keyword = parent:child(0)
        if if_keyword then
            table.insert(nodes, if_keyword)
        end

        -- Find elif clauses
        for child in parent:iter_children() do
            if child:type() == "elif_clause" then
                local elif_keyword = child:child(0)
                if elif_keyword then
                    table.insert(nodes, elif_keyword)
                end
            end
        end

        -- Find else clause
        for child in parent:iter_children() do
            if child:type() == "else_clause" then
                local else_keyword = child:child(0)
                if else_keyword then
                    table.insert(nodes, else_keyword)
                end
                break
            end
        end
    elseif stmt_type == "try_statement" then
        -- Add try node
        table.insert(nodes, parent:child(0))

        -- Look for except, else, and finally clauses
        for child in parent:iter_children() do
            local type = child:type()

            if type == "except_clause" or type == "finally_clause" or type == "else_clause" then
                local keyword_node = child:child(0)
                if keyword_node then
                    table.insert(nodes, keyword_node)
                end
            end
        end
    elseif stmt_type == "for_statement" or stmt_type == "while_statement" then
        -- Add for/while node
        table.insert(nodes, parent:child(0))

        -- Look for else clause
        for child in parent:iter_children() do
            if child:type() == "else_clause" then
                local else_keyword = child:child(0)
                if else_keyword then
                    table.insert(nodes, else_keyword)
                end
                break
            end
        end
    end

    return nodes
end

--- Handle Python block navigation
---@param node TSNode
function M.handle_block(node)
    local block_nodes = M.collect_block_nodes(node)

    if #block_nodes > 0 then
        --
        -- Find current position and jump
        for i, n in ipairs(block_nodes) do
            if n == node then
                local next_idx = i < #block_nodes and i + 1 or 1
                local next_node = block_nodes[next_idx]

                if next_node then
                    local next_row, next_col = next_node:range()
                    vim.api.nvim_win_set_cursor(0, { next_row + 1, next_col })
                end

                break
            end
        end

        return true
    end

    return false
end

return M
