import Command, option, flag from require "ice.command"

import BuildCommand from require "ice.commands.build"
import FastBuild from require "ice.tools.fastbuild"
import VStudio from require "ice.tools.vswhere"

import VSCodeProjectGen from require 'ice.generators.devenv.vscode'

class DevenvCommand extends Command
    @settings: {
        fbuild:
            config_file: BuildCommand.settings.fbuild.config_file
            default_target: os.osselect win:'vstudio', mac:'xcode', unix: 'vscode'
    }

    @arguments {
        flag 'start',
            name: '--start'
        flag 'clean',
            name: '--clean -c'
        option 'ide',
            name: '--devenv --ide'
            choices: { 'vstudio', 'xcode', 'vscode' }
            default: @@settings.fbuild.default_target
    }

    new: (...) =>
        -- Update the default target again if it was changed in a user workspace
        (@@argument_options 'ide').default = @@settings.fbuild.default_target

        -- Call the parent ctor
        super ...

    prepare: (args, project) =>
        os.chdir project.output_dir

    execute: (args, project) =>
        error "The 'vscode' target is not yet implemented" if args.devenv == 'vscode'
        error "The 'xcode' target is not yet implemented" if args.devenv == 'xcode'

        FastBuild!\build
            config:@@settings.fbuild.config_file
            target:args.devenv
            clean:args.clean

        if args.devenv == 'vscode'
            false
        else
            -- Run Visual Studio
            if args.devenv == 'vstudio' and args.start
                unless os.iswindows
                    error "The 'VStudio' tool is available only on Windows!"
                else
                    VStudio!\start open:"../#{project.fastbuild_solution_name}"
            true

{ :DevenvCommand }
