-- LLM assisted code
-- Reviewed / edited by @sylefeb
--[[
    allpll.lua
    ----------
    Shared utility functions used by icepll.lua, ecppll.lua and gatemate.lua.

    Intended use - two equally valid patterns:

    1. Via require() when allpll.lua is already on package.path:

        local allpll = require("allpll")

    2. Via dofile() from a sibling file that was itself loaded with dofile()
       (e.g. from an application that calls dofile("path/to/icepll.lua")).
       In this case package.path is usually not set correctly, so icepll.lua
       calls the helper below instead of bare require():

        local allpll = (require "allpll.loader")()   -- handled internally

       Sibling files do this transparently through M.load_sibling(), which
       is the only public API they need:

        -- at the top of icepll.lua, ecppll.lua, gatemate.lua:
        local allpll = require("allpll")
           -- OR, when loaded via dofile, automatically resolved via the
           -- self-locating loader at the bottom of each sibling file.

    Public API:
        allpll.parse_args(s)      -> token table
        allpll.binstr(val, bits)  -> binary string
        allpll.round(x)           -> integer
        allpll.fmt                -> string.format alias
--]]

local M = {}

-- -- Self-locating loader ------------------------------------------------------
-- Returns the directory that contains *this* file (allpll.lua), with a
-- trailing path separator.  Works whether the file was loaded via require()
-- or via dofile(), and on both POSIX and Windows.
local function this_dir()
    -- Level 1 = this function, level 2 = the code inside allpll.lua that calls
    -- this_dir(), level 3 = whoever loaded allpll.lua (require or dofile).
    -- We want the source of allpll.lua itself, which is at level 1's caller -
    -- i.e. the chunk that is allpll.lua - so we walk up until we find a source
    -- that ends with "allpll.lua" or just use level 1's @source directly.
    local src = debug.getinfo(1, "S").source  -- e.g. "@/some/path/allpll.lua"
    if src:sub(1,1) == "@" then
        src = src:sub(2)  -- strip the leading "@"
    end
    -- Extract directory: everything up to and including the last slash/backslash
    local dir = src:match("^(.*[/\\])") or "./"
    return dir
end

--- Load a sibling .lua file from the same directory as allpll.lua, bypassing
--- package.path entirely.  Returns the value returned by the file (same
--- semantics as require()).  Results are cached in package.loaded so the file
--- is never executed more than once.
---
--- This is used by icepll.lua / ecppll.lua / gatemate.lua so that a plain
--- dofile("path/to/icepll.lua") works even when package.path doesn't include
--- the pll directory.
---
--- @param  name  string  Module name without extension, e.g. "allpll"
--- @return        any     Whatever the module file returns
function M.load_sibling(name)
    if package.loaded[name] then
        return package.loaded[name]
    end
    local path = this_dir() .. name .. ".lua"
    local result = dofile(path)
    package.loaded[name] = result
    return result
end

--- Split a CLI-style argument string into a flat token table.
--- Handles single-quoted and double-quoted tokens (no backslash escapes).
---
--- @param  s  string  Raw argument string, e.g. "-i 12 -o 48 -n 'my pll'"
--- @return     table  Ordered list of string tokens
function M.parse_args(s)
    local args = {}
    local i = 1
    while i <= #s do
        -- skip whitespace
        while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
        if i > #s then break end

        local c = s:sub(i, i)
        if c == '"' or c == "'" then
            -- quoted token: collect until matching closing quote
            local q = c
            i = i + 1
            local t = {}
            while i <= #s and s:sub(i, i) ~= q do
                t[#t + 1] = s:sub(i, i)
                i = i + 1
            end
            i = i + 1          -- consume closing quote
            args[#args + 1] = table.concat(t)
        else
            -- plain token: collect until next whitespace
            local j = i
            while i <= #s and not s:sub(i, i):match("%s") do i = i + 1 end
            args[#args + 1] = s:sub(j, i - 1)
        end
    end
    return args
end

--- Convert a non-negative integer to a zero-padded binary string.
---
--- @param  val   integer  Value to convert (must fit in `bits` bits)
--- @param  bits  integer  Total width of the output string
--- @return        string  e.g. binstr(47, 7) --> "0101111"
function M.binstr(val, bits)
    local s = {}
    for b = bits - 1, 0, -1 do
        s[#s + 1] = ((val >> b) & 1 == 1) and "1" or "0"
    end
    return table.concat(s)
end

--- Round a number to the nearest integer (half-up).
---
--- @param  x  number
--- @return     integer
function M.round(x)
    return math.floor(x + 0.5)
end

--- Alias for string.format, provided for convenience so callers can write
---     local fmt = allpll.fmt
--- and use it exactly as they would string.format.
M.fmt = string.format

return M
