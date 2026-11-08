local M = {}

local config = require("treesitter-jump.config")

-- Sets derived from config tables, keyed by source table. config.setup() bumps
-- config.generation because it edits those tables in place.
local set_cache = setmetatable({}, { __mode = "k" })

---@param source table
---@param build fun(source: table): table<string, boolean>, integer
---@return table<string, boolean> set, integer maxlen
local function cached_set(source, build)
    local entry = set_cache[source]

    if not entry or entry.generation ~= config.generation then
        local set, maxlen = build(source)
        entry = { generation = config.generation, set = set, maxlen = maxlen }
        set_cache[source] = entry
    end

    return entry.set, entry.maxlen
end

---@param lang_pairs LanguagePairs
---@return table<string, boolean>, integer
local function build_keyword_set(lang_pairs)
    local keywords, maxlen = {}, 0

    for start, info in pairs(lang_pairs) do
        keywords[start] = true
        maxlen = math.max(maxlen, #start)

        if info.ending then
            keywords[info.ending] = true
            maxlen = math.max(maxlen, #info.ending)
        end

        for middle, enabled in pairs(info.middle or {}) do
            if enabled then
                keywords[middle] = true
                maxlen = math.max(maxlen, #middle)
            end
        end
    end

    return keywords, maxlen
end

---@param brackets string[]
---@return table<string, boolean>, integer
local function build_bracket_set(brackets)
    local set, maxlen = {}, 0

    for _, b in ipairs(brackets) do
        set[b] = true
        maxlen = math.max(maxlen, #b)
    end

    return set, maxlen
end
--- Set of all keywords (start, ending, middle) for the buffer's filetype
---@param bufnr integer
---@param ft? string filetype of bufnr, if already known
---@return table<string, boolean> keywords, integer maxlen (shared; do not modify)
function M.keyword_set(bufnr, ft)
    ft = ft or vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    local lang_pairs = config.language_pairs[ft]

    if not lang_pairs then
        return {}, 0
    end

    return cached_set(lang_pairs, build_keyword_set)
end

--- Set of configured brackets
---@return table<string, boolean> brackets, integer maxlen (shared; do not modify)
function M.bracket_set()
    return cached_set(config.brackets, build_bracket_set)
end

--- Check if the given node is a keyword node based on language pairs
---@param node TSNode
---@param bufnr integer
---@return boolean
function M.is_keyword_node(node, bufnr)
    local keywords, maxlen = M.keyword_set(bufnr)
    local text = M.short_text(node, bufnr, maxlen)
    return text ~= nil and keywords[text] == true
end

--- Check if the node's text is one of the configured brackets
---@param node TSNode
---@param bufnr integer
---@return boolean
function M.is_bracket_node(node, bufnr)
    local brackets, maxlen = M.bracket_set()
    local text = M.short_text(node, bufnr, maxlen)
    return text ~= nil and brackets[text] == true
end

--- Check if the node is a statement node
---@param node TSNode
---@return boolean
function M.is_statement_node(node)
    local type = node:type()
    return type:match("_statement$") or type:match("_declaration$") or type:match("_definition$")
end

--- Get the node at the given position
---@param bufnr integer
---@param row integer
---@param col integer
---@return TSNode? node, string? text
function M.get_node_at_pos(bufnr, row, col)
    local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, vim.treesitter.language.get_lang(ft))

    if not ok or parser == nil then
        return nil
    end

    local tree = parser:parse()[1]

    if not tree then
        return nil
    end

    local node = tree:root():descendant_for_range(row, col, row, col)

    local brackets, bracket_maxlen = M.bracket_set()
    local keywords, keyword_maxlen = M.keyword_set(bufnr, ft)
    local maxlen = math.max(bracket_maxlen, keyword_maxlen)

    while node do
        local text = M.short_text(node, bufnr, maxlen)

        -- Ancestors are at least as long, so none can match either
        if not text then
            break
        end

        if brackets[text] or keywords[text] then
            return node, text
        end

        node = node:parent()
    end

    return nil
end

--- Check if the cursor is at the node
---@param node TSNode
---@param row integer
---@param col integer
---@return boolean
function M.is_cursor_at_node(node, row, col)
    local srow, scol, erow, ecol = node:range()
    return row >= srow and row <= erow and col >= scol and col < ecol
end


---@type table<TSNode, TSNode[]>
local path_cache = setmetatable({}, { __mode = "k" })
--- Nearest ancestor of node satisfying pred.
--- Descends from the root because TSNode:parent() is O(depth), making repeated climbs O(depth^2).
---@param node TSNode
---@param pred fun(n: TSNode): boolean
---@return TSNode?
function M.find_ancestor(node, pred)
    local root = node:tree():root()

    if not root.child_with_descendant then
        local parent = node:parent()

        while parent and not pred(parent) do
            parent = parent:parent()
        end

        return parent
    end

    -- Language handlers and the generic fallback both search from the same node
    local path = path_cache[node]

    if not path then
        path = {}
        local cur = root

        while cur and cur ~= node do
            path[#path + 1] = cur
            cur = cur:child_with_descendant(node)
        end

        path_cache[node] = path
    end

    for i = #path, 1, -1 do
        if pred(path[i]) then
            return path[i]
        end
    end

    return nil
end

--- Text of a single-line node no longer than maxlen bytes, else nil
---@param node TSNode
---@param bufnr integer
---@param maxlen integer
---@return string?
function M.short_text(node, bufnr, maxlen)
    local srow, scol, erow, ecol = node:range()

    if srow ~= erow or ecol - scol > maxlen then
        return nil
    end

    return vim.api.nvim_buf_get_text(bufnr, srow, scol, erow, ecol, {})[1]
end

--- Index of the child of parent that contains the byte range [sbyte, ebyte), if any
---@param parent TSNode
---@param sbyte integer
---@param ebyte integer
---@return integer?
local function child_index_containing(parent, sbyte, ebyte)
    -- Children are ordered, so only the first one ending after sbyte can contain the range
    local lo, hi = 0, parent:child_count() - 1
    local found

    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local _, _, cend = parent:child(mid):end_()

        if cend > sbyte then
            found = mid
            hi = mid - 1
        else
            lo = mid + 1
        end
    end

    if found then
        local _, _, cstart = parent:child(found):start()

        if cstart <= sbyte and ebyte <= select(3, parent:child(found):end_()) then
            return found
        end
    end
end

-- Walk state: nodes[low..top] is the known part of the root path, deepest last, with
-- indices[k] the sibling index of nodes[k]. Plain functions over a state table instead of
-- closures, because LuaJIT can't compile closure creation (FNEW) and aborts the trace.

---@class treesitter-jump.Walk
---@field root TSNode
---@field node TSNode
---@field nodes table<integer, TSNode>
---@field indices table<integer, integer?>
---@field top integer
---@field low integer
---@field climbed boolean
---@field complete boolean

--- Load ancestors down to level k. The first climb is a single parent() call, since most
--- bracket matches are siblings; deeper climbs load the rest of the path in one root descent.
---@param s treesitter-jump.Walk
---@param k integer
---@return boolean
local function walk_ensure(s, k)
    if k >= s.low then
        return true
    end

    if s.complete then
        return false
    end

    local nodes = s.nodes

    if not s.climbed then
        s.climbed = true
        local parent = s.node:parent()

        if not parent then
            s.complete = true
            return false
        end

        s.low = s.low - 1
        nodes[s.low] = parent

        if k >= s.low then
            return true
        end
    end

    local target, path = nodes[s.low], {}

    if s.root.child_with_descendant then
        local cur = s.root

        while cur and cur ~= target do
            path[#path + 1] = cur
            cur = cur:child_with_descendant(target)
        end
    else
        local cur = target:parent()

        while cur do
            table.insert(path, 1, cur)
            cur = cur:parent()
        end
    end

    for i = #path, 1, -1 do
        s.low = s.low - 1
        nodes[s.low] = path[i]
    end

    s.complete = true
    return k >= s.low
end

--- Sibling index of nodes[k], found lazily since short walks rarely leave the deepest levels
---@param s treesitter-jump.Walk
---@param k integer
---@return integer?
local function walk_index(s, k)
    local indices = s.indices

    if not indices[k] then
        local node = s.nodes[k]
        local _, _, sbyte = node:start()
        local _, _, ebyte = node:end_()
        indices[k] = child_index_containing(s.nodes[k - 1], sbyte, ebyte)
    end

    return indices[k]
end

---@param s treesitter-jump.Walk
---@return TSNode?
local function walk_forward(s)
    local nodes, indices, top = s.nodes, s.indices, s.top

    if nodes[top]:child_count() > 0 then
        top = top + 1
        s.top = top
        nodes[top], indices[top] = nodes[top - 1]:child(0), 0
        return nodes[top]
    end

    while walk_ensure(s, top - 1) do
        local i = (walk_index(s, top) or math.huge) + 1

        if i < nodes[top - 1]:child_count() then
            nodes[top], indices[top] = nodes[top - 1]:child(i), i
            s.top = top
            return nodes[top]
        end

        top = top - 1
        s.top = top
    end
end

---@param s treesitter-jump.Walk
---@return TSNode?
local function walk_backward(s)
    local nodes, indices, top = s.nodes, s.indices, s.top

    if not walk_ensure(s, top - 1) then
        return nil
    end

    local i = (walk_index(s, top) or 0) - 1

    if i < 0 then
        s.top = top - 1
        return nodes[top - 1]
    end

    nodes[top], indices[top] = nodes[top - 1]:child(i), i
    local count = nodes[top]:child_count()

    while count > 0 do
        top = top + 1
        nodes[top], indices[top] = nodes[top - 1]:child(count - 1), count - 1
        count = nodes[top]:child_count()
    end

    s.top = top
    return nodes[top]
end

--- Iterate nodes after (forward) or before (backward) node in document (preorder) order.
--- Keeps an explicit root path because TSNode:parent()/next_sibling() are O(depth) each.
---@param node TSNode
---@param forward boolean
---@return fun(s: treesitter-jump.Walk): TSNode?, treesitter-jump.Walk
function M.walk(node, forward)
    local top = 1000

    ---@type treesitter-jump.Walk
    local s = {
        root = node:tree():root(),
        node = node,
        nodes = { [top] = node },
        indices = {},
        top = top,
        low = top,
        climbed = false,
        complete = false,
    }

    return forward and walk_forward or walk_backward, s
end

return M
