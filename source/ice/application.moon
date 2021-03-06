require "ice.util.os"
argparse = require "argparse"

package.moonpath ..= ";?.moon;?/init.moon"

class Application
    @arguments = (defined_args) =>
        @.args = { }
        for { :func, :name, :opts } in *defined_args
            opts.name = opts.name or "--#{name}"
            @.args[name] = { :func, :name, :opts }

    new: =>
        @script_file = arg[1]
        @parser = argparse @@name, @@description, @@epilog
        @parser\require_command false
        @parser\command_target "command"

        init_cmd = @parser\command "init", "Used to initialize the workspace for development."
        init_cmd\option "--update_tools", "Updates the tool dependencies, this might result in a broken workspace description."
        init_cmd\option "-p --profile", "A profile that should be used to generate conan profile files. This profile will affect the picked dependencies."

        if @@.args
            for _, { :func, :opts } in pairs @@.args
                @parser[func] @parser, opts

        -- Go through all defined actions (table values)
        @commands = { }
        for name, command_clazz in pairs @@commands or { }
            command = command_clazz @parser\command name, command_clazz.description, command_clazz.epilog

            -- Save the object
            @commands[name] = command
        @args = @parser\parse arg

    run: (project) =>
        result = nil

        -- Execute the given command or the main handler
        args = @args
        if args.command
            old_dir = os.cwd!

            @commands[args.command]\prepare args, project
            result = @commands[args.command]\execute args, project
            os.chdir old_dir
        else
            result = @execute args

        -- Translate return values to return codes
        if (type result) == "boolean"
            result = return_code:(result and 0 or -1)
        elseif (type result) == "number"
            result = return_code:result
        elseif (type result) == "table"
            result = return_code:0, value:result
        elseif (type result) == "nil"
            result = return_code:0

        -- Handle errors
        if result.return_code ~= 0
            print string.format "ERROR: [%d] %s", result.return_code, (result.message or "Unknown error occured!")
            os.exit 1

        result.value or { }

    execute: => true


{ :Application }
