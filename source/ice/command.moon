argument = (name, tab) -> func:'argument', name:name, opts:tab or { }
option = (name, tab) -> func:'option', name:name, opts:tab or { }
flag = (name, tab) -> func:'flag', name:name, opts:tab or { }
group = (name, tab) -> func:'group', name:name, opts:tab or { }

import Validation from require "ice.core.validation"
import Logger, Log from require "ice.core.logger"

class CommandResult
    @from_values: (command, result, message, value) =>
        final_result = nil
        if (type result) == "boolean"
            final_result = return_code:(result and 0 or 1), :value
        elseif (type result) == "number"
            final_result = return_code:result, :message, :value
        elseif (type result) == "table"
            if result.return_code ~= nil
                final_result = result
            else
                final_result = return_code:0, value:value or result, :message
        elseif (type result) == "nil"
            final_result = return_code:0, :message, value:true

        CommandResult command, final_result

    new: (command, params) =>
        @return_code = params.return_code or 0
        @message = params.message or "Failed command '#{command}' with return code '#{@return_code}'"
        @result = params.value or true

    success: => @return_code == 0

    validate: =>
        unless Validation\ensure @success!, @message
            -- Becauase on most systems the max value for an exit code is 255 we limit it here after it was logged
            os.exit math.min @return_code, 255
        @result

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

        @.result = (code, message, value) =>
            coroutine.yield CommandResult\from_values @name, code, message, value
        @.fail = (message, error_code = 1) =>
            Validation\assert error_code ~= 0, "A explicit fail cannot set the 'error_code' value to '0'"
            @result error_code, message
        @.success = (value) =>
            @result 0, message, value

        fn = (...) ->
            coro_success, result, message = coroutine.resume coro, ...
            return false unless coro_success
            return true, CommandResult\from_values @name, result, message

        call_success, coro_success, cmd_result = pcall fn, args, prj
        Validation\assert (call_success and coro_success), "Error while executing command '#{@name}'"

        @.fail = nil
        @.result = nil
        @.success = nil

        cmd_result

    run_execute: (args, prj) =>
        coro = coroutine.create @\execute

        @.result = (code, message, value) =>
            coroutine.yield CommandResult\from_values @name, code, message, value
        @.fail = (message, error_code = 1) =>
            Validation\assert error_code ~= 0, "A explicit fail cannot set the 'error_code' value to '0'"
            @result error_code, message
        @.success = (value) =>
            @result 0, message, value

        fn = (...) ->
            coro_success, result, message = coroutine.resume coro, ...
            return false unless coro_success
            return true, CommandResult\from_values @name, result, message

        call_success, coro_success, cmd_result = pcall fn, args, prj
        Validation\assert (call_success and coro_success), "Error while executing command '#{@name}'"

        @.fail = nil
        @.result = nil
        @.success = nil

        cmd_result


    prepare: => nil
    execute: => true

{ :Command, :CommandResult, :argument, :option, :flag, :group }
