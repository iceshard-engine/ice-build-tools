import Command, option, flag from require "ice.command"

class BaseCommand extends Command
    @arguments {
        flag 'install',
            name: '--install'
    }

    execute: (args) =>
        {
            conan_source_update: args.install
        }

{ :BaseCommand }
