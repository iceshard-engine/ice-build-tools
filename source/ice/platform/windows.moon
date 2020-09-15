class Windows
    @detect: =>
        -- Get Windows 10 SDK information
        get_win10_sdk = ->
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
        get_universal_crt = ->
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

        sdk_list = { }

        if win_sdk = get_win10_sdk!
            sdk_info = {
                name: 'SDK-Windows-10'
                struct_name: 'SDK_Windows_10'
                includedirs: {
                    "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\ucrt"
                    "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\um"
                    "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\shared"
                    "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\winrt"
                }
                libdirs: {
                    "#{win_sdk.directory}Lib\\#{win_sdk.version}.0\\ucrt\\x64"
                    "#{win_sdk.directory}Lib\\#{win_sdk.version}.0\\um\\x64"
                }
                libs: { }
            }
            table.insert sdk_list, sdk_info

            sdk_info = {}
            sdk_info.name = 'SDK-DX12'
            sdk_info.struct_name = 'SDK_DX12'
            sdk_info.includedirs = {}
            sdk_info.libdirs = {}
            sdk_info.libs = {}
            table.insert sdk_list, sdk_info

        sdk_list

{ :Windows }
