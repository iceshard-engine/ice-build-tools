require "ice.util.os"
argparse = require "argparse"
package.moonpath ..= ";?.moon;?/init.moon"

import IBT from require "ibt.ibt"
import Logger, LogCategory, LogLevel, Log from require "ice.core.logger"
import Command, group, argument, option, flag from require "ice.command"
import Validation from require "ice.core.validation"
import Path, Dir, File from require "ice.core.fs"

class Application
    @arguments = (defined_args) =>
        @.args = { }
        for { :func, :name, :opts } in *defined_args
            opts.name = opts.name or "--#{name}"
            @.args[name] = { :func, :name, :opts }

    @arguments {
        option 'log',
            name: '-l --log'
            description: 'Changes the log level for stdout.'
            choices: {'d', 'debug', 'v', 'verbose', 'i', 'info', 'w', 'warning', 'e', 'error'}
            default: 'info'
            defmode: 'log-level'
    }

    new: (settings) =>
        Validation\assert (Dir\exists IBT.fbuild_scripts), "IBT.fbuild_scripts (#{IBT.fbuild_scripts}) does not exist! Are you running IBT in a proper conan environment?"

        @script_file = arg[1]
        @parser = argparse @@name, @@description, @@epilog
        @parser\require_command false
        @parser\command_target "command"

        init_cmd = @parser\command "init", "Used to initialize the workspace for development."
        opt = init_cmd\option "--usage"
        opt\choices {"default", "ci"}
        opt\description "Initializing for a specific usage scenario. 'ci' will generate additional files to reduce platform-specific code on CI workflows."

        -- init_cmd\option "--update-tools", "Updates the tool dependencies."
        -- init_cmd\option "-p --profile", "A profile that should be used to generate conan profile files. This profile will affect the picked dependencies."

        if @@.args
            for _, { :func, :opts } in pairs @@.args
                @parser[func] @parser, opts

        logv = nil
        for val in *arg
            if logv == '.next'
                logv = val
                break
            else if val == '-l' or val == '--log'
                logv = '.next'
            else if val[1] ~= '-'
                break

        if logv
            lvlmap = {
                'd':LogLevel.Debug, 'dbg':LogLevel.Debug, 'debug':LogLevel.Debug,
                'v':LogLevel.Verbose, 'verbose':LogLevel.Verbose,
                'i':LogLevel.Info, 'info':LogLevel.Info,
                'w':LogLevel.Warning, 'warning':LogLevel.Warning,
                'e':LogLevel.Error, 'error':LogLevel.Error
            }

            -- Initialize global logger if it wasn't done yet
            Logger\init stdout:{ level:lvlmap[logv] }

        -- Go through all defined actions (table values)
        @commands = { }
        for name, command_clazz in pairs @@commands or { }
            command_object = @parser\command name, command_clazz.description, command_clazz.epilog
            command_object\help_max_width 80

            -- Save the object
            @commands[name] = command_clazz command_object, settings
            @commands[name].name = name
            @commands[name].log = Logger\create (LogCategory command_clazz.logtag or name)

        for name, command in pairs @commands
            command\init_internal!
        @parser\add_help_command!

        success, result = @parser\pparse arg
        Validation\assert "Failed argument parsing with error: #{result}"
        @args = result

    run: (project) =>
        result = nil

        -- Execute the given command or the main handler
        args = @args
        if args.command == 'init'
            if args.usage == 'ci'
                script = ""
                script = (Path\join os.cwd!, project.script) unless Path\is_absolute project.script
                contents = "$ScriptArgs = ($Args -join ' ')\n"
                contents ..= "$ScriptFile = \"#{script}\"\n"
                contents ..= "if ($IsLinux) {\n"
                contents ..= "  bash $ScriptFile $ScriptArgs\n"
                contents ..= "} elseif ($IsWindows -or [System.Environment]::OSVersion.Platform -eq 'Win32NT') {\n"
                contents ..= "  cmd /C $ScriptFile $ScriptArgs\n"
                contents ..= "}\n"
                File\save (Path\join os.cwd!, "ibt-ci.ps1"), contents

        elseif args.command

            old_dir = os.cwd!
            command = @commands[args.command]

            -- Recreate the logger with additional verbosity if set
            command.log = Logger\create command.log.category, stdout:{level:LogLevel.Verbose} if args.verbose

            -- We only validate setting for the current command to avoid setting everything when not necessary!
            errors = command\validate_settings!
            for errmsg in *errors
                Log\error errmsg if errmsg ~= ""
            return if #errors > 0

            fn_prepare = command\run_prepare
            fn_execute = command\run_execute

            if (fn_prepare args, project)\validate!
                exec_result = (fn_execute args, project)\validate!

            os.chdir old_dir
        else
            result = @execute args, project

        -- Translate return values to return codes
        result or { }

    execute: =>
        Log\info "#{@@name} CLI - (IBT/#{IBT.version}@#{IBT.conan.user}/#{IBT.conan.channel})"
        Log.raw\info '\nFor more options see the -h,--help output.'


{ :Application }
