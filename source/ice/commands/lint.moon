import Command, argument, option, flag, group from require "ice.command"
import Setting from require "ice.settings"
import FastBuild from require "ice.tools.fastbuild"
import Conan from require "ice.tools.conan"
import BuildCommand from require "ice.commands.build"

import Validation from require "ice.core.validation"
import Log from require "ice.core.logger"
import Dir, Path, File from require "ice.core.fs"
import Json from require "ice.util.json"

class LintCommand extends Command
    @resolve_conan_modules!

    @settings {
        Setting 'linter.qodana.default_target', default:'all'
        Setting 'linter.qodana.output_filename', default:'compile_commands_qodana.json'
    }

    @arguments {
        group 'general', description: "General options"
        argument 'linter',
            description: 'Linter tool for which configuration should be generated.'
            group: 'general'
            name: 'linter'
            choices: { 'qodana' }
            default: 'qodana'
        option 'output-path',
            description: 'Output path for files generated to support the given linter.'
            group: 'general'
            name: '-o --output'
            default: '.'

        group 'qodana', description: "Configuring Qodana linter"
        argument 'target',
            description: "One or more targets for which to prepare 'compile_commands.json' file."
            group: 'qodana'
            name: 'target'
            args: '*'
            default: (Setting\ref 'linter.qodana.default_target') or (Setting\ref 'build.default_target')
        option 'workspace-path',
            description: 'The replacement path for the workspace location. (qodana-docker)'
            group: 'qodana'
            name: '--workspace-path'
            default: '/data/project'
        option 'conan-path',
            description: 'The replacement path for the global Conan2 location. (qodana-docker)'
            group: 'qodana'
            name: '--conan-path'
            default: '/data/.conan2'
    }

    prepare: (args, project) =>
        @compdb_file = "compile_commands.json"
        @compdb_output_file = Path\join args.output, (Setting\get 'linter.qodana.output_filename')

        Dir\enter project.output_dir

    execute: (args, project) =>
        BuildCommand\fbuild target:(args.target or 'all-x64-Debug'), clean:true, compdb:true

        -- Qodana specific steps
        if args.linter == 'qodana'
            @fail "Missing file '#{@compdb_file}'!" unless File\exists @compdb_file

            compdb = File\load @compdb_file --, parser:Json\decode
            -- @fail "Failed to parse '#{@compdb_file}'!" unless (type compdb) == 'table'

            -- Move over all entries and replace the current paths with qodana-docker expected paths
            replacements = {
                [project.workspace_dir]: args.workspace_path
                [Conan\location!]: args.conan_path
            }

            -- We assume qodana is run on linux, but just in case we cleanup the paths
            compdb = compdb\gsub "\\\\", "/"

            for old_path, new_path in pairs replacements
                -- ... same here, path cleanup
                old_path = old_path\gsub "[/\\]", "/"

                -- Update the paths in the whole file
                @log\info "Replacing old path '#{old_path}' with '#{new_path}'..."
                compdb = compdb\gsub old_path, new_path

            -- Store the file
            File\save @compdb_output_file, compdb

{ :LintCommand }
