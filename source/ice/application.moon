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

        if @@.args
            for _, { :func, :opts } in pairs @@.args
                @parser[func] @parser, opts

        -- Go through all defined actions (table values)
        @commands = { }
        for name, command_clazz in pairs @@commands or { }
            command = command_clazz @parser\command name, command_clazz.description, command_clazz.epilog

            -- Save the object
            @commands[name] = command

    run: =>
        result = nil

        -- Execute the given command or the main handler
        args = @parser\parse arg
        if args.command
            result = @commands[args.command]\execute args
        else
            result = @execute args

        -- Translate return values to return codes
        if (type result) == "boolean"
            result = return_code:(result and 0 or -1)
        if (type result) == "number"
            result = return_code:result
        elseif (type result) == "nil"
            result = return_code:0

        -- Handle errors
        if result.return_code ~= 0
            print string.format "ERROR: %s", (result.message or "Unknown error occured!")
            os.exit result.return_code

    execute: => true


{ :Application }
