import BaseCommand, option, flag from require "ice.commands.base"
import FastBuild from require "ice.tools.fastbuild"

class BuildCommand extends BaseCommand
    @arguments {
        option 'target',
            name: '-t --target'
            default: 'all-x64-Develop'
        option 'summary',
            name: '-s --summary'
            choices: { "off", "success", "always" }
            default: 'off'
        flag 'clean',
            name: '-c --clean'
        flag 'verbose',
            name: '-v --verbose'
    }

    prepare: (args, project) =>
        os.chdir project.output_dir

    execute: (args) =>
        FastBuild!\build
            config:'fbuild.bff'
            target:args.target
            clean:args.clean
            monitor:true
            distributed:true
            summary:args.summary == 'always'
            nosummaryonerror:args.summary == 'success'
            verbose:args.verbose

{ :BuildCommand }
