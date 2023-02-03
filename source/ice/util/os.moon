lfs = require "lfs"

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

-- Returns the value from the map that is representing the current OS ibt is running on
os.osselect = (osmap) ->
    if os.iswindows
        return osmap.windows or osmap.win
    elseif os.ismacos
        return osmap.macos or osmap.mac or osmap.osx or osmap.unix
    elseif os.isunix
        return osmap.linux or osmap.unix

os.osname = os.osselect win:'windows', macos:'macos', linux:'linux'

-- Returns true if the path is a directory
os.isfile = (path) -> (lfs.attributes path, 'mode') == 'file'

-- Returns true if the path is a file
os.isdir = (path) -> (lfs.attributes path, 'mode') == 'directory'

-- Creates the directory at the given path
os.mkdir = (path) -> lfs.mkdir path

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
