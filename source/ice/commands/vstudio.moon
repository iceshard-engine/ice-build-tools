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

    prepare: (args, project) =>
        super args, project

        os.chdir project.output_dir

    execute: (args, project) =>
        FastBuild!\build
            config:'fbuild.bff'
            target:'solution'
            clean:args.clean

        VStudio!\start open:"../#{project.fastbuild_solution_name}" if args.start
        true

{ :VStudioCommand }
