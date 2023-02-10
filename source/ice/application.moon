require "ice.util.os"
argparse = require "argparse"
package.moonpath ..= ";?.moon;?/init.moon"

import IBT from require "ibt.ibt"
import Logger, LogCategory, Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

import Dir from require "ice.core.fs"

handle_result_value = (result, table_only) ->
    final_result = nil
    if (type result) == "boolean"
        final_result = return_code:(result and 0 or -1)
    elseif (type result) == "number"
        final_result = return_code:result
    elseif (type result) == "table"
        if result.return_code ~= nil
            final_result = result
        else
            final_result = return_code:0, value:result
    elseif (type result) == "nil"
        final_result = return_code:0

    -- Handle errors
    if final_result.return_code ~= 0
        -- print string.format "ERROR: [%d] %s", final_result.return_code, (final_result.message or "Unknown error occured!")
        os.exit 1

    final_result.value or table_only

class Application
    @arguments = (defined_args) =>
        @.args = { }
        for { :func, :name, :opts } in *defined_args
            opts.name = opts.name or "--#{name}"
            @.args[name] = { :func, :name, :opts }

    new: (settings) =>
        -- Initialize global logger if it wasn't done yet
        Logger\init { }

        Validation\assert (Dir\exists IBT.fbuild_scripts), "IBT.fbuild_scripts (#{IBT.fbuild_scripts}) does not exist! Are you running IBT in a proper conan environment?"

        @script_file = arg[1]
        @parser = argparse @@name, @@description, @@epilog
        @parser\require_command false
        @parser\command_target "command"

        init_cmd = @parser\command "init", "Used to initialize the workspace for development."
        init_cmd\option "--update-tools", "Updates the tool dependencies."
        init_cmd\option "-p --profile", "A profile that should be used to generate conan profile files. This profile will affect the picked dependencies."

        if @@.args
            for _, { :func, :opts } in pairs @@.args
                @parser[func] @parser, opts

        -- Go through all defined actions (table values)
        @commands = { }
        for name, command_clazz in pairs @@commands or { }
            command_object = @parser\command name, command_clazz.description, command_clazz.epilog
            command_object\help_max_width 80

            -- Save the object
            @commands[name] = command_clazz command_object, settings
            @commands[name].log = Logger\create (LogCategory command_clazz.logtag or name)

        for name, command in pairs @commands
            command\init_internal!
        @parser\add_help_command!

        @args = @parser\parse arg

    run: (project) =>
        result = nil

        -- Execute the given command or the main handler
        args = @args
        if args.command
            old_dir = os.cwd!

            -- We only validate setting for the current command to avoid setting everything when not necessary!
            errors = @commands[args.command]\validate_settings!
            for errmsg in *errors
                Log\error errmsg if errmsg ~= ""
            return if #errors > 0

            if handle_result_value (@commands[args.command]\run_prepare args, project), true
                result = handle_result_value (@commands[args.command]\run_execute args, project)
            os.chdir old_dir
        else
            result = @execute args, project

        -- Translate return values to return codes
        result or { }

    execute: =>
        Log\info "#{@@name} CLI - (IBT/#{IBT.version}@#{IBT.conan.user}/#{IBT.conan.channel})"
        Log.raw\info '\nFor more options see the -h,--help output.'


{ :Application }
