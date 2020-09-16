import BaseCommand, option, flag from require "ice.commands.base"
import FastBuild from require "ice.tools.fastbuild"

class BuildCommand extends BaseCommand
    @arguments {
        BaseCommand.args.install
        BaseCommand.args.clean
        option 'target',
            name: '-t --target'
            default: 'all-x64-Develop'
        flag 'verbose',
            name: '-v --verbose'
    }

    execute: (args) =>
        result = super args
        result.execute_location = 'output_directory'
        result.execute = ->
            FastBuild!\build
                config:'fbuild.bff'
                target:args.target
                clean:args.clean
                monitor:true
                distributed:true
                summary:false
                verbose:args.verbose

        result

{ :BuildCommand }
