import Command, Setting, option, flag, group from require "ice.command"

import BuildCommand from require "ice.commands.build"
import FastBuild from require "ice.tools.fastbuild"
import VStudio, VSCode from require "ice.tools.vswhere"

import VSCodeProjectGen from require "ice.generators.devenv.vscode"
import INIConfig from require "ice.util.iniconfig"

import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"
import Path, File, Dir from require "ice.core.fs"

class DevenvCommand extends Command
    @settings {
        Setting 'devenv.default_environment', default:(os.osselect win:'vstudio', mac:'xcode', unix: 'vscode'), required:true
    }

    @arguments {
        group 'generation', description: 'DevEnv/IDE environment generation'
        option 'devenv',
            description: 'Selects the environment for which to generate files.'
            group: 'generation'
            name: '--devenv --ide'
            choices: { 'vstudio', 'vscode' }
            default: Setting\ref 'devenv.default_environment'
        option 'update',
            description: 'Updates or replaces previously generated environment files.'
            group: 'generation'
            name: '--update -u'
            argname: '<behavior>'
            choices: { 'replace', 'modify' }
            default: 'modify'
            defmode: 'arg'

        flag 'start',
            description: 'Tries to launch the selected IDE.'
            name: '--start'
    }

    prepare: (args, project) =>
        Dir\enter project.output_dir

    execute: (args, project) =>
        @fail "The 'xcode' target is not yet implemented" if args.devenv == 'xcode'

        config_file = Setting\get 'build.fbuild_config_file'

        if args.devenv == 'vscode'
            FastBuild!\build
                config:config_file
                target:'devenv-targets'
                clean:args.update ~= nil

            -- If we can open devenv_targets we continue generation
            with config = INIConfig\open "devenv_targets.txt", debug: false
                build_targets = \section 'build_targets', 'array'
                run_targets = \section 'run_targets', 'array'
                vscode_gen = VSCodeProjectGen project, exe:FastBuild!.exec, script:(Path\join project.output_dir, config_file)

                -- Known VSCode workspace files
                vscode_dir = Path\join project.workspace_dir, ".vscode"
                @fail "Failed to create required directory: '#{vscode_dir}'" unless (Dir\create vscode_dir)

                tasks_file = Path\join vscode_dir, "tasks.json"
                tasks_file_exists = File\exists tasks_file
                launch_file = Path\join vscode_dir, "launch.json"
                launch_file_exists = File\exists launch_file

                if args.update or (not tasks_file_exists)
                    if tasks_file_exists
                        if args.update == 'modify'
                            unless File\copy tasks_file, "#{tasks_file}.backup", force:true
                                @fail "Failed to create backup file for #{tasks_file}"

                        if args.update == 'replace'
                            unless File\move tasks_file, "#{tasks_file}.backup", force:true
                                @fail "Failed to create backup file for #{tasks_file}"

                    -- Generate the file
                    if vscode_gen\create_tasks_file tasks_file, build_targets, update:args.update == 'modify'
                        Log\info "Generated file: #{tasks_file}"
                    else
                        @fail "Failed to generate file: #{tasks_file}"

                if args.update or (not launch_file_exists)
                    if launch_file_exists
                        if args.update == 'modify'
                            unless os.copy_file launch_file, "#{launch_file}.backup", force:true
                                @fail "Failed to create backup file for #{launch_file}"

                        if args.update == 'replace'
                            unless os.move_file launch_file, "#{launch_file}.backup", force:true
                                @fail "Failed to create backup file for #{launch_file}"

                    launch_targets = { }
                    for target in *run_targets
                        table.insert launch_targets, (config\section target, 'map')

                    if vscode_gen\create_launch_file launch_file, launch_targets, update:args.update == 'modify'
                        Log\info "Generated file: #{launch_file}"
                    else
                        @fail "Failed to generate file: #{launch_file}"

                \close!

            -- Run Visual Studio Code
            VSCode!\start open:Path\join Dir\current!, ".." if args.start

        elseif args.devenv == 'vstudio'
            if args.update == 'modify'
                Log\warning "The 'modify' behaves like 'replace' for the Visual Studio enviroment."
                args.update = 'replace'

            FastBuild!\build
                config:config_file
                target:'vstudio'
                clean:args.update ~= nil

            -- Run Visual Studio
            VStudio!\start open:"../#{project.fastbuild_solution_name}" if args.start

{ :DevenvCommand }
