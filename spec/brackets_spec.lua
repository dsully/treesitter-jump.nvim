local jumper = require("treesitter-jump")

local bufnr

before_each(function()
    bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(bufnr)
end)

after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
end)

describe("Bracket matching", function()
    it("matches simple brackets", function()
        local text = { "x={1,2}" } -- Minimal test case
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

        vim.api.nvim_win_set_cursor(0, { 1, 2 }) -- position on {
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 6 }, cursor) -- should be on }

        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 2 }, cursor) -- should be back on {
    end)

    it("matches nested brackets", function()
        local text = { "f({[1]})" } -- Minimal nested case
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

        -- Test outer brackets
        vim.api.nvim_win_set_cursor(0, { 1, 2 }) -- position on (
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 6 }, cursor) -- should be on )

        -- Test middle brackets
        vim.api.nvim_win_set_cursor(0, { 1, 3 }) -- position on {
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 5 }, cursor) -- should be on }

        -- Test inner brackets
        vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- position on [
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 4 }, cursor) -- should be on ]
    end)
end)
