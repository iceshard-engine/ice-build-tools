
import Log from require "ice.core.logger"

class Validation
    @check = (value, message, ...) =>
        Log\warning string.format(message, ...) if not value
        return value

    @ensure = (value, message, ...) =>
        Log\error string.format(message, ...) if not value
        return value

    @assert = (value, message, ...) =>
        if not value
            message = string.format(message, ...)
            Log\error message
            error (Log\format message), 2

class Match
    @table = (data, checks) =>
        result = true
        issues = { }
        for data_key, check in pairs checks or { }
            fn = -> true
            is_required = false
            is_table = (type check) == "table"
            data_value = data[data_key]

            -- Prepare check information
            if is_table
                if check.pattern
                    fn = (str) -> (type str) == 'string' and (str\match check.pattern) ~= nil
                elseif check.min or check.max
                    check_min = (val) -> val >= check.min if check.min else -> true
                    check_max = (val) -> val <= check.max if check.max else -> true
                    fn = (val) -> (type val) == 'number' and (check_min val) and (check_max val)
                elseif check.fn
                    fn = check.fn
                is_required or= (check.required == true)

            elseif (type check) == 'function'
                fn = check


            -- Run the check and gather results
            check_result = fn data_value if data_value
            Log\debug "[Match.table] Match result after function call was '#{check_result}' for value '#{data_value}'" if data_value

            check_result = (not is_required) unless data_value
            Log\debug "[Match.table] Match result is '#{check_result}' because non existing value, 'required' == '#{is_required}'" unless data_value

            check_result = check_result or false
            Log\debug "[Match.table] Final match result for '#{data_key}' is '#{check_result}'"

            if check_result == false
                if is_table and check.errmsg
                    msg_type = type check.errmsg
                    valid_type = (msg_type == 'string' or msg_type == 'function')

                    if Validation\ensure valid_type, "Invalid value provided for 'errmsg' in validator '#{data_key}'. Allowed values are 'string' or 'fn -> string'."
                        if msg_type == 'string'
                            Log\debug "[Match.table] Pushing error message from value"
                            table.insert issues, check.errmsg
                        elseif msg_type == 'function'
                            Log\debug "[Match.table] Pushing error message from function call"
                            table.insert issues, (check.errmsg data_value, {required:is_required, key:data_key})
                else
                    table.insert issues, "Matching failed for key '#{data_key}' with value '#{data_value}'"


            -- Update the result
            result and= check_result

        return result, issues



{ :Validation, :Match }
