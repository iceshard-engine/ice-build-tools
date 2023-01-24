import Command, option, flag from require "ice.command"

import FastBuild from require "ice.tools.fastbuild"

class BuildCommand extends Command
    @settings: {
        fbuild:
            config_file: 'fbuild.bff'
        default_target: 'all-x64-Release'
    }

    @arguments {
        option 'target',
            name: '-t --target'
            count: '*'
            default: @settings.default_target
        option 'summary',
            name: '-s --summary'
            choices: { "off", "success", "always" }
            default: 'off'
        flag 'clean',
            name: '-c --clean'
        flag 'verbose',
            name: '-v --verbose'
        flag 'monitor'
        flag 'dist'
    }

    new: (...) =>
        -- Update the default target again if it was changed in a user workspace
        (@@argument_options 'target').default = @@settings.default_target

        -- Call the parent ctor
        super ...

    prepare: (args, project) =>
        os.chdir project.output_dir

    execute: (args) =>
        FastBuild!\build
            config:@@settings.fbuild.config_file
            target:table.concat args.target, ' '
            clean:args.clean
            monitor:args.monitor
            distributed:args.dist
            summary:args.summary == 'always'
            nosummaryonerror:args.summary == 'success'
            verbose:args.verbose

{ :BuildCommand }
