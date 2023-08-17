
import File from require "ice.core.fs"
import Log from require "ice.core.logger"

class INIConfig
    @open = (path, args = {}) =>
        if file = File\open path, mode:'rb'
            return INIConfig file, args

    @save = (path, sections) =>
        if file = File\open path, mode:'wb+'
            for section, values in pairs sections
                file\write "\n[#{section}]\n"
                if #values > 0
                    file\write "#{value}\n" for value in *values
                else
                    sorted_values = [{:key, :value} for key, value in pairs values]
                    table.sort sorted_values, (a, b) -> a.key < b.key

                    file\write "#{key}=#{value}\n" for { :key, :value } in *sorted_values
            file\close!

    new: (@file, args) =>
        @dbg_print = args.debug or false

        @sections = { default:{} }
        @sections_meta = { }
        @current_section = 'default'

        for line in @file\lines!
            line = line\gsub '[\n\r]', ''
            if (line\match "::") or (line\match "^[ \t]*$")
                nil -- Comment or empty line
            elseif section_name = line\match "%[([a-zA-Z0-9%-_%.:]+)%]"
                @new_section section_name
            elseif key = line\match "([a-zA-Z0-9%-_%.:]+)="
                value = line\sub (#key + 2)
                @new_entry key, value
            else
                @new_value line

    section: (name, expected_type) =>
        return @sections[name], @sections_meta[name] unless expected_typ
        return @sections[name] if expected_type == @sections_meta[name].type

    section_type: (name) => @sections_meta[name].type

    new_section: (name) =>
        Log\debug "New section: #{name}"
        @sections[name] = @sections[name] or { }
        @sections_meta[name] = @sections_meta[name] or { }
        @current_section = name

    new_entry: (key, value) =>
        Log\debug "New entry: #{key}=#{value}"
        section, meta = @\section @current_section
        Log\error "Section #{@current_section} was initialized with array elements" if meta.type == 'array'

        section[key] = value
        meta.type = 'map'

    new_value: (value) =>
        Log\debug "New value: #{value}"
        section, meta = @\section @current_section
        Log\error "Section #{@current_section} was initialized with key-value pairs" if meta.type == 'map'

        table.insert section, value
        meta.type = 'array'

    close: =>
        @file\close!

{ :INIConfig }
