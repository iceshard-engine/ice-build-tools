
serialize_value = (value) ->
    value_type = type value
    return "#{value}" if value_type == "boolean" or value_type == "number"
    return "'#{value}'" if value_type == "string"
    error "ERROR: Value of type #{value_type} is not supported!"

class FastBuildGenerator
    new: (@output) =>
        @file = io.open @output, 'w+'
        @file\write "// This file is generated!\n// Do not modify on your own!\n"

    variables: (...) =>
        @file\write ".#{name} = #{serialize_value value}\n" for { [1]:name, [2]:value } in *{...}

    close: => @file\close!

{ :FastBuildGenerator }
