import Command, argument, option, flag from require "ice.command"
import Json from require "ice.util.json"

class LicenseCommand extends Command
    @settings = {
        license: nil
        authors: nil

        info_3rdparty:
            details_file: 'thirdparty/details.json'
            generate_location: 'thirdparty'

        source_headers:
            pattern_find:
                args: { 'year_created', 'year_modified', 'authors', 'license' }
                lines: {
                    '[/!*]+ Copyright (%d+) %- (%d+), ([%s%S]+)'
                    '[/!*]+ SPDX%-License%-Identifier: (%w+)'
                }
            generate_lines: {
                "/// Copyright %d - %d, %s"
                "/// SPDX-License-Identifier: %s"
            }
    }

    @arguments {
        argument 'mode',
            name: 'mode'
            choices: { 'sources', '3rdparty' }
            default: 'sources'
        flag 'generate',
            name: '-g --generate'
            description: 'Generates 3rd-party readme and license files or file headers.'
        flag 'verbose',
            name: '-v --verbose'
            description: 'Increases verbosity of the output. Can be used up to two times.'
            count: '0-2'
    }

    prepare: (args, project) =>
        @current_dir = os.cwd!

        if args.mode == '3rdparty'
            @details = {}
            if file = io.open @@settings.info_3rdparty.details_file
                @details = Json\decode file\read '*a'
                file\close!

    execute: (args, project) =>
        return @execute_mode_sources args, project if args.mode == 'sources'
        return @execute_mode_3rdparty args, project if args.mode == '3rdparty'

    --[[ source code licensing tools ]]

    check_license_header: (file, args) =>
        newline = os.iswindows and "\r\n" or "\n"
        line_count = 0
        if f = io.open file
            lines_it = f\lines!

            results = { }
            header_size = 0
            for pat_line in *@@settings.source_headers.pattern_find.lines
                file_line = lines_it!
                break unless file_line

                line_count += 1
                header_size += #file_line + #newline

                line_results = { file_line\match pat_line }
                if #line_results == 0
                    f\close!
                    break

                -- Append results
                table.foreach line_results, (_, v) -> table.insert results, v

            -- Send missing message (always shown)
            if line_count == 0
                print "Skipping empty file #{file}" if args.verbose == 2
                return

            if #results ~= #@@settings.source_headers.pattern_find.args
                print "Missing copyright and/or SPDX header in file: #{file}"
                header_size = 0

            -- Name the results
            r = { year_created:0, year_modified:0 }
            for idx, val in pairs results
                arg_name = @@settings.source_headers.pattern_find.args[idx]

                if arg_name == 'year_created' or arg_name == 'year_modified'
                    val = val and tonumber val

                r[arg_name] = val

            file_info = lfs.attributes file
            r.file_modified = os.date("*t", file_info.modification).year
            -- This is just an approximate
            r.file_created = os.date("*t", file_info.change).year

            requires_update = true
            if r.year_modified < r.file_modified and r.year_modified > 0
                print (string.format "Modification year (found: %d, current: %d) is outdated in #{file}", r.year_modified, r.file_modified) if args.verbose
            elseif header_size > 0 and (r.authors ~= @@settings.authors or r.license ~= @@settings.license)
                print (string.format "Modification of authors or license values in #{file}", r.authors, r.license)
                print (string.format "- [authors] old: '%s', new: '%s'", r.authors, @@settings.authors) if r.authors ~= @@settings.authors and args.verbose == 2
                print (string.format "- [license] old: '%s', new: '%s'", r.license, @@settings.license) if r.license ~= @@settings.license and args.verbose == 2

                -- Let's don't end up reversing years...
                r.file_modified = r.year_modified
            elseif header_size == 0
                r.year_created = r.file_created
            else
                requires_update = false

            -- Apply changes
            if args.generate and requires_update
                final_header = ""
                for line in *@@settings.source_headers.generate_lines
                    final_header ..= line .. newline

                final_header ..= newline if header_size == 0

                -- Apply formatting
                r.authors = @@settings.authors if r.authors ~= @@settings.authors
                r.license = @@settings.license if r.license ~= @@settings.license
                final_header = string.format final_header, (r.year_created or r.file_created), (r.file_modified or r.year_modified), r.authors, r.license

                print "Generating copyright and SPDX header in file: #{file}"
                if f = io.open file, "rb"
                    contents = f\read "*a"
                    contents = final_header .. (contents\sub header_size + (#newline - 1))
                    f\close!

                    if f = io.open file, "wb"
                        f\write contents
                        f\close!
                    else
                        print "Failed to update file #{file}"

        else
            print "Failed to open file #{file}"

    search_dir: (dir, args) =>
        sdpx_extensions = {
            ".hxx": true
            ".cxx": true
            ".bff": true
            ".inl": true
            -- We check additional source files only during 'check' runs
            ".h": not args.generate
            ".c": not args.generate
            ".hpp": not args.generate
            ".cpp": not args.generate
        }

        -- Find matching files
        files = os.find_files dir, recursive:true, filter: (file_name) ->
            file_ext = file_name\sub (file_name\find "%."), file_name_len
            sdpx_extensions[file_ext]

        for file in *files
            @check_license_header file, args


    execute_mode_sources: (args, project) =>
        print "Warning: Flag '--clean' has no effect in 'source' mode." if args.clean
        print "Warning: Argument '--gen-3rdparty' has no effect in 'source' mode." if args.gen_3rdparty

        @search_dir "#{os.cwd!}/#{project.source_dir}", args
        print "Checks finished." if args.check
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
        if os.isdir "#{rootpath}/#{dir}"
            for candidate_file, mode in os.listdir "#{rootpath}/#{dir}", 'mode'
                continue if mode ~= 'file'

                if dir == "."
                    if known_license_files[candidate_file\lower!] ~= nil
                        table.insert out_license_files, "#{rootpath}/#{candidate_file}"
                        found_license = true
                else
                    table.insert out_license_files, "#{rootpath}/#{dir}/#{candidate_file}"
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
        if file = io.open conanfile, "rb+"
            contents = file\read "*a"
            for field, value in contents\gmatch "(%w*) = \"([^\\\"]*)\""
                result[field] = value if allowed_fields[field]
            file\close!
        result

    execute_mode_3rdparty: (args, project) =>
        license_files = {}
        with file = io.open 'build/conan_debug/conanbuildinfo.json'

            if buildinfo = Json\decode file\read '*a'

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
                                print "Packge '#{dependency.name}' contains more than one license file."
                                print "> Please select the desired license file in 'thirdparty/details.json'."
                                for license_file in *found_license_files
                                    print "- #{license_file}"
                                continue

                        table.insert license_files, {
                            dependency,
                            "#{dependency.rootpath}/../../export/conanfile.py",
                            selected_license or found_license_files[1]
                        }

                    else
                        print "Packge '#{dependency.name}' is missing license file..."

            file\close!

        if license_files and #license_files > 0

            if args.generate
                gen_dir = "#{@current_dir}/#{@@settings.info_3rdparty.generate_location}"
                os.mkdir gen_dir unless os.isdir gen_dir

                if licenses = io.open "#{gen_dir}/LICENSES.txt", "wb+"
                    for { dep, _, license_file } in *license_files
                        licenses\write "\n-------------------- START '#{dep.name\lower!}' --------------------\n"
                        if license_file_handle = io.open license_file, "rb+"
                            for line in license_file_handle\lines!
                                licenses\write "    #{line}\n"
                            license_file_handle\close!
                        licenses\write "-------------------- END '#{dep.name\lower!}' --------------------\n\n"
                    licenses\close!

                if readme = io.open "#{gen_dir}/README.md", "wb+"

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

        print "Checks finished." if args.check
        true


{ :LicenseCommand, :argument, :option, :flag }
