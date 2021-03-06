lfs = require 'lfs'

-- Get the host system value on first run
extension_to_system = dll:'windows', dylib:'macos', so:'unix'

-- Get the binary module extension this lua build is using
module_extension = string.match package.cpath, '?%.(%w+)'

-- Save the host system value
detected_host_system = extension_to_system[module_extension] or 'unknown'

os.cwd = -> lfs.currentdir!

-- We use the lua build configuration to get the host system, this works in most cases but some issues may arise on MacOS.
os.host = -> detected_host_system

os.iswindows = detected_host_system == 'windows'
os.isunix = detected_host_system == 'unix'
os.ismacos = detected_host_system == 'macos'

-- Returns true if the path is a directory
os.isfile = (path) -> (lfs.attributes path, 'mode') == 'file'

-- Returns true if the path is a file
os.isdir = (path) -> (lfs.attributes path, 'mode') == 'directory'

-- Creates the directory at the given path
os.mkdir = (path) -> lfs.mkdir path

-- Creates all directories in the path
os.mkdirs = (path) ->
    return true if os.isdir path

    result = true
    partial = ''
    for name in path\gmatch '[^/\\]+'
        partial ..= "#{name}/"
        unless os.isdir partial
            result and= (os.mkdir partial) ~= nil
    result

os.listdir = (path, part) ->
    unless os.isdir path then ->

    iter, dir_obj = lfs.dir path
    return ->
        if result = iter dir_obj
            return result, lfs.attributes "#{path}/#{result}", part

os.rmdir = (path) ->
    return true unless os.isdir path
    lfs.rmdir path

os.rmdir_with_files = (path) ->
    return true unless os.isdir path

    for name, mode in os.listdir path, 'mode'
        -- Skip 'meta' names
        if name == '.' or name == '..'
            continue

        entry_path = "#{path}/#{name}"

        -- Delete file nodes
        os.remove entry_path if mode == 'file'
        os.rmdir_with_files entry_path if mode == 'directory'

    -- Delete this path
    lfs.rmdir path

os.chdir = (path, fn) ->
    result = false

    if fn == nil
        result = lfs.chdir path

    else
        -- Save the current directory
        current_dir = lfs.currentdir!
        if result = lfs.chdir path

            -- Call the function method
            assert (type fn) == "function", "Expected callback at #2 argument!"
            fn lfs.currentdir!

            -- Get out of the directory
            lfs.chdir current_dir

    result

-- Create an alias for the deprecated name
os.indir = os.chdir
