import VSWhere from require "ice.tools.vswhere"

toolchain_definitions = {
    --[[ Toolchain: MSVC - x64 - v142 ]]
    msvc_x64_v142: {
        name: 'msvc-x64-v142'
        struct_name: 'Toolchain_MSVC_x64_v142'
        compiler_name: 'compiler-msvc-x64-v142'

        generate_structure: (gen, toolchain_bin_dir, toolchain_dir) ->
            struct_name = 'Toolchain_MSVC_x64_v142'
            compiler_name = 'compiler-msvc-x64-v142'

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
                    { 'ToolchainCompilerFamily', 'MSVC' }
                    { 'ToolchainArchitecture', 'x64' }
                    { 'ToolchainToolset', 'v142' }
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
                }
    }
}

detect_compilers = (version, requirements) ->
    unless (type requirements) == "table" and #requirements > 0
        requirements = {
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
        }

    vswhere = VSWhere!
    vswhere\find products:'*', all:true, format:'json', version:version, requires:requirements

class MSVC
    @detect: (version, requirements) =>
        toolchain_list = { }

        -- Append all MSVC compilers
        for compiler in *detect_compilers version, requires
            path = compiler.installationPath

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

                tools_version_short = ((tools_version\gsub '%.', '')\sub 0, 3) if tools_version
                toolchain_variable = "msvc_x64_v#{tools_version_short}"
                tools_arch_x64_exist = os.isdir "Tools/MSVC/#{tools_version}/bin/Hostx64/x64"

                if tools_version and tools_arch_x64_exist and toolchain_definitions[toolchain_variable]
                    toolchain_definition = toolchain_definitions[toolchain_variable]
                    toolchain_path = "#{current_dir}\\Tools\\MSVC\\#{tools_version}\\bin\\Hostx64\\x64"

                    table.insert toolchain_list, {
                        name: toolchain_definition.name
                        struct_name: toolchain_definition.struct_name
                        compiler_name: toolchain_definition.compiler_name
                        generate: (gen) -> toolchain_definition.generate_structure gen, toolchain_path, current_dir
                        path:toolchain_path
                    }

        toolchain_list

{ :MSVC }
