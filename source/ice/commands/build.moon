import BaseCommand, option, flag from require "ice.commands.base"
import FastBuild from require "ice.tools.fastbuild"

class BuildCommand extends BaseCommand
    @arguments {
        BaseCommand.args.clean
        BaseCommand.args.update_deps
        option 'target',
            name: '-t --target'
            default: 'all-x64-Develop'
        flag 'verbose',
            name: '-v --verbose'
    }

    prepare: (args, project) =>
        super args, project

        os.chdir project.output_directory

    execute: (args) =>
        FastBuild!\build
            config:'fbuild.bff'
            target:args.target
            clean:args.clean
            monitor:true
            distributed:true
            summary:false
            verbose:args.verbose

        true

{ :BuildCommand }
