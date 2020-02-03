require "ice.util.os"
argparse = require "argparse"

class Application
    new: =>
        @script_file = arg[1]
        @parser = argparse @@name, @@description, @@epilog
        @parser\require_command false
        @parser\command_target "command"

        -- Add all defined arguments
        for { :func, :args } in *@@arguments or { }
            @parser[func] @parser, unpack args

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
        elseif (type result) == "nil"
            result = return_code:0

        -- Handle errors
        if result.return_code ~= 0
            print string.format "ERROR: %s", (result.message or "Unknown error occured!")
            os.exit result.return_code

    execute: => true


{ :Application }
