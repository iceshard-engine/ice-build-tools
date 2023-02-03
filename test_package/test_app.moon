import Application from require "ice.application"
import Command, option, flag from require "ice.command"

class PrintCommand extends Command
    @arguments {
        option "text", {
            name: '-t'
            optional:true
        }
    }
    execute: (args) =>
        print "Hello world!" if not args.t
        print args.t if args.t

class HelloWorldCommand extends Command
    @arguments { PrintCommand.args.text }
    execute: (args) =>
        super\execute args

class TestApp extends Application
    @commands: {
        'hello': HelloWorldCommand
    }
    execute: =>



with TestApp { }
    \run!
