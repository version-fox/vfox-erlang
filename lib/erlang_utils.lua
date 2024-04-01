local http = require("http")

local erlang_utils = {}

local function peek_lua_table(o, indent)
    indent = indent or 0
 
    local function handle_table(t, currentIndent)
        local result = {}
        for k, v in pairs(t) do
            local key = type(k) ~= 'number' and ('[' .. peek_lua_table(k, currentIndent + 1) .. ']') or ''
            local value = type(v) == 'table' and handle_table(v, currentIndent + 1) or peek_lua_table(v, currentIndent + 1)
            table.insert(result, key .. (key ~= '' and ' = ' or '') .. value)
        end
        return '{\n' .. table.concat(result, ',\n') .. '\n' .. string.rep('  ', currentIndent) .. '}'
    end
 
    if type(o) == 'table' then
        return handle_table(o, indent)
    else
        return tostring(o)
    end
end

function erlang_utils.check_platform()
    if RUNTIME.OS_TYPE == "windows" then
        error("Windows is not supported. Please direct use the offcial installer to setup Erlang/OTP. visit: https://www.erlang.org/downloads")
    end
end

function erlang_utils.check_version_existence(url)
    local resp, err = http.get({
        url = url
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("Please confirm whether the corresponding Erlang/OTP release version exists! visit: https://github.com/erlang/otp/releases")
    end
end

function erlang_utils.get_erlang_release_verions()
    local resp, err = http.get({
        url = "https://fastly.jsdelivr.net/gh/yeshan333/vfox-erlang@main/assets/versions.txt"
    })
    local result = {}
    for version in string.gmatch(resp.body, '([^\n]+)') do
        table.insert(result, {
            version = version
        })
    end
    return result
end

return erlang_utils