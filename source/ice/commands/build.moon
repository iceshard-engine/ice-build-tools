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
        option 'list_targets',
            name: '-l --list-targets'
            default: '*'
            defmode: 'arg'
        option 'summary',
            name: '-s --summary'
            choices: { "off", "success", "always" }
            default: 'off'
        flag 'clean',
            name: '-c --clean'
        flag 'verbose',
            name: '-v --verbose'
        flag 'match',
            name: '-m --match'
            description: 'Enables IBT to match targets based on the values passed to \'--target\'. Use \'--list-targets\' to explore targets.'
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
        -- Remove lines we don't want
        bad_matches = {
            'devenv_targets.txt'
            'devenv%-targets'
            'vstudio'
            '-vcxproj'
            '-Build'
            '-Link'
        }

        if args.list_targets
            pattern = args.list_targets\gsub '*', '%.*'
            targets = @gather_targets pattern, bad_matches

            print "List of targets matching the pattern '#{args.list_targets}'"
            print target for target in *targets

        else
            if args.match
                new_targets = { }
                for target_pattern in *args.target
                    table.insert new_targets, target for target in *(@gather_targets target_pattern, bad_matches)
                args.target = new_targets

            FastBuild!\build
                config:@@settings.fbuild.config_file
                target:table.concat args.target, ' '
                clean:args.clean
                monitor:args.monitor
                distributed:args.dist
                summary:args.summary == 'always'
                nosummaryonerror:args.summary == 'success'
                verbose:args.verbose

    -- Helpers
    gather_targets: (pattern, excluded = { }) =>
        fn = FastBuild!\list_targets!\gmatch "([%w_%-:%. ]+)\n"
        lines = [line for line in fn]

        -- Helper method
        matches_none = (table, match_list, cb) ->
            results = { }
            for line in *table
                matched = false
                for match_value in *match_list
                    matched or= line\match match_value

                if not matched and line\lower!\match pattern\lower!
                    cb line


        -- Remove first and last lines (fbuild output text)
        table.remove lines, #lines
        table.remove lines, 1

        -- Remove matching lines
        targets = { }
        matches_none lines, excluded, (line) ->
            table.insert targets, line

        -- Sort and show
        table.sort targets, (a, b) -> a < b
        targets

{ :BuildCommand }
