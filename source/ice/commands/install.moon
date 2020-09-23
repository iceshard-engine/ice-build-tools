import Command, option, flag from require "ice.command"

class InstallCommand extends Command
    @arguments {
        flag 'update',
            name: '-u --update'
    }

    execute: (args, project) =>
        project.generate.conan_tools_files! if args.update
        project.generate.conan_source_files! if args.update

{ :InstallCommand }
