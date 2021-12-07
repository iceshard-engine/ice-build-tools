import Locator from require 'ice.locator'
import Windows from require 'ice.platform.windows'

resource_compiler_toolchain_definition = (gen, arch, ver, win_sdk_path, win_sdk_ver) ->
    struct_name = 'Toolchain_ResCompiler_' .. arch .. '_' .. ver
    compiler_name = 'compiler-win-res-' .. arch .. '-' .. ver

    gen\structure struct_name, (gen) ->
        gen\line!
        gen\compiler
            name: compiler_name
            executable: "#{win_sdk_path}bin\\#{win_sdk_ver}.0\\#{arch}\\rc.exe"
            compiler_family: 'custom'
            extra_files: { }

        gen\line!
        gen\variables {
            { 'ToolchainCompilerFamily', 'custom' }
            { 'ToolchainArchitecture', arch }
            { 'ToolchainToolset', win_sdk_ver }
            { 'ToolchainFrontend', 'WinRC' }
            { 'ToolchainCompiler', compiler_name }
            { 'ToolchainLibrarian', '' }
            { 'ToolchainLinker', '' }
            { 'ToolchainIncludeDirs', { } }
            { 'ToolchainLibDirs', { } }
            { 'ToolchainLibs', { } }
        }


class SDK_Win32 extends Locator
    new: => super Locator.Type.PlatformSDK, "Win32 Platform Locator"
    locate: =>
        if os.iswindows
            if win_sdk = Windows\detect_win10_sdk!
                @\add_result {
                    tags: { 'windows', 'windows-10' }
                    name: 'SDK-Windows-10'
                    struct_name: 'SDK_Windows_10'
                    includedirs: {
                        "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\ucrt"
                        "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\um"
                        "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\shared"
                    }
                    libdirs: {
                        "#{win_sdk.directory}Lib\\#{win_sdk.version}.0\\ucrt\\x64"
                        "#{win_sdk.directory}Lib\\#{win_sdk.version}.0\\um\\x64"
                    }
                    libs: { }
                }

                -- @\add_result {
                --     name: 'rc-win10-x64'
                --     struct_name: 'Toolchain_ResCompiler_x64_10'
                --     compiler_name: 'compiler-win-res-x64-10'
                --     generate: (gen) -> resource_compiler_toolchain_definition gen, 'x64', '10', win_sdk.directory, win_sdk.version
                -- }, Locator.Type.Toolchain

{ :SDK_Win32 }
