import Command, option, flag from require "ice.command"

import BuildCommand from require "ice.commands.build"
import FastBuild from require "ice.tools.fastbuild"
import VStudio from require "ice.tools.vswhere"

class VStudioCommand extends Command
    @settings: {
        fbuild:
            config_file: BuildCommand.settings.fbuild.config_file
            target_name:'solution'
    }

    @arguments {
        flag 'start',
            name: '--start'
    }

    prepare: (args, project) =>
        os.chdir project.output_dir

    execute: (args, project) =>
        FastBuild!\build
            config:@@settings.fbuild.config_file
            target:@@settings.fbuild.target_name
            clean:args.clean

        if args.start
            unless os.iswindows
                error "The 'VStudio' tool is available only on Windows!"
            else
                VStudio!\start open:"../#{project.fastbuild_solution_name}"
        true

{ :VStudioCommand }
