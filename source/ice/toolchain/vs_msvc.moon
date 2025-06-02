import VSWhere from require "ice.tools.vswhere"
import Locator from require "ice.locator"
import Dir, Path from require "ice.core.fs"

toolchain_definitions = {
    --[[ Toolchain: MSVC - v142 ]]
    msvc_x64_v142: {
        name: 'msvc-x64-v142'
        struct_name: 'Toolchain_MSVC_v142'
        compiler_name: 'compiler-msvc-v142'

        generate_structure: (gen, toolchain_bin_dir, toolchain_dir, tools_version) ->
            struct_name = 'Toolchain_MSVC_v142'
            compiler_name = 'compiler-msvc-v142'

            gen\structure struct_name, (gen) ->
                gen\variables { { 'ToolchainPath', toolchain_bin_dir } }

                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: "$ToolchainPath$\\cl.exe"
                    extra_files: {
                        "$ToolchainPath$\\c1.dll",
                        "$ToolchainPath$\\c1xx.dll",
                        "$ToolchainPath$\\c2.dll",
                        "$ToolchainPath$\\msobj140.dll",
                        "$ToolchainPath$\\mspdb140.dll",
                        "$ToolchainPath$\\mspdbcore.dll",
                        "$ToolchainPath$\\mspdbsrv.exe",
                        "$ToolchainPath$\\mspft140.dll",
                        "$ToolchainPath$\\msvcp140.dll",
                        "$ToolchainPath$\\atlprov.dll",
                        "$ToolchainPath$\\tbbmalloc.dll",
                        "$ToolchainPath$\\vcruntime140.dll",
                        "$ToolchainPath$\\1033\\mspft140ui.dll",
                        "$ToolchainPath$\\1033\\clui.dll",
                    }

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'msvc' }
                    { 'ToolchainSupportedArchitectures', { 'x64' } }
                    { 'ToolchainToolset', 'v142' }
                    { 'ToolchainFrontend', 'MSVC' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', "$ToolchainPath$\\lib.exe" }
                    { 'ToolchainLinker', "$ToolchainPath$\\link.exe" }
                    { 'ToolchainIncludeDirs', {
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\include",
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\atlmfc\\include",
                        "#{toolchain_dir}\\Auxiliary\\VS\\include",
                        "#{toolchain_dir}\\Auxiliary\\VS\\UnitTest\\include",
                    } }
                    { 'ToolchainLibDirs', {
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\lib\\x64",
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\atlmfc\\lib\\x64",
                        "#{toolchain_dir}\\Auxiliary\\VS\\lib\\x64",
                        "#{toolchain_dir}\\Auxiliary\\VS\\UnitTest\\lib",
                    } }
                    { 'ToolchainLibs', {
                        'kernel32',
                        'user32',
                        'gdi32',
                        'winspool',
                        'comdlg32',
                        'advapi32',
                        'shell32',
                        'ole32',
                        'oleaut32',
                        'uuid',
                        'odbc32',
                        'odbccp32',
                        'delayimp',
                    } }
                    { 'ConanCompilerVersion', '142' }
                }
    }
    --[[ Toolchain: MSVC - v143 ]]
    msvc_x64_v143: {
        name: 'msvc-x64-v143'
        struct_name: 'Toolchain_MSVC_v143'
        compiler_name: 'compiler-msvc-v143'

        generate_structure: (gen, toolchain_bin_dir, toolchain_dir, tools_version) ->
            struct_name = 'Toolchain_MSVC_v143'
            compiler_name = 'compiler-msvc-v143'

            gen\structure struct_name, (gen) ->
                gen\variables { { 'ToolchainPath', toolchain_bin_dir } }

                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: "$ToolchainPath$\\cl.exe"
                    extra_files: {
                        "$ToolchainPath$\\c1.dll",
                        "$ToolchainPath$\\c1xx.dll",
                        "$ToolchainPath$\\c2.dll",
                        "$ToolchainPath$\\msobj140.dll",
                        "$ToolchainPath$\\mspdb140.dll",
                        "$ToolchainPath$\\mspdbcore.dll",
                        "$ToolchainPath$\\mspdbsrv.exe",
                        "$ToolchainPath$\\mspft140.dll",
                        "$ToolchainPath$\\msvcp140.dll",
                        "$ToolchainPath$\\atlprov.dll",
                        "$ToolchainPath$\\tbbmalloc.dll",
                        "$ToolchainPath$\\vcruntime140.dll",
                        "$ToolchainPath$\\1033\\mspft140ui.dll",
                        "$ToolchainPath$\\1033\\clui.dll",
                    }

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'msvc' }
                    { 'ToolchainSupportedArchitectures', { 'x64' } }
                    { 'ToolchainToolset', 'v143' }
                    { 'ToolchainFrontend', 'MSVC' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', "$ToolchainPath$\\lib.exe" }
                    { 'ToolchainLinker', "$ToolchainPath$\\link.exe" }
                    { 'ToolchainIncludeDirs', {
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\include",
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\atlmfc\\include",
                        "#{toolchain_dir}\\Auxiliary\\VS\\include",
                        "#{toolchain_dir}\\Auxiliary\\VS\\UnitTest\\include",
                    } }
                    { 'ToolchainLibDirs', {
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\lib\\x64",
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\atlmfc\\lib\\x64",
                        "#{toolchain_dir}\\Auxiliary\\VS\\lib\\x64",
                        "#{toolchain_dir}\\Auxiliary\\VS\\UnitTest\\lib",
                    } }
                    { 'ToolchainLibs', {
                        'kernel32',
                        'user32',
                        'gdi32',
                        'winspool',
                        'comdlg32',
                        'advapi32',
                        'shell32',
                        'ole32',
                        'oleaut32',
                        'uuid',
                        'odbc32',
                        'odbccp32',
                        'delayimp',
                    } }
                    { 'ConanCompilerVersion', '143' }
                }
    }
}

