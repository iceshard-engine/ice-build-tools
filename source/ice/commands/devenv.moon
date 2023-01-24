import Command, option, flag from require "ice.command"

import BuildCommand from require "ice.commands.build"
import FastBuild from require "ice.tools.fastbuild"
import VStudio from require "ice.tools.vswhere"

import VSCodeProjectGen from require 'ice.generators.devenv.vscode'

import INIConfig from require 'ice.util.iniconfig'

class DevenvCommand extends Command
    @settings: {
        fbuild:
            config_file: BuildCommand.settings.fbuild.config_file
            default_target: os.osselect win:'vstudio', mac:'xcode', unix: 'vscode'
    }

    @arguments {
        flag 'start',
            name: '--start'
            description: 'Launches the specified IDE for the generated workspace.'
        option 'update',
            name: '--update -u'
            description: 'Overwrites existing devenv files. Renames previous files in the process.'
            choices: { 'replace', 'modify' }
            default: 'modify'
            defmode: 'arg'
        option 'ide',
            name: '--devenv --ide'
            description: 'The IDE for which to generate workspace files.'
            choices: { 'vstudio', 'vscode' }
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
        error "The 'xcode' target is not yet implemented" if args.devenv == 'xcode'

        if args.devenv == 'vscode'
            FastBuild!\build
                config:@@settings.fbuild.config_file
                target:'devenv-targets'
                clean:args.update ~= nil

            -- If we can open devenv_targets we continue generation
            with config = INIConfig\open "devenv_targets.txt", debug: false
                build_targets = \section 'build_targets', 'array'
                run_targets = \section 'run_targets', 'array'
                vscode_gen = VSCodeProjectGen project, exe:FastBuild!.exec, script:"#{project.output_dir}/#{@@settings.fbuild.config_file}"

                -- Known VSCode workspace files
                vscode_dir = "#{project.workspace_dir}/.vscode"
                os.mkdirs vscode_dir unless os.isdir vscode_dir

                tasks_file = "#{vscode_dir}/tasks.json"
                tasks_file_exists = os.isfile tasks_file
                launch_file = "#{vscode_dir}/launch.json"
                launch_file_exists = os.isfile launch_file

                if args.update or (not tasks_file_exists)
                    if tasks_file_exists
                        if args.update == 'modify'
                            unless os.copy_file tasks_file, "#{tasks_file}.backup", force:true
                                error "Failed to create backup file for #{tasks_file}"
                        if args.update == 'replace'
                            unless os.move_file tasks_file, "#{tasks_file}.backup", force:true
                                error "Failed to create backup file for #{tasks_file}"

                    -- Generate the file
                    if vscode_gen\create_tasks_file tasks_file, build_targets, update:args.update == 'modify'
                        print "Generated file: #{tasks_file}"
                    else
                        error "Failed to generate file: #{launch_file}"

                if args.update or (not launch_file_exists)
                    if launch_file_exists
                        if args.update == 'modify'
                            unless os.copy_file launch_file, "#{launch_file}.backup", force:true
                                error "Failed to create backup file for #{launch_file}"
                        if args.update == 'replace'
                            unless os.move_file launch_file, "#{launch_file}.backup", force:true
                                error "Failed to create backup file for #{launch_file}"

                    launch_targets = { }
                    for target in *run_targets
                        table.insert launch_targets, (config\section target, 'map')

                    if vscode_gen\create_launch_file launch_file, launch_targets, update:args.update == 'modify'
                        print "Generated file: #{launch_file}"
                    else
                        error "Failed to generate file: #{launch_file}"

                \close!

        else
            if args.update == 'modify'
                print "[WARNING] The 'modify' value for '--update' behaves as 'replace' for vstuido"
                args.update = 'replace'

            FastBuild!\build
                config:@@settings.fbuild.config_file
                target:args.devenv
                clean:args.update ~= nil

            -- Run Visual Studio
            if args.devenv == 'vstudio' and args.start
                unless os.iswindows
                    error "The 'VStudio' tool is available only on Windows!"
                else
                    VStudio!\start open:"../#{project.fastbuild_solution_name}"
            true

{ :DevenvCommand }
