argument = (name, tab) -> func:'argument', name:name, opts:tab or { }
option = (name, tab) -> func:'option', name:name, opts:tab or { }
flag = (name, tab) -> func:'flag', name:name, opts:tab or { }
group = (name, tab) -> func:'group', name:name, opts:tab or { }

import Validation from require "ice.core.validation"
import Logger, Log from require "ice.core.logger"

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

{ :Command, :argument, :option, :flag, :group }
