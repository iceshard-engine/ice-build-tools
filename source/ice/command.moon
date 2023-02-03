argument = (name, tab) -> func:'argument', name:name, opts:tab or { }
option = (name, tab) -> func:'option', name:name, opts:tab or { }
flag = (name, tab) -> func:'flag', name:name, opts:tab or { }
group = (name, tab) -> func:'group', name:name, opts:tab or { }

import Validation from require "ice.core.validation"
import Logger, Log from require "ice.core.logger"

global_settings_table = { }

class Setting
    @get = (key) =>
        success, errmsg = global_settings_table[key]\validate!
        if success
            return global_settings_table[key].value
        else
            Log\error errmsg

    @ref = (key) =>
        -> Setting\get key


    new: (@key, args = {}) =>
        @path, @name = @key\match "^(.*)%.([%w_]+)$"
        Validation\assert @path and @name, "Settings key '#{@key}' is missing a path and/or name"

        -- Save this setting in the global table
        Validation\assert global_settings_table[@key] == nil, "A setting with key '#{@key}' was already defined!"
        global_settings_table[@key] = @

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
            if args.type_hint
                Validation\assert (type args.default) == args.type_hint, "The 'default' property does not match 'type_hint' value in setting '#{key}'"
            else
                args.type_hint = type args.default

            if args.predicate
                Validation\assert (type args.predicate) == 'function', "The 'predicate' property is not a valid function object in setting '#{key}'"
                success, errmsg = args.predicate args.default
                Validation\assert success, errmsg or "Default value '#{value}' failed predicate for setting '#{@key}'"
        elseif args.type_hint == nil
            @properties.type_hint = 'ANY'

        for prop, value in pairs args
            if known_properties[prop]
                @properties[prop] = value
            else
                Log\warning "Unknown property '#{prop}' on setting '#{@key}'"

    validate: =>
        return @validation_result, "" if @validated

        @validated = true
        @validation_result = false
        if @value == nil and @properties.required
            return false, "Missing value for required setting '#{@key}'"
        if @properties.predicate
            success, errmsg = @properties.predicate @value
            return false, errmsg or "Value '#{value}' failed predicate for setting '#{@key}'" unless success
        if @properties.type_hint ~= "ANY" and (type @value) ~= @properties.type_hint
            return false, errmsg or "Value '#{value}' does not match the expected type '#{type @value}' != '#{@properties.type_hint}'" unless success

        @validation_result = true
        return true

    set: (value) =>
        @validated = false
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
        dst_tab[@name] = {
            key:@key
            name:@name,
            path:@path,
            type:@properties.type_hint or 'ANY',
            default:@properties.default
            description:@properties.desc or @properties.description
            required:@properties.required and 'true' or 'false'
        }

    serialize: (target) =>
        table.insert (_get_or_create_path_table target, @path), {
            [@name]:@value or @properties.default
        }

    deserialize: (source, target) =>
        src_tab = (_get_or_create_path_table source, @path)
        dst_tab = (_get_or_create_path_table target, @path)
        dst_tab[@name] = @\set src_tab[@name]

class Command
    @settings = (defined_settings) =>
        @settings = { }
        @settings_list = { }
        for setting in *defined_settings
            table.insert @settings_list, setting
            setting\schema @settings

    @arguments = (defined_args) =>
        @.args = { }
        @.groups = { }
        @.ordered_args = { }
        @.ordered_groups = { }
        for { :func, :name, :opts } in *defined_args
            if func == 'group'
                @.groups[name] = { :func, name:opts.description or name, args:{} }
                table.insert @.ordered_groups, @.groups[name]

            else
                opts.name = opts.name or (func == 'argument' and name) or "--#{name}"

                @.args[name] = { :func, :name, :opts }
                if opts.group and Validation\check @.groups[opts.group] ~= nil, "Group '#{opts.group}' was not declared!"
                    table.insert @.groups[opts.group].args, @.args[name]
                else
                    table.insert @.ordered_args, @.args[name]

    @argument_options = (name) =>
        @.args[name].opts

    new: (@parser, settings) =>
        @settings = { }

        -- Load settings before continuing
        @\load_settings settings

    init_internal: =>
        -- Run init before continuing
        @\init @parser

        if @@.ordered_args
            for { :name, :args } in *@@.ordered_groups
                @parser\group name, do
                    results = { }
                    for { :func, :opts } in *args
                        if opts.default and (type opts.default) == 'function'
                            opts.default = opts.default!
                        table.insert results, @parser[func] @parser, opts
                    unpack results

            for { :func, :opts } in *@@.ordered_args
                if opts.default and (type opts.default) == 'function'
                    opts.default = opts.default!
                @parser[func] @parser, opts

        -- if @@.ordered_args
        --     groups = { default:{} }
        --     groups_order = { }

        --     for tab in *@@.ordered_args
        --         tab.group = tab.opts.group or 'default'
        --         tab.opts.group = nil
        --         unless groups[tab.group]
        --             table.insert groups_order, tab.group
        --             groups[tab.group] = { }

        --     for tab in *@@.ordered_args
        --         opts.group = nil
        --         table.insert groups[tab.group], tab

        --     for group in *groups_order
        --         for { :func, :opts } in groups[group]

    init: =>

    settings_schema: (settings) => setting\schema settings, @settings for setting in *(@@.settings_list or { })
    save_settings: (settings) => setting\serialize settings, @settings for setting in *(@@.settings_list or { })
    load_settings: (settings) => setting\deserialize settings, @settings for setting in *(@@.settings_list or { })
    validate_settings: =>
        results = {}
        for setting in *(@@.settings_list or { })
            success, errmsg = setting\validate!
            table.insert results, errmsg unless success
        results

    run_prepare: (args, prj) =>
        coro = coroutine.create @\prepare

        @.fail = (msg, error_code = -1) => coroutine.yield false, { success:false, :msg, :error_code }
        @.success = (result) => coroutine.yield true, { success:true, :result }
        fn = (...) -> coroutine.resume coro, ...

        call_success, coro_success, cmd_success, cmd_result = pcall fn, args, prj
        cmd_result = { success:false, msg:cmd_success } unless coro_success

        @.fail = nil
        @.success = nil

        unless cmd_result == nil or cmd_result.success
            @log\error cmd_result.msg
            return false
        true

    run_execute: (args, prj) =>
        coro = coroutine.create @\execute

        @.fail = (msg, error_code = -1) => coroutine.yield false, { success:false, :msg, :error_code }
        @.success = (result) => coroutine.yield true, { success:true, :result }
        fn = (...) -> coroutine.resume coro, ...

        call_success, coro_success, cmd_success, cmd_result = pcall fn, args, prj
        cmd_result = { success:false, msg:cmd_success } unless coro_success

        @.fail = nil
        @.success = nil

        unless cmd_result == nil or cmd_result.success
            @log\error cmd_result.msg
            return false
        true


    prepare: => nil
    execute: => true

{ :Command, :Setting, :argument, :option, :flag, :group }
