local jumper = require("treesitter-jump")

-- Point to installed parsers.
local path = tostring(vim.fn.stdpath("data"))

vim.opt.runtimepath:append(vim.fs.joinpath(path, "ts-install"))
vim.opt.runtimepath:append(vim.fs.joinpath(path, "site/pack/packer/start/nvim-treesitter/parser"))
vim.opt.runtimepath:append(vim.fs.joinpath(path, "lazy/nvim-treesitter/parser"))

local bufnr

before_each(function()
    bufnr = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(bufnr)
end)

after_each(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
end)

describe("Python matching", function()
    it("matches if-elif-else", function()
        local text = {
            "if condition:",
            "    print(1)",
            "elif other:",
            "    print(2)",
            "else:",
            "    print(3)",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })

        -- From if -> elif
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 3, 0 }, cursor)

        -- From elif -> else
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 5, 0 }, cursor)

        -- From else -> if
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 0 }, cursor)
    end)

    it("matches try-except-else-finally", function()
        local text = {
            "try:",
            "    risky()",
            "except Error:",
            "    handle()",
            "else:",
            "    success()",
            "finally:",
            "    cleanup()",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })

        -- From try -> except
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 3, 0 }, cursor)

        -- From except -> else
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 5, 0 }, cursor)

        -- From else -> finally
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 7, 0 }, cursor)

        -- From finally -> try
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 0 }, cursor)
    end)

    it("matches for-else", function()
        local text = {
            "for item in items:",
            "    process(item)",
            "else:",
            "    print('done')",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })

        -- From for -> else
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 3, 0 }, cursor)

        -- From else -> for
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 0 }, cursor)
    end)

    it("matches while-else", function()
        local text = {
            "while condition:",
            "    process()",
            "else:",
            "    print('done')",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
        vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })

        -- From while -> else
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        jumper.jump()
        local cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 3, 0 }, cursor)

        -- From else -> while
        jumper.jump()
        cursor = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 0 }, cursor)
    end)
end)
