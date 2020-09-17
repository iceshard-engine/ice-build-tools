import BaseCommand, option, flag from require "ice.commands.base"
import FastBuild from require "ice.tools.fastbuild"

import VStudio from require "ice.tools.vswhere"

class VStudioCommand extends BaseCommand
    @arguments {
        BaseCommand.args.clean
        BaseCommand.args.update_deps
        flag 'start',
            name: '--start'
    }

    execute: (args) =>
        result = super args
        result.execute_location = 'output_directory'
        result.execute = (prj) ->
            FastBuild!\build
                config:'fbuild.bff'
                target:'solution'
                clean:args.clean

            VStudio!\start open:"../#{prj.solution_name}" if args.start

        result

{ :VStudioCommand }
