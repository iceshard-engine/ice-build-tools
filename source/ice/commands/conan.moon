import Command, argument, option, flag, group from require "ice.command"
import BuildCommand from require "ice.commands.build"
import Path from require "ice.core.fs"

class ConanCommand extends Command
    @arguments {
        argument 'task',
            description: 'The task to be performed regarding depencenies handled by conan.'
            choices: { 'create' }
            required: true
        group 'create', description: "Executing build for conan 'create' command"
        option 'config',
            description: 'The Conan configuration to be build.'
            group: 'create'
            name: '-c --config'
            choices: { 'Debug', 'Release' }
            default: 'Release'
        option 'arch',
            description: 'The Conan architecture to be build.'
            group: 'create'
            name: '-a --arch'
            required: true
    }

    prepare: (args, project) =>

    execute: (args, project) =>
        return @_create_package_build args, project if args.task == 'create'

    -- Helper methods / task implementations
    _create_package_build: (args, project) =>
        bad_matches = {
            'clean'
            'devenv_targets.txt'
            'devenv%-targets'
            'vstudio'
            '-vcxproj'
            '-Build'
            '-Link'
        }

        -- Only select specific targets for the given arch and configuration
        targets = BuildCommand\gather_targets "all%-#{args.arch}%-#{args.config}", bad_matches
        @fail "No targets available for the given architecture and configuration: #{args.arch}-#{args.config}" unless targets and #targets > 0

        -- Generate the conan modules info
        project.action.build_conan_modules {
            {
                name:"Conan-#{args.config}"
                location:Path\join project.output_dir, 'tools'
            }
        }

        -- Build the binaries
        BuildCommand\fbuild
            target:targets

{ :ConanCommand }
