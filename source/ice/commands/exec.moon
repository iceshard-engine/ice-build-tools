import BaseCommand, argument, option, flag from require 'ice.commands.base'

class ExecCommand extends BaseCommand
    @settings: { }
    @arguments {
        argument 'cmdline',
            description: 'Runs the given command line in the local Conan environment.'
            argname: { 'command line' }
            args: '*'
    }

    new: (parser) =>
        parser\handle_options false
        parser\add_help false
        super parser

    execute: (args, project) =>
        cmdline = table.concat args.cmdline, ' '
        retcode = os.execute cmdline

        {
            return_code: retcode
            message: "Command line '#{cmdline}' failed with return code #{retcode}."
        }


{ :ExecCommand }
