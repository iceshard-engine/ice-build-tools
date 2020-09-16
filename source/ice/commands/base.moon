import Command, option, flag from require "ice.command"

class BaseCommand extends Command
    @arguments {
        flag 'install',
            name: '--install'
        flag 'clean',
            name: '-c --clean'
    }

    execute: (args) =>
        {
            conan_source_update: args.install
            fbuild_detect_variables: args.clean
            fbuild_workspace_script: args.clean
        }

{ :BaseCommand, :option, :flag }
