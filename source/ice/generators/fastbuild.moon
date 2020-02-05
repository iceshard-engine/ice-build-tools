
serialize_value = (value) ->
    value_type = type value
    return "#{value}" if value_type == "boolean" or value_type == "number"
    return "'#{value}'" if value_type == "string"
    error "ERROR: Value of type #{value_type} is not supported!"

class FastBuildGenerator
    new: (@output, @parent, @indent = "") =>
        unless @parent
            @file = io.open @output, 'w+'
            @file\write "// This file is generated!\n// Do not modify on your own!\n"

        else
            @file = @parent.file

    variables: (vars) =>
        @\line "#{@indent}.#{name} = #{serialize_value value}" for { [1]:name, [2]:value } in *vars

    structure: (name, fn) =>
        @\line "#{@indent}.#{name} ="
        @\line "#{@indent}["
        fn FastBuildGenerator nil, @, "#{@indent}    " if (type fn) == "function"
        @\line "#{@indent}]"

    include: (path) =>
        @\line "#include \"#{path}\""

    line: (value) =>
        @file\write "#{value or ''}\n"

    close: => @file\close!

{ :FastBuildGenerator }
