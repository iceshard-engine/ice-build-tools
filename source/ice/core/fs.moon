lfs = require "lfs"

import Log from require "ice.core.logger"

select = (v, true_val, false_val) -> v and true_val or false_val
allowed_separators = os.osselect win:"\\/", unix:"/"

class Path
    @separator = string.sub package.config, 1, 1

    @info = (path, mode) => lfs.attributes path, mode
    @exists = (path) => (Path\info path, 'mode') != nil

    -- Does not return name of directory if final slash is there, maybe we want this?
    -- @name = (path, args = { noextension:false }) => path and path\match select args.noextension, "([^#{allowed_separators}%.]+)%.?[%w]*$", "([^#{allowed_separators}]+)$"
    @name = (path, args = { noextension:false }) => path and path\match select args.noextension, "([^#{allowed_separators}%.]+)%.?[%w]*[#{allowed_separators}]*$", "([^#{allowed_separators}]+)[#{allowed_separators}]*$"
    @extension = (path, args = { }) => path and path\match (select args.long, "(%.[%.%w]+)$", "(%.[%w]+)$")
    @parent = (path) => path and path\match "^(.+)[#{allowed_separators}]+[^#{allowed_separator}]+"

    @is_absolute = (path) => path and (path\match os.osselect win:"^[a-zA-Z]+:\\", unix:'^/') ~= nil
    @is_relative = (path) => not @is_absolute path

    @normalize = (path, args = { }) =>
        return unless path
        separator = args.separator or @separator

        -- Make sure separators are identical
        path = path\gsub "[#{allowed_separators}]", separator

        -- Remove backtracking paths
        path, i = path\gsub "([^%.#{separator}]+)#{separator}+%.%.#{separator}?", (v) -> ""
        while i > 0
            path, i = path\gsub "([^%.#{separator}]+)#{separator}+%.%.#{separator}?", (v) -> ""

        -- Remove 'current' paths
        path = path\gsub "%.#{separator}", ""

        -- Remove duplicates
        (path\gsub "#{separator}+", separator)

    @join = (left, right, ...) =>
        local internal_join
        trim_separators = (v) -> (v\match "^[#{allowed_separators}]*(.+)"), v\match "[#{allowed_separators}]+$"
        internal_join = (l, r, ...) ->
            return l unless r

            trimed, sep = trim_separators l
            return internal_join l, ... if r == "./" or r == ".\\" or r == ""
            return internal_join "#{trimed}/#{trim_separators r}", ... unless sep
            return internal_join "#{trimed}#{trim_separators r}", ...

        Path\normalize internal_join left, right, ...

