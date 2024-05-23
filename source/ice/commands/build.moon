import Command, option, flag, group from require "ice.command"
import Setting from require "ice.settings"
import FastBuild from require "ice.tools.fastbuild"

import Validation from require "ice.core.validation"
import Log from require "ice.core.logger"
import Dir, Path, File from require "ice.core.fs"

class BuildCommand extends Command
    @settings {
        Setting 'build.fbuild_config_file', default:'fbuild.bff'
        Setting 'build.default_target', default:'all'
    }

    @arguments {
        group 'build', description: "Configuring build behavior"
        option 'target',
            description: 'One or more targets to build.'
            group: 'build'
            name: '-t --target'
            count: '*'
            default: Setting\ref 'build.default_target'
        flag 'match',
            description: 'Enables simple matching for target selection.'
            group: 'build'
            name: '-m --match'
        flag 'clean',
            description: 'Builds the targets as if everything is out-of-date.'
            group: 'build'
            name: '-c --clean'
        flag 'dist'
            description: 'Enables distributed compilation if available.'
            group: 'build'

        group 'additional', description:'Configuring build progress feedback'
        option 'summary',
            description: 'Shows a summary of the build when it ends.'
            group: 'additional'
            name: '-s --summary'
            choices: { 'off', 'success', 'always' }
            default: 'off'
        flag 'monitor'
            description: 'Enables FastBuild monitoring using 3rdParty applications.'
            group: 'additional'

        group 'targets', description:'Working with build targets'
        option 'list_targets',
            description: 'Lists available build targets that match the pattern.'
            group: 'targets'
            name: '-l --list-targets'
            default: '*'
            defmode: 'arg'

        flag 'verbose',
            description: 'Enables verbose output of the build system.'
            name: '-v --verbose'
    }

    prepare: (args, project) =>
        Validation\ensure (Dir\enter project.output_dir), "Missing output directory '#{project.output_dir}'..."

    execute: (args) =>
        -- Remove lines we don't want
        bad_matches = {
            'clean'
            'devenv_targets.txt'
            'devenv%-targets'
            'vstudio'
            '-vcxproj'
            '-Build'
            '-Link'
        }

        if args.list_targets
            pattern = args.list_targets\gsub '-', '%-'
            pattern = pattern\gsub '*', '%.*'
            targets = BuildCommand\gather_targets pattern, bad_matches

            Log\info "List of targets matching the pattern '#{args.list_targets}'"
            Log.raw\info target for target in *targets

        else
            if args.match
                new_targets = { }
                for target_pattern in *args.target
                    table.insert new_targets, target for target in *(BuildCommand\gather_targets target_pattern, bad_matches)
                args.target = new_targets

            -- Execute fastbuild with given arguments
            BuildCommand\fbuild args

    -- Helpers
    @gather_targets: (pattern, excluded = { }) =>
        config_file = Setting\get 'build.fbuild_config_file'
        unless File\exists config_file
            output_dir = Setting\get 'project.output_dir'
            config_file = Path\join output_dir, config_file
            Validation\assert (File\exists config_file), "Failed to find fbuild config file."

        fn = (FastBuild!\list_targets config:config_file)\gmatch "([%w_%-:%. ]+)\n"
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

    @fbuild: (args = {}) =>
        if (type args.target) ~= 'table'
            args.target = { tostring(args.target) }

        config_file = Setting\get 'build.fbuild_config_file'
        unless File\exists config_file
            output_dir = Setting\get 'project.output_dir'
            config_file = Path\join output_dir, config_file
            Validation\assert (File\exists config_file), "Failed to find fbuild config file."

        FastBuild!\build
            config:config_file
            target:table.concat args.target, ' '
            clean:args.clean
            monitor:args.monitor
            distributed:args.dist
            summary:args.summary == 'always'
            nosummaryonerror:args.summary == 'success'
            verbose:args.verbose

{ :BuildCommand }
