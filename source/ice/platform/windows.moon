class Windows
    @detect_win10_sdk: ->
        -- Helper function to ask for registry keys
        get_registry_key = (root, key, value_type) ->
            result = nil
            if f = io.popen "reg query \"#{root}\\Microsoft\\Microsoft SDKs\\Windows\\v10.0\" /v #{key}"
                -- Check the lines
                for line in f\lines!
                    if result = line\match "#{key}[%s]+#{value_type}[%s]+(.+)"
                        break
                f\close!
            result

        -- Result table
        result = directory:nil, version:nil
        for root in *{ 'HKLM\\SOFTWARE\\Wow6432Node', 'HKCU\\SOFTWARE\\Wow6432Node', 'HKLM\\SOFTWARE', 'HKCU\\SOFTWARE' }
            result.directory = get_registry_key root, 'InstallationFolder', 'REG_SZ'
            result.version = get_registry_key root, 'ProductVersion', 'REG_SZ'
            if result.directory and result.version
                break

        result if result.directory and result.version

    -- Get the windows 10 universal CRT information
    @detect_universal_crt: ->
        -- Helper function to ask for registry keys
        get_registry_key = (root, key, value_type) ->
            result = nil
            if f = io.popen "reg query \"#{root}\\Microsoft\\Windows Kits\\Installed Roots\" /v #{key}"
                -- Check the lines
                for line in f\lines!
                    if result = line\match "#{key}[%s]+#{value_type}[%s]+(.+)"
                        break
                f\close!
            result

        -- Result table
        result = nil
        for root in *{ 'HKLM\\SOFTWARE\\Wow6432Node', 'HKCU\\SOFTWARE\\Wow6432Node', 'HKLM\\SOFTWARE', 'HKCU\\SOFTWARE' }
            if result = get_registry_key root, 'KitsRoot10', 'REG_SZ'
                break
        result

{ :Windows }