default_toolchain_definition = (path, platform_toolset, override_libs) ->
    extra_files = Dir\find_files path, filter:(p) -> (Path\extension p) == '.dll'
    extra_files = [(Path\normalize name) for name in *extra_files]
    override_libs = nil unless (type override_libs) == 'table'

    return {
        name: "msvc-x64-#{platform_toolset}"
        struct_name: "Toolchain_MSVC_#{platform_toolset}"
        compiler_name: "compiler-msvc-#{platform_toolset}"

        generate_structure: (gen, toolchain_bin_dir, toolchain_dir, tools_version) ->
            struct_name = "Toolchain_MSVC_#{platform_toolset}"
            compiler_name = "compiler-msvc-#{platform_toolset}"

            cv_major, cv_minor = ((Exec\lines "#{toolchain_bin_dir}\\cl.exe")\gmatch "Compiler Version (%d%d).(%d)")!
            cv_full = "#{cv_major}#{cv_minor}"

            gen\structure struct_name, (gen) ->
                gen\variables { { 'ToolchainPath', toolchain_bin_dir } }

                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: "$ToolchainPath$\\cl.exe"
                    extra_files: ["$ToolchainPath$\\#{file}" for file in *extra_files]

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'msvc' }
                    { 'ToolchainSupportedArchitectures', { 'x64' } }
                    { 'ToolchainToolset', "#{platform_toolset}" }
                    { 'ToolchainFrontend', 'MSVC' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', "$ToolchainPath$\\lib.exe" }
                    { 'ToolchainLinker', "$ToolchainPath$\\link.exe" }
                    { 'ToolchainIncludeDirs', {
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\include",
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\atlmfc\\include",
                        "#{toolchain_dir}\\Auxiliary\\VS\\include",
                        "#{toolchain_dir}\\Auxiliary\\VS\\UnitTest\\include",
                    } }
                    { 'ToolchainLibDirs', {
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\lib\\x64",
                        "#{toolchain_dir}\\Tools\\MSVC\\#{tools_version}\\atlmfc\\lib\\x64",
                        "#{toolchain_dir}\\Auxiliary\\VS\\lib\\x64",
                        "#{toolchain_dir}\\Auxiliary\\VS\\UnitTest\\lib",
                    } }
                    { 'ToolchainLibs', override_libs or {
                        'kernel32',
                        'user32',
                        'gdi32',
                        'winspool',
                        'comdlg32',
                        'advapi32',
                        'shell32',
                        'ole32',
                        'oleaut32',
                        'uuid',
                        'odbc32',
                        'odbccp32',
                        'delayimp',
                    } }
                    { 'ConanCompilerVersion', cv_full }
                }
    }

