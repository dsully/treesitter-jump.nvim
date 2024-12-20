---@class treesitter-jump.Config
---@field brackets string[]
---@field bracket_pairs table<string, string>
---@field opening_brackets table<string, boolean>
---@field language_pairs table<string, LanguagePairs>

---@class treesitter-jump.LanguagePair
---@field ending? string
---@field middle? table<string, boolean>

---@class LanguagePairs
---@field [string] treesitter-jump.LanguagePair

local M = {}

--- Brackets to consider
---@type string[]
M.brackets = {
    "(",
    ")",
    "[",
    "]",
    "{",
    "}",
    "<",
    ">",
}

--- Mapping of opening to closing brackets
---@type table<string, string>
M.bracket_pairs = {
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
    ["<"] = ">",
}

--- Set of opening brackets
---@type table<string, boolean>
M.opening_brackets = {
    ["("] = true,
    ["["] = true,
    ["{"] = true,
    ["<"] = true,
}

--- Default language-specific keyword patterns
---@type table<string, LanguagePairs>
M.language_pairs = {
    bash = {
        ["if"] = {
            ending = "fi",
            middle = {
                ["else"] = true,
                ["elif"] = true,
            },
        },
        ["case"] = { ending = "esac", middle = {} },
        ["while"] = { ending = "done", middle = {} },
        ["until"] = { ending = "done", middle = {} },
        ["for"] = { ending = "done", middle = {} },
        ["select"] = { ending = "done", middle = {} },
    },
    fish = {
        ["if"] = {
            ending = "end",
            middle = {
                ["else"] = true,
                ["else if"] = true,
            },
        },
        ["function"] = { ending = "end", middle = {} },
        ["for"] = { ending = "end", middle = {} },
        ["while"] = { ending = "end", middle = {} },
        ["begin"] = { ending = "end", middle = {} },
        ["switch"] = {
            ending = "end",
            middle = {
                ["case"] = true,
            },
        },
    },
    lua = {
        ["if"] = {
            ending = "end",
            middle = {
                ["else"] = true,
                ["elseif"] = true,
            },
        },
        ["function"] = { ending = "end", middle = {} },
        ["for"] = { ending = "end", middle = {} },
        ["while"] = { ending = "end", middle = {} },
        ["do"] = { ending = "end", middle = {} },
        ["repeat"] = { ending = "until", middle = {} },
    },
    python = {
        ["if"] = {
            middle = {
                ["elif"] = true,
                ["else"] = true,
            },
        },
        ["for"] = {
            middle = {
                ["else"] = true,
            },
        },
        ["while"] = {
            middle = {
                ["else"] = true,
            },
        },
        ["try"] = {
            middle = {
                ["except"] = true,
                ["else"] = true,
                ["finally"] = true,
            },
        },
        ["match"] = {
            middle = {
                ["case"] = true,
            },
        },
    },
    zsh = {
        ["if"] = {
            ending = "fi",
            middle = {
                ["else"] = true,
                ["elif"] = true,
            },
        },
        ["case"] = { ending = "esac", middle = {} },
        ["while"] = { ending = "done", middle = {} },
        ["until"] = { ending = "done", middle = {} },
        ["for"] = { ending = "done", middle = {} },
        ["select"] = { ending = "done", middle = {} },
        ["function"] = { ending = "}", middle = {} },
    },
}

--- Setup function to configure language pairs and other settings
---@param opts table
function M.setup(opts)
    opts = opts or {}

    if opts.language_pairs then
        --
        -- Merge user-defined language pairs
        for lang, pairs in pairs(opts.language_pairs) do
            --
            if M.language_pairs[lang] then
                -- Merge existing language definitions
                for keyword, data in pairs(pairs) do
                    M.language_pairs[lang][keyword] = data
                end
            else
                -- Add new language
                M.language_pairs[lang] = pairs
            end
        end
    end
end

return M
