import Command, group, argument, option, flag from require "ice.command"
import Setting from require "ice.settings"
import Json from require "ice.util.json"
import Git from require "ice.tools.git"
import Conan from require "ice.tools.conan"

import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"
import Path, File, Dir from require "ice.core.fs"
import TeamCity from require "ice.tools.teamcity"

class LicenseCommand extends Command
    @resolve_conan_modules!

    @settings {
        Setting 'license.spdx', required:true
        Setting 'license.authors', required:true

        -- 'Mode: Thirdparty settings'
        Setting 'license.thirdparty.details_file', default:'thirdparty/details.json'
        Setting 'license.thirdparty.generate_location', default:'thirdparty'

        -- 'Mode: Sources settings'
        Setting 'license.mode_sources.file_extensions', default:{
            ".bff": true, ".inl": true
            ".h": true, ".c": true
            ".hxx": true, ".cxx": true
            ".hpp": true, ".cpp": true
        }
        Setting 'license.mode_sources.spdx_headers.match_pattern.args', default:{
            'year_created', 'year_modified', 'authors', 'license'
        }
        Setting 'license.mode_sources.spdx_headers.match_pattern.lines', default:{
            '^[/!*]+ Copyright (%d+) %- (%d+), (.+)$'
            '^[/!*]+ SPDX%-License%-Identifier: (.+)$'
        }
        Setting 'license.mode_sources.spdx_headers.generate', default:{
            "/// Copyright %d - %d, %s"
            "/// SPDX-License-Identifier: %s"
        }
    }

    @arguments {
        group 'general', description:'General licensing options'
        argument 'mode',
            group: 'general'
            description: 'Selects the process that this command should run.\n- \'sources\' checks for SPDX headers.\n- \'3rdparty\' searches dependencies for license information.\n'
            name: 'mode'
            choices: { 'sources', '3rdparty' }
            default: 'sources'
        flag 'generate',
            group: 'general'
            description: 'Runs generation step for the selected mode.\n- \'sources\' generates SPDX file headers.\n- \'3rdparty\' generates readme and license files.'
            name: '-g --generate'

        group 'sources', description:'Source licensing options'
        option 'directory',
            description: "Instead of just checking current diff files, checks all files under the specified directory."
            group: 'sources'
            name: '-d --dir'
            default: 'source'
            count: '*'
            args: '?'
        option 'gitref',
            description: "Git reference to use when checking for changed files!"
            group: 'sources'
            name: '-r --git-ref'

        option 'set_created',
            description: "Updates all selected files to use the specified 'created year' value in the license header."
            group: 'sources'
            name: '-c --created-year'
        option 'set_modified',
            description: "Updates all selected files to use the specified 'modified year' value in the license header."
            group: 'sources'
            name: '-m --modified-year'
        flag 'ci_validation',
            description: "Reports missing and outdated license headers as inspection errors. Only works if IBT is running with a 'ci' service enabled. (ex. TeamCity)"
            group: 'sources'
            name: '--ci-validation'
    }

    prepare: (args, project) =>
        @current_dir = Dir\current!

        if args.generate
            @fail "Missing value for setting '#{@@settings.license.spdx.key}'" unless @settings.license.spdx
            @fail "Missing value for setting '#{@@settings.license.authors.key}'" unless @settings.license.authors

        if args.mode == '3rdparty'
            @details = File\load @settings.license.thirdparty.details_file, parser:Json\decode

        if args.mode == 'sources'
            @report_spdx_missing = TeamCity\inspection_type
                id:'MissingSPDXheader'
                name:'Missing SPDX License Header'
                category:'Licensing requirements'
                description:'Reports missing license information in text-based source files.'
                severity:'ERROR'
            @report_spdx_outdated = TeamCity\inspection_type
                id:'OutdatedSPDXheader'
                name:'Oudated SPDX License Header'
                category:'Licensing requirements'
                description:'Reports oudated license information in text-based source files.'
                severity:'WARNING'

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

        file = Path\normalize file
        contents = File\load file, limit: 500, mode:'rb'
        if not contents or contents == ""
            @log\debug "Skipping empty file #{file}"
            return

        results = { }
        header_size = 0
        for pat_line in *lic_patterns
            file_line, cr, nl = contents\match "([^\n\r]+)(\r?)(\n)"
            if nl ~= '\n'
                @log\debug "Skipping empty file #{file}"
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
            @log\debug "Skipping empty file #{file}"
            return

        if #results ~= #lic_pattern_args
            @log\warning "Missing copyright and/or SPDX header in file: #{file}"
            @report_spdx_missing :file

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
            message = "Modification year is outdated! (found: #{r.year_modified}, current: #{r.file_modified})"
            @log\info "#{message} in #{file}"
            @report_spdx_outdated :file, :message

        elseif header_size > 0 and (r.authors ~= lic_authors or r.license ~= lic_spdx)
            @log\verbose "Modification of authors or license values in #{file}", r.authors, r.license
            @log\debug "- [authors] old: '%s', new: '%s'", r.authors, lic_authors if r.authors ~= lic_authors
            @log\debug "- [license] old: '%s', new: '%s'", r.license, lic_spdx if r.license ~= lic_spdx

            -- Let's don't end up reversing years...
            r.file_modified = r.year_modified
        elseif header_size == 0
            r.year_created = r.file_created
        else
            requires_update = false

        -- Force years to specific values
        if args.created_year and args.created_year ~= "#{r.year_created}"
            @log\debug "Forcing 'creation year' to value '#{args.created_year}' from current value '#{r.year_created}' in #{file}"
            r.year_created = args.created_year
            requires_update = true

        if args.modified_year and args.modified_year ~= "#{r.year_modified}"
            @log\debug "Forcing 'modified year' to value '#{args.modified_year}' from current value '#{r.year_modified}' in #{file}"
            r.year_modified = args.modified_year
            requires_update = true

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

            @log\verbose "Generating copyright and SPDX header in file: #{file}"
            contents = File\load file, mode:'rb'
            contents = contents\sub header_size + 1
            contents = final_header .. contents

            if f = File\open file, mode:"wb"
                f\write contents
                f\close!
                return true
            else
                @log\warning "Failed to update file #{file}"
        elseif args.generate
            @log\debug "No updated required for file #{file}"
        return false

    search_dir: (args, project) =>
        sdpx_extensions = @settings.license.mode_sources.file_extensions
        -- source_path = Path\join project.workspace_dir, project.source_dir

        -- Find matching files
        files = { }
        if args.dir and not args.git_ref
            for dir in *args.dir
                dir = dir[1] or 'source'
                sub_files = Dir\find_files dir, recursive:true, filter: (filename) ->
                    sdpx_extensions[Path\extension filename]
                @log\debug "Gathered #{#sub_files} files from the '#{dir}' directory..."

                table.insert files, file for file in *sub_files
        else
            files = [filename for filename in *(Git!\diff_files ref:args.git_ref) when sdpx_extensions[Path\extension filename]]

        @log\verbose "Selected #{#files} files from #{#args.dir} directories" if #files > 0
        updated = 0
        for file in *files
            updated += 1 if @check_license_header file, args
        @log\info "Updated license headers in #{updated} files."


    execute_mode_sources: (args, project) =>
        @log\info "Checking source files for necessary license header changes..."
        @log\warning "Flag '--clean' has no effect in 'source' mode." if args.clean
        @log\warning "Argument '--gen-3rdparty' has no effect in 'source' mode." if args.gen_3rdparty

        @search_dir args, project
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

    gather_deps_from_conan: (path) =>
        conandeps_files = Dir\find_files path, recursive:true, filter: (filename) -> (filename\match "conandeps.bff") ~= nil

        conandeps_parse = (filepath) ->
            dependencies = { }
            for line in File\lines filepath
                if line\match '// "name":'
                    line = line\sub 4
                    line = line\gsub '\\', '/'
                    table.insert dependencies, Json\decode "{#{line}}"
            @log\warning "No dependencies found in '#{filepath}'" if #dependencies == 0
            return dependencies

        deps_final = { }
        deps_seen = { }
        for depsfile in *conandeps_files
            for dependency in *conandeps_parse depsfile
                unless deps_seen[dependency.name]
                    deps_seen[dependency.name] = true
                    dependency.conanfile = Path\rename depsfile, "conanfile.txt"
                    table.insert deps_final, dependency

        table.sort deps_final, (a, b) -> a.name < b.name
        return deps_final

    execute_mode_3rdparty: (args, project) =>
        return unless Validation\ensure (Dir\exists 'build/conan'), "Missing Conan dependency configuration!"

        dependencies = @gather_deps_from_conan 'build/conan'

        -- Check all dependencies for license files
        license_files = {}
        for dependency in *dependencies
            found_license_files = { }
            for subdir in *{ ".", "LICENSE", "COPYRIGHT", "LICENSES" }
                if not @search_for_license_files found_license_files, dependency.package_folder, subdir
                    @search_for_license_files found_license_files, dependency.package_folder, subdir\lower!

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
                    "#{dependency.package_folder}/../../export/conanfile.py",
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
                        -- Parse graph info and get the first entry
                        conaninfo_json = Conan!\graph_info package:"#{dep.name}/*", format:'json', conanfile:dep.conanfile
                        conaninfo = Json\decode conaninfo_json

                        Validation\assert conaninfo.nodes or (conaninfo.graph and conaninfo.graph.nodes), "Conan 'graph info --format json' result changed and is no longer supported!"
                        conaninfo_nodes = conaninfo.nodes or conaninfo.graph.nodes
                        -- Gather all nodes and pick the first one
                        conaninfo_node = [node for _, node in pairs conaninfo_nodes]
                        conaninfo = Validation\ensure conaninfo_node[1], "Package '#{dep.name}' info  not found!"
                        conaninfo.version = conaninfo.label\match "[^/]+/([^@]+)"

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
