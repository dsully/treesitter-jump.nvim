local config = require("treesitter-jump.config")
local jumper = require("treesitter-jump")

describe("setup", function()
    it("merges pairs into an existing language", function()
        local if_pair = config.language_pairs.lua["if"]

        jumper.setup({ language_pairs = { lua = { ["if"] = if_pair } } })

        assert.are.equal(if_pair, config.language_pairs.lua["if"])
    end)

    it("adds a new language", function()
        local pairs_for_lang = { ["begin"] = { ending = "finish", middle = {} } }

        jumper.setup({ language_pairs = { setup_spec_lang = pairs_for_lang } })

        assert.are.equal(pairs_for_lang, config.language_pairs.setup_spec_lang)
    end)
end)
