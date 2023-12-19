import Path, Dir, File from require "ice.core.fs"
import Exec, Where from require "ice.tools.exec"
import Git from require "ice.tools.git"

import Setting from require "ice.settings"
import Log from require "ice.core.logger"

class SDKManager extends Exec
    new: (path) => super path

    install: (opts = { }) =>
    uninstall: (opts = { }) =>
    list: (opts = { }) =>

class WebAsm
    @settings: {
        Setting "webasm.sdk_root"
    }

    @find_webasm_sdk: (location) =>
        required_file = os.osselect win:'emsdk_env.bat', unix:'emsdk_env.sh'
        is_empty = true
        if Dir\exists location
            for entry, mode in Dir\list location
                if (mode == 'file' and entry\match required_file)
                    return location, false
                is_empty = false

        return nil, is_empty

    @install_webasm_sdk: (location, opts = { }) =>
        is_emsdk, is_empty = @find_webasm_sdk location

        return true if is_emsdk and (not opts.force)
        if (is_empty == false) and (not opts.force)
            return false, "Directory is not empty, use 'force:true' to wipe it and install emsdk inside."

        -- Clear directory before continuing

        git = Git!
        git\clone location:location, url:'https://github.com/emscripten-core/emsdk.git' unless is_emsdk
        Dir\enter location, ->
            git\pull!

            emsdk = Exec os.osselect win:'emsdk.bat', unix:'emsdk.sh'
            emsdk\run "install #{opts.version or 'latest'}"
            emsdk\run "activate #{opts.version or 'latest'}"
            -- os.execute 'source ./emsdk_env.sh' if os.isunix

    @detect_webasm_sdk: =>
        possible_paths = {
            { source:'settings', location: Setting\get "webasm.sdk_root" }
            { source:'environment', location: os.env.EMSDK }
            { source:'local-setup', location: "build/webasm" }
        }

        sdk_root = nil
        for entry in *possible_paths
            entry.location = Path\normalize entry.location

            if entry.location == nil
                Log\verbose "Skipping search for WebAsm SDK from #{entry.source}"
            elseif (Dir\exists entry.location) == false
                Log\verbose "Skipping search for WebAsm SDK in invalid path #{entry.location}"
            else
                Log\verbose "Searching for WebAsm SDK in #{entry.source} path #{entry.location}..."
                Log\warning "Overriden WebAsm SDK location from #{sdk_root} to #{entry.location}" if sdk_root and sdk_root != entry.location
                sdk_root = entry.location
        Log\verbose "Selected WebAsm SDK at location #{sdk_root}"

        return nil unless sdk_root
        emsdk_location = @find_webasm_sdk sdk_root
        return nil unless emsdk_location
        return { location: Path\join Dir\current!, emsdk_location }


{ :WebAsm }
