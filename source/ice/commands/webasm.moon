import Command, group, argument, option, flag from require "ice.command"
import Exec, Where from require "ice.tools.exec"
import BuildCommand from require "ice.commands.build"

import Path, Dir, File from require "ice.core.fs"
import Validation from require "ice.core.validation"
import Setting from require "ice.settings"
import Log from require "ice.core.logger"
import WebAsm from require "ice.platform.webasm"

import INIConfig from require "ice.util.iniconfig"
import Json from require "ice.util.json"
import IBT from require "ibt.ibt"

class WebAsmCommand extends Command
    @settings {
        Setting 'webasm.projects', default:{}
        Setting 'webasm.emscripten.location', default:'build/emscripten'
        Setting 'webasm.emscripten.version', default:'latest'
    }
    @arguments {
        group 'general', description: "Basic options"
        argument 'mode',
            group: 'general'
            description: 'Selects the mode in which the command operates.'
            name: 'mode'
            choices: { 'host', 'setup' }
            default: 'host'
        flag 'verbose',
            group: 'general'
            description: 'Increase verbosity of this command'
            name: '-v --verbose'
        group 'host', description: "Host options"
        option 'project',
            group: 'host'
            description: 'The project to be hosted using a simple HTTP server.'
            name: '-p --project'
            argname: '<project>'
        option 'config',
            group: 'host'
            description: 'The project configuration to be hosted'
            name: '-c --config'
            argname: 'configuration'
            default: 'Develop'
        flag 'build',
            group: 'host'
            description: 'Builds the project before starting a host window'
            name: '-b --build'
        option 'host',
            group: 'host'
            description: 'The host address that should be used.'
            name: '--host'
            argname: 'address'
            default: '0.0.0.0'
        option 'port',
            group: 'host'
            description: 'The port at which the server should serve.'
            name: '--port'
            argname: 'port'
            default: '8000'
        group 'setup', description: "Setup options"
        flag 'reinstall',
            group: 'setup'
            description: 'Reinstalls the SDK from scratch.'
            name: '--reinstall'
    }

    prepare: (args, project) =>
        @requires_conan = args.mode != 'setup'

    execute: (args, project) =>
        return @execute_setup args, project if args.mode == 'setup'
        return @execute_host args, project

    execute_host: (args, project) =>
        return unless Validation\ensure args.project, "Missing valid 'project' to be hosted"

        -- Find the executable
        python3 = Where\exec 'python3'
        Validation\assert python3, "Failed to find a valid python3 instance."
        @log\verbose "Found python3 instance: #{python3.exec}"

        http_server = Path\join IBT.python_scripts, 'webasm/http_server.py'
        Validation\assert (File\exists http_server), "IBT HTTP server script not found!"
        @log\verbose "Found server script: #{http_server}"

        -- TODO: Rename the targets file so it's no longer 'devenv' only.
        targets_file = Path\join project.output_dir, 'devenv_targets.txt'
        unless File\exists targets_file
            BuildCommand\fbuild target:'devenv-targets', clean:(args.update~=nil)
            Validation\assert (File\exists targets_file), "Failed to generate targets file: #{targets_file}"
        @log\verbose "Found targets file: #{targets_file}"

        -- Find all possible run targets
        selected_target = nil
        with config = INIConfig\open targets_file, debug: false
            for targetid in *\section 'build_targets', 'array'
                target = \section targetid, 'map'
                if target and target.platform == 'WebAsm' and target.name == args.project and target.config == args.config
                    selected_target = target
                    selected_target.id = targetid
                    break

        -- Build the target if requested
        if args.build
            BuildCommand\fbuild target:selected_target.id

        @fail "Target for project #{args.project} (#{args.config}) does not exist" if selected_target == nil
        serving_path = Path\parent selected_target.executable
        Dir\enter serving_path, ->
            -- Build the parameter list
            params = "#{http_server}"
            params ..= " --host #{args.host}"
            params ..= " --port #{args.port}"

            -- Start the server in a new shell
            os.execute('start cmd /k call "'..(Path\normalize python3.exec)..'" '..params..'')

    execute_setup: (args, project) =>
        location = (Setting\get 'webasm.emscripten.location') or 'build/webasm'
        version = (Setting\get 'webasm.emscripten.version') or 'latest'

        unless WebAsm\install_emscripten_sdk location, force:args.reinstall, version:version
            @fail "Failed to install web-assembly SDK"

{ :WebAsmCommand }
