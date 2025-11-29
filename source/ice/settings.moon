import Validation from require "ice.core.validation"
import Logger, Log from require "ice.core.logger"

global_warnings_table = { }
global_settings_table = { }

class Setting
    @get = (key) =>
        unless global_settings_table[key]
            Log\error "Trying to access unknown setting: '#{key}'"
            return nil, false

        success, errmsg = global_settings_table[key]\validate!
        if success
            return global_settings_table[key].value, true
        else
            Log\error errmsg
        return nil, false

    @ref = (key) =>
        -> Setting\get key

    new: (@key, args = {}) =>
        @path, @name = @key\match "^(.*)%.([%w_]+)$"
        Validation\assert @path and @name, "Settings key '#{@key}' is missing a path and/or name"

        -- Save this setting in the global table
        Validation\assert global_settings_table[@key] == nil, "A setting with key '#{@key}' was already defined!"
        global_settings_table[@key] = @

        @isdefault = 'Default value'
        @properties = { }
        known_properties = {
            'required':true
            'default':true
            'predicate':true
            'type_hint':true
            'description':true
            'desc':true
        }

        if args.default ~= nil
            Log\warning "(#{@key}) The 'required' property is not functional when a default value is set" if args.required

            if args.type_hint
                Validation\assert (type args.default) == args.type_hint, "The 'default' property does not match 'type_hint' value in setting '#{key}'"
            else
                args.type_hint = type args.default

            if args.predicate
                Validation\assert (type args.predicate) == 'function', "The 'predicate' property is not a valid function object in setting '#{key}'"
                success, errmsg = args.predicate args.default
                unless success
                    errmsg = errmsg or "Default value '#{args.default}' failed predicate for setting '#{@key}'"
                    Validation\assert success, errmsg if @properties.required
                    -- Log\warning errmsg if not @properties.required

        elseif args.type_hint == nil
            @properties.type_hint = 'ANY'

        for prop, value in pairs args
            if known_properties[prop]
                @properties[prop] = value
            else
                Log\warning "Unknown property '#{prop}' on setting '#{@key}'"

    validate: (value, force) =>
        return @validation_result, "" if @validated and not force
        @value = @properties.default unless @value -- Set the value from the default value
        value = @value unless force

        @validated = not force
        @validation_result = false
        if value == nil and @properties.required
            return false, "Missing value for required setting '#{@key}'"
        if @properties.predicate
            success, errmsg = @properties.predicate value
            unless success
                errmsg = errmsg or "#{@isdefault} '#{value}' failed predicate for setting '#{@key}'"
                return false, errmsg if @properties.required
                unless global_warnings_table[@] and not @properties.required
                    global_warnings_table[@] = true
                    Log\warning errmsg
                @validated = false
                return true, errmsg

        if @properties.type_hint ~= "ANY" and (type value) ~= @properties.type_hint
            return false, errmsg or "Setting '#{@key}' value '#{value}' does not match the expected type '#{type value}' != '#{@properties.type_hint}'" unless success

        @validation_result = true
        return true

    set: (value) =>
        @validated = false
        @isdefault = 'Value' if value
        @value = value or @properties.default
        @value

    _get_or_create_path_table = (tab, path) ->
        for sub_key in path\gmatch "([^%.]+)"
            if tab[sub_key] == nil
                tab[sub_key] = { }
            tab = tab[sub_key]
        return tab

    schema: (target) =>
        dst_tab = (_get_or_create_path_table target, @path)
        dst_tab[@name] = @schema_info!

    schema_info: (target) =>
        {
            key:@key
            name:@name,
            path:@path,
            type:@properties.type_hint or 'ANY',
            default:@properties.default
            description:@properties.desc or @properties.description
            required:@properties.required and 'true' or 'false'
        }

    setting_info: (target) =>
        {
            key:@key
            name:@name,
            path:@path,
            value:@value
            required:@properties.required and 'true' or 'false'
        }

    serialize: (target) =>
        dst_tab = (_get_or_create_path_table target, @path)
        dst_tab[@name] = @value or @properties.default
        if not dst_tab[@name] and @properties.required
            dst_tab["MISSING_" .. @name] = "This value is required. Remove the 'MISSING_' prefix and provide a valid value."

    deserialize: (source, target) =>
        src_tab = (_get_or_create_path_table source, @path)
        if target
            dst_tab = (_get_or_create_path_table target, @path)
            dst_tab[@name] = @\set src_tab[@name]
        else
            @\set src_tab[@name]

class Settings
    @get = (key) => Setting\get key
    @ref = (key) => Setting\ref key

    @set = (key, value) =>
        unless global_settings_table[key]
            Log\error "Trying to access unknown setting: '#{key}'"
            return false

        success, errmsg = global_settings_table[key]\validate value, true
        if success
            -- Skip setting the value if a error message was still included (this means the settings failed validation but was not required)
            global_settings_table[key]\set value unless errmsg
            return true
        else
            Log\error "New value '#{value}' for setting '#{key}' failed validation with error:"
            Log\error errmsg
        return false

    @serialize = =>
        serialized_settings = { }
        for _, setting in pairs global_settings_table
            setting\serialize serialized_settings
        serialized_settings

    @deserialize = (settings_table) =>
        for _, setting in pairs global_settings_table
            setting\deserialize settings_table, nil -- We could store the values to a table if necessary

    @list = (args = { }) =>
        result = { }
        for key, setting in pairs global_settings_table
            table.insert result, setting\setting_info!
        table.sort result, (a, b) -> a.path < b.path
        result

    @schema = (args = { }) =>
        result = { }
        for key, setting in pairs global_settings_table
            setting\schema result
        result

{ :Setting, :Settings }
