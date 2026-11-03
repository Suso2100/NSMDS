-- NSMDS - JSON Parser

local JSON = {}

function JSON.decode(str)

    local position = 1

    local function skip_whitespace()
        while position <= #str and
            str:sub(position, position):match("%s") do
            position = position + 1
        end
    end

    local parse_value

    local function parse_string()

        position = position + 1

        local result = {}

        while position <= #str do

            local char = str:sub(position, position)

            if char == '"' then
                position = position + 1
                return table.concat(result)
            end

            if char == "\\" then

                position = position + 1

                local escaped = str:sub(position, position)

                local escapes = {
                    ['"'] = '"',
                    ["\\"] = "\\",
                    ["/"] = "/",
                    ["b"] = "\b",
                    ["f"] = "\f",
                    ["n"] = "\n",
                    ["r"] = "\r",
                    ["t"] = "\t"
                }

                if not escapes[escaped] then
                    error("Invalid JSON escape.")
                end

                table.insert(result, escapes[escaped])

            else
                table.insert(result, char)
            end

            position = position + 1
        end

        error("Unterminated JSON string.")
    end

    local function parse_object()

        position = position + 1

        local object = {}

        skip_whitespace()

        if str:sub(position, position) == "}" then
            position = position + 1
            return object
        end

        while true do

            skip_whitespace()

            if str:sub(position, position) ~= '"' then
                error("Expected JSON object key.")
            end

            local key = parse_string()

            skip_whitespace()

            if str:sub(position, position) ~= ":" then
                error("Expected ':' after object key.")
            end

            position = position + 1

            object[key] = parse_value()

            skip_whitespace()

            local char = str:sub(position, position)

            if char == "}" then
                position = position + 1
                return object
            elseif char == "," then
                position = position + 1
            else
                error("Expected ',' or '}' in object.")
            end
        end
    end

    parse_value = function()

        skip_whitespace()

        local char = str:sub(position, position)

        if char == '"' then
            return parse_string()
        elseif char == "{" then
            return parse_object()
        elseif str:sub(position, position + 3) == "true" then
            position = position + 4
            return true
        elseif str:sub(position, position + 4) == "false" then
            position = position + 5
            return false
        elseif str:sub(position, position + 3) == "null" then
            position = position + 4
            return nil
        else
            local number = str:match(
                "^-?%d+%.?%d*[eE]?[+-]?%d*",
                position
            )

            if number and number ~= "" then
                position = position + #number
                return tonumber(number)
            end
        end

        error("Invalid JSON value at position " .. position)
    end

    local result = parse_value()

    skip_whitespace()

    if position <= #str then
        error("Unexpected content after JSON value.")
    end

    return result
end

return JSON