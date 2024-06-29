local http = require("http")

local erlang_utils = {}

function erlang_utils.peek_lua_table(o, indent)
    indent = indent or 0

    local function handle_table(t, currentIndent)
        local result = {}
        for k, v in pairs(t) do
            local key = type(k) ~= 'number' and ('[' .. erlang_utils.peek_lua_table(k, currentIndent + 1) .. ']') or ''
            local value = type(v) == 'table' and handle_table(v, currentIndent + 1) or
            erlang_utils.peek_lua_table(v, currentIndent + 1)
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

function erlang_utils.array_contains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

-- load configuration from environment variables
function erlang_utils.get_config_from_env(env_name, default_value)
    return os.getenv(env_name) or default_value
end

function erlang_utils.check_version_existence(url)
    local resp, err = http.get({
        url = url
    })
    if err ~= nil or resp.status_code ~= 200 then
        error(
        "Please confirm whether the corresponding Erlang/OTP release version exists! visit: https://github.com/erlang/otp/releases")
    end
end

function erlang_utils.directory_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

function erlang_utils.get_erlang_release_verions()
    local search_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/versions.txt"

    if erlang_utils.get_config_from_env("USE_PREBUILT_OTP") then
        -- FIXME: replace to release branch
        search_url = "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@support-download-bin/assets/prebuilt_versions.txt"
    end

    local resp, err = http.get({
        url = search_url
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
