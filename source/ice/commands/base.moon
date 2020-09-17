import Command, option, flag from require "ice.command"

class BaseCommand extends Command
    @arguments {
        flag 'clean',
            name: '-c --clean'
        flag 'update_deps',
            name: '-u --update-deps'
    }

    execute: (args) =>
        {
            conan_source_update: args.update_deps
            fbuild_detect_variables: args.clean
            fbuild_workspace_script: args.clean
        }

{ :BaseCommand, :option, :flag }