detect_compilers = (version, requirements) ->
    unless (type requirements) == "table" and #requirements > 0
        requirements = {
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
        }

    vswhere = VSWhere!
    vswhere\find products:'*', all:true, format:'json', version:version, requires:requirements

class Toolchain_MSVC extends Locator
    new: => super Locator.Type.Toolchain, "MSVC Compiler Locator"

    locate: =>
        -- MSVC is a Windows-Only toolchain
        return unless os.iswindows

        @\add_result toolchain for toolchain in *@@detect!

    -- Allow to override the libraries generated into the MSVC toolchain
    @override_libraries = { }
    @set_libraries: (vs_channel, libraries) =>
        @override_libraries[vs_channel] = libraries if (type vs_channel) == 'string' and (type libraries) == 'table'

    -- Allow to override the name of the toolset given the specific VisualStudio channel (version)
    @override_toolset = {
        ['VisualStudio.15.Release']: 'v141' -- Not checked
        ['VisualStudio.16.Release']: 'v142' -- Not checked
        ['VisualStudio.17.Release']: 'v143'
        ['VisualStudio.18.Release']: 'v144' -- Just a prediction
    }
    @set_toolset: (vs_channel, toolset) =>
        @override_toolset[vs_channel] = toolset if (type vs_channel) == 'string' and (type toolset) == 'string'

    @detect: (version, requirements) =>
        toolchain_list = { }

        -- Append all MSVC compilers
        for compiler in *detect_compilers version, requirements
            path = compiler.installationPath
            channel_id = compiler.channelId\match "%w+%.%d+.%w+"

            -- Try to enter this directory,
            os.chdir "#{path}/VC", (current_dir) ->
                tools_version = nil
                redist_version = nil

                -- Read the Tools and Redist version files
                os.chdir "Auxiliary/Build", ->
                    get_version = (type) ->
                        read_version_file = (file) ->
                            result = nil
                            if f = io.open file, 'r'
                                result = f\read '*l'
                                f\close!
                            result

                        ver = read_version_file "Microsoft.VC#{type}Version.default.txt"
                        ver or read_version_file "Microsoft.VC#{type}Version.default.txt"

                    tools_version = get_version 'Tools'
                    redist_version = (get_version 'Redist') or tools_version

                tools_version_short = (tools_version\gsub '(%d+)%.(%d)%d*%.%d+', '%1%2') if tools_version
                toolchain_variable = "msvc_x64_v#{tools_version_short}"
                tools_arch_x64_exist = os.isdir "Tools/MSVC/#{tools_version}/bin/Hostx64/x64"

                toolchain_definition = toolchain_definitions[toolchain_variable] or default_toolchain_definition
                if tools_version and tools_arch_x64_exist and toolchain_definition
                    toolchain_path = "#{current_dir}\\Tools\\MSVC\\#{tools_version}\\bin\\Hostx64\\x64"
                    if (type toolchain_definition) == 'function'
                        toolchain_definition = toolchain_definition toolchain_path, @override_toolset[channel_id], @override_libraries[channel_id]

                    table.insert toolchain_list, {
                        name: toolchain_definition.name
                        struct_name: toolchain_definition.struct_name
                        compiler_name: toolchain_definition.compiler_name
                        generate: (gen) -> toolchain_definition.generate_structure gen, toolchain_path, current_dir, tools_version
                        path:toolchain_path
                    }

        toolchain_list

{ TC_MSVC:Toolchain_MSVC, :Toolchain_MSVC }
