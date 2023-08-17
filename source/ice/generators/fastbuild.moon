
serialize_value = (value) ->
    value_type = type value
    if value_type == "boolean" or value_type == "number"
        return "#{value}"
    if value_type == "string"
        if (value\sub 1, 1) ~= '.'
            return "'#{value}'"
        else
            return "#{value}"
    error "ERROR: Value of type #{value_type} is not supported!"

class FastBuildGenerator
    new: (@output, @parent, @indent = "") =>
        unless @parent
            @file = io.open @output, 'w+'
            @file\write "// This file is generated!\n// Do not modify on your own!\n"

        else
            @file = @parent.file

    indented: (fn) =>
        fn FastBuildGenerator nil, @, "#{@indent}    " if (type fn) == "function"

    variables: (vars) =>
        for { [1]:name, [2]:value } in *vars
            if (type value) ~= "table"
                @\line ".#{name} = #{serialize_value value}"
            else
                @\line ".#{name} = {"
                @\indented =>
                    @line "#{serialize_value entry}" for entry in *value
                @\line "}"

    structure: (name, fn) =>
        @\line ".#{name} ="
        @\line "["
        @\indented fn
        @\line "]"

    compiler: (info) =>
        @\line "Compiler( '#{info.name}' )"
        @\line '{'
        @\indented =>
            vars = { { 'Executable', info.executable } }
            table.insert vars, { 'UseLightCache_Experimental', true } if info.light_cache
            table.insert vars, { 'CompilerFamily', info.compiler_family } if info.compiler_family

            @\variables vars

            if info.extra_files and #info.extra_files > 0
                @\line ".ExtraFiles = {"
                @\indented =>
                    @\line "'#{value}'" for value in *info.extra_files
                @\line "}"

        @\line '}'

    include: (path) =>
        @\line_raw "#include \"#{path}\""

    line: (value) =>
        if value
            @file\write "#{@indent}#{value or ''}\n"
        else
            @file\write '\n'


    line_raw: (value) =>
        @file\write "#{value or ''}\n"

    close: => @file\close!

{ :FastBuildGenerator }
