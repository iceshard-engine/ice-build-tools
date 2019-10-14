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
        result = true
    
        args = @parser\parse arg
        if args.command
            result = @commands[args.command]\execute args
        else
            result = @execute args
            
        -- Fail the application if the command returned false
        os.exit -1 if not result

    execute: =>


{ :Application }
