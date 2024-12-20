local jumper = require("treesitter-jump")

local bufnr

before_each(function()
    bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(bufnr)
end)

after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
end)

describe("Lua matching", function()
    it("matches if-then-end", function()
        local text = {
            "if x then",
            "  print(x)",
            "end",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 3, 0 }, cursor)

        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 0 }, cursor)
    end)

    it("matches if-else-end", function()
        local text = {
            "if x then",
            "  print(1)",
            "else", -- Make sure this line exists in the test
            "  print(2)",
            "end",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

        -- Test from 'if'
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 3, 0 }, cursor) -- should jump to else

        -- Test from 'else'
        vim.api.nvim_win_set_cursor(0, { 3, 0 })
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 5, 0 }, cursor) -- should jump to end

        -- Test from 'end'
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 0 }, cursor) -- should jump back to if
    end)

    it("matches function-end", function()
        local text = {
            "function test()",
            "    return true",
            "end",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

        -- From function -> end
        vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- position on 'function'
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 3, 0 }, cursor)

        -- From end -> function
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 0 }, cursor)
    end)

    it("matches local function-end", function()
        local text = {
            "local function test()",
            "    return true",
            "end",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

        -- From function -> end
        vim.api.nvim_win_set_cursor(0, { 1, 9 }) -- position after "local "
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 3, 0 }, cursor)

        -- From end -> function
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 6 }, cursor)
    end)
end)
