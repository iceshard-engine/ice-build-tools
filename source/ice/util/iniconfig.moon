
class INIConfig
    @open = (path, args) =>
        if file = io.open path, 'rb'
            return INIConfig file, args

    new: (@file, args) =>
        @dbg_print = (msg) =>
            print msg if args.debug

        @sections = { default:{} }
        @sections_meta = { }
        @current_section = 'default'

        for line in @file\lines!
            line = line\gsub '[\n\r]', ''
            if (line\match "::") or (line\match "^[ \t]*$")
                nil -- Comment or empty line
            elseif section_name = line\match "%[([a-zA-Z0-9%-_]+)%]"
                @new_section section_name
            elseif key = line\match "([a-zA-Z0-9%-_]+)="
                value = line\sub (#key + 2)
                @new_entry key, value
            else
                @new_value line

    section: (name, expected_type) =>
        return @sections[name], @sections_meta[name] unless expected_typ
        return @sections[name] if expected_type == @sections_meta[name].type

    section_type: (name) => @sections_meta[name].type

    new_section: (name) =>
        @dbg_print "New section: #{name}"
        @sections[name] = @sections[name] or { }
        @sections_meta[name] = @sections_meta[name] or { }
        @current_section = name

    new_entry: (key, value) =>
        @dbg_print "New entry: #{key}=#{value}"
        section, meta = @\section @current_section
        error "Section #{@current_section} was initialized with array elements" if meta.type == 'array'

        section[key] = value
        meta.type = 'map'

    new_value: (value) =>
        @dbg_print "New value: #{value}"
        section, meta = @\section @current_section
        error "Section #{@current_section} was initialized with key-value pairs" if meta.type == 'map'

        table.insert section, value
        meta.type = 'array'

    close: =>
        @file\close!

{ :INIConfig }
