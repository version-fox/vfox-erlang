-- Copyright 2026 vfox-erlang contributors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local erlangUtils = require("erlang_utils")

-- Finds Erlang/OTP installations that vfox did not install. Each function that touches
-- the file system is a field of this table, so the offline tests can replace it with a
-- fake file system.
local detect = {}

local function under(base, ...)
    local result = base
    for _, part in ipairs({ ... }) do
        result = erlangUtils.join(result, part)
    end
    return result
end

local function basename(path)
    return string.match(path, "([^/\\]+)$") or path
end

--- Returns the text of a file, or nil when it cannot be read.
function detect.read_file(path)
    local file = io.open(path, "r")
    if file == nil then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

--- Returns true when the path can be opened for reading.
function detect.file_exists(path)
    return erlangUtils.file_exists(path)
end

--- Lists the immediate children of dir as full paths, or {} when dir cannot be listed.
function detect.list_children(dir)
    if dir == nil or dir == "" or io.popen == nil then
        return {}
    end
    local command
    if erlangUtils.is_windows() then
        command = "dir /b /ad " .. erlangUtils.shell_quote(dir) .. " 2>nul"
    else
        command = "ls -1 " .. erlangUtils.shell_quote(dir) .. " 2>/dev/null"
    end
    local handle = io.popen(command, "r")
    if handle == nil then
        return {}
    end
    -- vfox replaces io.popen on Windows with a handle that has read, write and close, but no
    -- lines method. Read line by line with read("*l"), which returns nil at the end, so the
    -- same code works on every platform.
    local result = {}
    while true do
        local line = handle:read("*l")
        if line == nil then
            break
        end
        local name = erlangUtils.trim(line)
        if name ~= "" then
            table.insert(result, erlangUtils.join(dir, name))
        end
    end
    handle:close()
    return result
end

--- Lists the children of dir whose lower-cased names start with one of prefixes.
function detect.list_matching(dir, prefixes)
    local result = {}
    for _, child in ipairs(detect.list_children(dir)) do
        local name = string.lower(basename(child))
        for _, prefix in ipairs(prefixes) do
            if string.sub(name, 1, #prefix) == prefix then
                table.insert(result, child)
                break
            end
        end
    end
    return result
end

--- Returns true for paths that vfox manages itself, which must never be detected.
local function is_vfox_managed(path)
    local p = string.lower(path or "")
    return string.find(p, "/.vfox/", 1, true) ~= nil or string.find(p, "\\.vfox\\", 1, true) ~= nil
end

--- Returns the OTP version recorded in releases/<release>/OTP_VERSION, or nil.
local function release_version(root)
    local dirs = detect.list_children(under(root, "releases"))
    table.sort(dirs)
    for _, dir in ipairs(dirs) do
        local text = detect.read_file(under(dir, "OTP_VERSION"))
        if text ~= nil then
            local version = erlangUtils.trim(text)
            if version ~= "" then
                return version
            end
        end
    end
    return nil
end

--- Returns the Erlang/OTP root under dir and its version, or nil. dir is either the root
--- itself (it holds bin and releases) or a prefix whose lib/erlang is the root.
local function otp_root(dir)
    local exe = erlangUtils.is_windows() and "erl.exe" or "erl"
    for _, root in ipairs({ dir, under(dir, "lib", "erlang") }) do
        if detect.file_exists(under(root, "bin", exe)) then
            local version = release_version(root)
            if version ~= nil then
                return root, version
            end
        end
    end
    return nil, nil
end

--- Candidate locations, each with mode: "self" (the path is one root or prefix), "children"
--- (every child is one) or "matching" (children whose names start with one of prefixes).
function detect.candidate_roots()
    local roots = {}
    local function add(path, note, mode, prefixes)
        if type(path) == "string" and path ~= "" then
            table.insert(roots, { path = path, note = note, mode = mode, prefixes = prefixes })
        end
    end

    local home = os.getenv("HOME") or ""
    if erlangUtils.is_windows() then
        local userprofile = os.getenv("USERPROFILE") or ""
        local programfiles = os.getenv("ProgramFiles") or "C:\\Program Files"
        local programfiles_x86 = os.getenv("ProgramFiles(x86)")
        local prefixes = { "erlang otp", "erl" }
        add(programfiles, "installed in Program Files", "matching", prefixes)
        add(programfiles_x86, "installed in Program Files (x86)", "matching", prefixes)
        if userprofile ~= "" then
            add(under(userprofile, ".local", "share", "mise", "installs", "erlang"), "installed by mise", "children")
        end
        return roots
    end

    add("/usr/lib/erlang", "installed by a system package", "self")
    add("/usr/local/lib/erlang", "installed under /usr/local", "self")
    add("/opt/erlang", "installed under /opt/erlang", "children")
    add("/opt/homebrew/opt/erlang", "installed by Homebrew", "self")
    add("/usr/local/opt/erlang", "installed by Homebrew", "self")
    add("/home/linuxbrew/.linuxbrew/opt/erlang", "installed by Homebrew", "self")
    add("/opt/homebrew/Cellar/erlang", "installed by Homebrew", "children")
    add("/usr/local/Cellar/erlang", "installed by Homebrew", "children")
    add("/home/linuxbrew/.linuxbrew/Cellar/erlang", "installed by Homebrew", "children")
    if home ~= "" then
        add(under(home, ".asdf", "installs", "erlang"), "installed by asdf", "children")
        add(under(home, ".local", "share", "mise", "installs", "erlang"), "installed by mise", "children")
    end
    return roots
end

--- Finds every Erlang/OTP installation on the machine. Results are sorted by version and
--- path, with one entry per version: vfox links the first entry for a version and skips the
--- rest as already linked, so the order decides which copy is offered.
function detect.find_all()
    local found = {}
    local seen_dirs = {}
    local seen_roots = {}
    for _, candidate in ipairs(detect.candidate_roots()) do
        local dirs
        if candidate.mode == "children" then
            dirs = detect.list_children(candidate.path)
        elseif candidate.mode == "matching" then
            dirs = detect.list_matching(candidate.path, candidate.prefixes)
        else
            dirs = { candidate.path }
        end
        for _, dir in ipairs(dirs) do
            if not seen_dirs[dir] and not is_vfox_managed(dir) then
                seen_dirs[dir] = true
                local root, version = otp_root(dir)
                if root ~= nil and not seen_roots[root] and not is_vfox_managed(root) then
                    seen_roots[root] = true
                    table.insert(found, { version = version, path = root, note = candidate.note })
                end
            end
        end
    end

    table.sort(found, function(a, b)
        if a.version ~= b.version then
            return a.version < b.version
        end
        return a.path < b.path
    end)

    local result = {}
    local seen_versions = {}
    for _, item in ipairs(found) do
        if not seen_versions[item.version] then
            seen_versions[item.version] = true
            table.insert(result, item)
        end
    end
    return result
end

return detect
