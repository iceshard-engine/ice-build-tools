import Command, option, flag from require "ice.command"

class InstallCommand extends Command
    @arguments {
        flag 'update',
            name: '-u --update'
    }

    execute: (args) =>
        {
            conan_tools_update: args.update
            conan_source_update: args.update
        }

{ :InstallCommand }
