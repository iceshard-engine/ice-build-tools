import Command, option, flag from require "ice.command"

class InstallCommand extends Command
    @arguments {
        flag 'force_all',
            name: '-f --force'
    }

    execute: (args) =>
        {
            conan_tools_update: args.force or args.force_tools
            conan_source_update: args.force or args.force_sources
        }

{ :InstallCommand }