class Dir
    @current = => lfs.currentdir!
    @exists = (path) => (Path\info path, 'mode') == 'directory'
    @is_empty = (path) => (Dir\list path)! == nil

    @create = (path, args = { }) =>
        return true if Dir\exists path

        result = true
        if args.skip_parents
            result = lfs.mkdir path
        else
            partial = ''
            for name in path\gmatch '[^/\\]+'
                partial ..= "#{name}/"
                unless os.isdir partial
                    result and= (lfs.mkdir partial) ~= nil
        result

    @delete = (path, args = { with_files:true }) =>
        return true unless Dir\exists path

        result = true
        if args.with_files
            for name, mode in Dir\list path
                entry_path = "#{path}/#{name}"

                -- Delete file nodes
                result and= File\delete entry_path if mode == 'file'
                result and= Dir\delete entry_path, with_files:true if mode == 'directory'

        -- Delete this path
        lfs.rmdir path if result

        return (Dir\exists path) == false

    @copy = (path) => false -- Log\error "'Dir\\copy' is not yet implemented."
    @move = (path) => false -- Log\error "'Dir\\move' is not yet implemented."
    @enter = (path, fn) =>

        result = false
        if fn == nil
            result = lfs.chdir path

        elseif Validation\ensure (type fn) == 'function', "Expected callback on second argument, got '#{fn}' (#{type fn}) instead!"
            -- Save the current directory
            current_dir = lfs.currentdir!
            if result = lfs.chdir path

                -- Call the function method
                fn lfs.currentdir!

                -- Get out of the directory
                lfs.chdir current_dir
        result

    @list = (path, args = { keep_meta_paths:false, recursive:false }) =>
        unless (Dir\exists path) then ->

        -- Paths we want to skip
        skip_paths = { }
        skip_paths = { ['.']:true, ['..']:true } unless args.keep_meta_paths
        skip_paths[path] = true for path in *(args.skip_paths or { })

        if args.recursive
            it = Dir\list path, keep_meta_paths:false, recursive:false, metadata:'mode'
            next_dirs = { }
            return ->
                child_path, path_type = it!

                -- Files only implementation
                -- while path_type != 'file'
                --     if (not child_path) and #next_dirs > 0
                --         path = next_dirs[1]
                --         it = Dir\list path, keep_meta_paths:false, metadata:'mode'
                --         table.remove next_dirs, 1
                --         child_path, path_type = it!

                --     elseif path_type == 'directory'
                --         table.insert next_dirs, "#{path}/#{child_path}"
                --         child_path, path_type = it!

                --     elseif path_type == nil
                --         break

                --     elseif path_type != 'file'
                --         Log\warning "Unexpected filesystem object '#{path}' of type '#{path_type}'"
                                -- while path_type != 'file'

                while path_type != 'file'
                    if (not child_path) and #next_dirs > 0
                        path = next_dirs[1]
                        it = Dir\list path, keep_meta_paths:false, recursive:false, metadata:'mode'
                        table.remove next_dirs, 1
                        return path, 'directory'

                    if path_type == 'directory'
                        table.insert next_dirs, 1, "#{path}/#{child_path}"
                        child_path, path_type = it!

                    elseif path_type and path_type != 'file'
                        continue
                        -- Log\warning "Unexpected filesystem object '#{path}' of type '#{path_type}'"

                    else break

                return "#{path}/#{child_path}", path_type if child_path

        else
            iter, dir_obj = lfs.dir path
            return ->
                if result = iter dir_obj
                    while skip_paths[result]
                        result = iter dir_obj
                    return result, Path\info (Path\join path, result), (args.metadata or 'mode')

    @find_files = (path, args = { recursive:false }) =>
        return { } unless Dir\exists path

        result = { }
        for child_path, child_type in Dir\list path, recursive:args.recursive
            if child_type == 'file'
                table.insert result, child_path if not args.filter or args.filter child_path, path
        result

class File
    @exists = (path) => (Path\info path, 'mode') == 'file'
    @create = (path) =>
    @delete = (path) => (path and os.remove path) or false

    @copy = (old_path, new_path, args = { }) =>
        if File\exists new_path
            return false unless args.force
            File\delete new_path

        if out_file = File\open new_path, mode:'wb+'
            if in_file = File\open old_path, mode:'rb'
                out_file\write in_file\read '*a'
                in_file\close!
            out_file\close!

        return File\exists new_path

    @move = (old_path, new_path, args = { }) =>
        if File\exists new_path
            return false unless args.force
            File\delete new_path

        if out_file = File\open new_path, mode:'wb+'
            if in_file = File\open old_path, mode:'rb'
                out_file\write in_file\read '*a'
                in_file\close!

                -- Delete the old path
                File\delete old_path
            out_file\close!

        return (File\exists old_path) == false

    @open = (path, args = { }) => io.open path, args.mode
    @lines = (path) => io.lines path
    @contents = (path, args = { limit:0, mode:'r' }) =>
        result = ""
        if f = File\open path, args.mode or 'r'
            if args.limit and args.limit > 0
                result = f\read args.limit
            else
                result = f\read '*a'
            f\close!

        -- Run the contents through a parser return the result
        return args.parser result if result and result ~= "" and args.parser
        result -- else return the raw contents

{ :Path, :Dir, :File }
