import Command, option, flag from require "ice.command"

class BaseCommand extends Command
    @arguments {
        flag 'clean',
            name: '-c --clean'
        flag 'update_deps',
            name: '-u --update-deps'
    }

    prepare: (args, project) =>
        project.generate.conan_source_files! if args.clean
        project.generate.fbuild_platform_files! if args.clean
        project.generate.fbuild_workspace_files! if args.clean

    execute: (args) =>

{ :BaseCommand, :option, :flag }
