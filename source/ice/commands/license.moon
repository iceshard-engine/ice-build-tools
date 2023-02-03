import Command, Setting, argument, option, flag from require "ice.command"
import Json from require "ice.util.json"

import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"
import Path, File, Dir from require "ice.core.fs"

class LicenseCommand extends Command
    @settings {
        Setting 'license.spdx', required:true
        Setting 'license.authors', required:true

        -- 'Mode: Thirdparty settings'
        Setting 'license.thirdparty.details_file', required:true, default:'thirdparty/details.json'
        Setting 'license.thirdparty.generate_location', required:true, default:'thirdparty'

        -- 'Mode: Sources settings'
        Setting 'license.mode_sources.file_extensions', required:true, default:{
            ".bff": true, ".inl": true
            ".h": true, ".c": true
            ".hxx": true, ".cxx": true
            ".hpp": true, ".cpp": true
        }
        Setting 'license.mode_sources.spdx_headers.match_pattern.args', required:true, default:{
            'year_created', 'year_modified', 'authors', 'license'
        }
        Setting 'license.mode_sources.spdx_headers.match_pattern.lines', required:true, default:{
            '^[/!*]+ Copyright (%d+) %- (%d+), (.+)$'
            '^[/!*]+ SPDX%-License%-Identifier: (.+)$'
        }
        Setting 'license.mode_sources.spdx_headers.generate', required:true, default:{
            "/// Copyright %d - %d, %s"
            "/// SPDX-License-Identifier: %s"
        }
    }

    @arguments {
        argument 'mode',
            description: 'Selects the process that this command should run.\n- \'sources\' checks for SPDX headers.\n- \'3rdparty\' searches dependencies for license information.\n'
            name: 'mode'
            choices: { 'sources', '3rdparty' }
            default: 'sources'
        flag 'generate',
            description: 'Runs generation step for the selected mode.\n- \'sources\' generates SPDX file headers.\n- \'3rdparty\' generates readme and license files.'
            name: '-g --generate'
        flag 'verbose',
            description: 'Increases verbosity of the output. Can be used up to two times.'
            name: '-v --verbose'
            count: '0-2'
    }

    prepare: (args, project) =>
        @current_dir = Dir\current!

        if args.generate
            @fail "Missing value for setting '#{@@settings.license.spdx.key}'" unless @settings.license.spdx
            @fail "Missing value for setting '#{@@settings.license.authors.key}'" unless @settings.license.authors

        if args.mode == '3rdparty'
            @details = File\contents @settings.license.thirdparty.details_file, parser:Json\decode

    execute: (args, project) =>
        return @execute_mode_sources args, project if args.mode == 'sources'
        return @execute_mode_3rdparty args, project if args.mode == '3rdparty'

    --[[ source code licensing tools ]]

    check_license_header: (file, args) =>
        lic_spdx = @settings.license.spdx
        lic_authors = @settings.license.authors
        lic_patterns = @settings.license.mode_sources.spdx_headers.match_pattern.lines
        lic_pattern_args = @settings.license.mode_sources.spdx_headers.match_pattern.args
        lic_generate = @settings.license.mode_sources.spdx_headers.generate

        newline = "\n"
        line_count = 0

        contents = File\contents file, limit: 500, mode:'rb'
        @log\warning "Failed to read file: '#{file}'" if not contents or contents == ""

        results = { }
        header_size = 0
        for pat_line in *lic_patterns
            file_line, cr, nl = contents\match "([^\n\r]+)(\r?)(\n)"
            if nl ~= '\n'
                @log\verbose "Skipping empty file #{file}" if args.verbose == 2
                return
            elseif cr == '\r'
                newline = "\r\n"

            line_count += 1
            line_size = #file_line + 1 + (cr == '\r' and 1 or 0)

            line_results = { file_line\match pat_line }
            break if #line_results == 0

            header_size += line_size
            contents = contents\sub line_size + 1

            -- Append results
            table.foreach line_results, (_, v) -> table.insert results, v

        -- Send missing message (always shown)
        if line_count == 0
            @log\verbose "Skipping empty file #{file}" if args.verbose == 2
            return

        if #results ~= #lic_pattern_args
            @log\warning "Missing copyright and/or SPDX header in file: #{file}"
            header_size = 0
            contents = nil

        -- Name the results
        r = { year_created:0, year_modified:0 }
        for idx, val in pairs results
            arg_name = lic_pattern_args[idx]

            if arg_name == 'year_created' or arg_name == 'year_modified'
                val = tonumber val

            r[arg_name] = val

        file_info = Path\info file
        r.file_modified = os.date("*t", file_info.modification).year
        -- This is just an approximate
        r.file_created = os.date("*t", file_info.change).year

        requires_update = true
        if r.year_modified < r.file_modified and r.year_modified > 0
            @log\verbose "Modification year (found: %d, current: %d) is outdated in #{file}", r.year_modified, r.file_modified if args.verbose
        elseif header_size > 0 and (r.authors ~= lic_authors or r.license ~= lic_spdx)
            @log\info "Modification of authors or license values in #{file}", r.authors, r.license
            @log\verbose "- [authors] old: '%s', new: '%s'", r.authors, lic_authors if r.authors ~= lic_authors and args.verbose == 2
            @log\verbose "- [license] old: '%s', new: '%s'", r.license, lic_spdx if r.license ~= lic_spdx and args.verbose == 2

            -- Let's don't end up reversing years...
            r.file_modified = r.year_modified
        elseif header_size == 0
            r.year_created = r.file_created
        else
            requires_update = false

        -- Apply changes
        if args.generate and requires_update
            final_header = ""
            for line in *lic_generate
                final_header ..= line .. newline

            final_header ..= newline if header_size == 0

            -- Apply formatting
            r.authors = lic_authors if r.authors ~= lic_authors
            r.license = lic_spdx if r.license ~= lic_spdx
            final_header = string.format final_header, (r.year_created or r.file_created), (r.file_modified or r.year_modified), r.authors, r.license

            @log\info "Generating copyright and SPDX header in file: #{file}"
            contents = File\contents file, mode:'rb' unless contents
            contents = final_header .. contents

            if f = File\open file, mode:"wb"
                f\write contents
                f\close!
            else
                @log\warning "Failed to update file #{file}"
        elseif args.generate
            @log\verbose "No updated required for file #{file}"


    search_dir: (dir, args) =>
        sdpx_extensions = @settings.license.mode_sources.file_extensions

        -- Find matching files
        files = Dir\find_files dir, recursive:true, filter: (filename) ->
            sdpx_extensions[Path\extension filename]

        for file in *files
            @check_license_header file, args


    execute_mode_sources: (args, project) =>
        @log\warning "Flag '--clean' has no effect in 'source' mode." if args.clean
        @log\warning "Argument '--gen-3rdparty' has no effect in 'source' mode." if args.gen_3rdparty

        @search_dir "#{os.cwd!}/#{project.source_dir}", args
        @log\info "Checks finished." if args.check
        return true

    --[[ 3rd party licensing tools ]]

    search_for_license_files: (out_license_files, rootpath, dir) =>
        known_license_files = {
            'license': true
            'license.md': true
            'license.txt': true
            'license.rst': true
            'copyright': true
            'copyright.txt': true
        }

        found_license = false
        if Dir\exists (Path\join rootpath, dir)
            for candidate_file, mode in *Dir\find_files (Path\join rootpath, dir)
                if dir == "."
                    if known_license_files[candidate_file\lower!] ~= nil
                        table.insert out_license_files, Path\join rootpath, candidate_file
                        found_license = true
                else
                    table.insert out_license_files, Path\join rootpath, dir, candidate_file
                    found_license = true
        found_license


    extract_recipe_info: (conanfile) =>
        allowed_fields = {
            'url': true
            'homepage': true
            'license': true
            'description': true
        }

        result = { }
        if file = File\open conanfile, mode:'rb'
            contents = file\read "*a"
            for field, value in contents\gmatch "(%w*) = \"([^\\\"]*)\""
                result[field] = value if allowed_fields[field]
            file\close!
        result

    execute_mode_3rdparty: (args, project) =>
        license_files = {}

        if buildinfo = File\contents 'build/conan_debug/conanbuildinfo.json', parser:Json\decode
            for dependency in *buildinfo.dependencies
                found_license_files = { }
                for subdir in *{ ".", "LICENSE", "COPYRIGHT", "LICENSES" }
                    if not @search_for_license_files found_license_files, dependency.rootpath, subdir
                        @search_for_license_files found_license_files, dependency.rootpath, subdir\lower!

                -- Gather license files
                if #found_license_files > 0
                    selected_license = nil

                    if #found_license_files > 1

                        if @details[dependency.name] and @details[dependency.name].license_file
                            for license_file in *found_license_files
                                if license_file\lower!\match @details[dependency.name].license_file\lower!
                                    selected_license = license_file

                        if selected_license == nil
                            @log\warning "Packge '#{dependency.name}' contains more than one license file."
                            @log\warning "> Please select the desired license file in 'thirdparty/details.json'."
                            for license_file in *found_license_files
                                @log\warning "- #{license_file}"
                            continue

                    table.insert license_files, {
                        dependency,
                        "#{dependency.rootpath}/../../export/conanfile.py",
                        selected_license or found_license_files[1]
                    }

                else
                    @log\warning "Packge '#{dependency.name}' is missing license file..."

        if license_files and #license_files > 0

            if args.generate
                gen_dir = "#{@current_dir}/#{@settings.license.thirdparty.generate_location}"
                Dir\create gen_dir

                if licenses = File\open "#{gen_dir}/LICENSES.txt", mode:"wb+"
                    for { dep, _, license_file } in *license_files
                        licenses\write "\n-------------------- START '#{dep.name\lower!}' --------------------\n"
                        if license_file_handle = File\open license_file, mode:"rb+"
                            for line in license_file_handle\lines!
                                licenses\write "    #{line}\n"
                            license_file_handle\close!
                        licenses\write "-------------------- END '#{dep.name\lower!}' --------------------\n\n"
                    licenses\close!

                if readme = File\open "#{gen_dir}/README.md", mode:"wb+"

                    readme\write "# Third Party Libraries\n\n"
                    readme\write "A file generated from all in-used conan dependencies.\n"
                    readme\write "Listed alphabetically with general information about each third party dependency.\n"
                    readme\write "For exact copies of eache license please follow the upstream link to look into [LICENSES.txt](LICENSES.txt).\n"

                    for { dep, conanfile, license_file } in *license_files
                        conaninfo = @extract_recipe_info conanfile
                        readme\write "\n## #{dep.name}\n"

                        license_info = conaninfo.license or 'not found'
                        upsteam_info = conaninfo.url or conaninfo.homepage
                        description_info = conaninfo.description or dep.description
                        if @details[dep.name]
                            description_info = @details[dep.name].description or description_info
                            license_info = @details[dep.name].license or license_info
                            upsteam_info = @details[dep.name].upstream or upsteam_info

                        readme\write "#{description_info}\n"
                        readme\write "- **upstream:** #{upsteam_info}\n" if upsteam_info
                        readme\write "- **version:** #{conaninfo.version or dep.version}\n"
                        readme\write "- **license:** #{license_info}\n"

                    readme\close!

        @log\info "Checks finished." if args.check
        true


{ :LicenseCommand, :argument, :option, :flag }
