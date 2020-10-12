import VSWhere from require "ice.tools.vswhere"

toolchain_definitions = {
    --[[ Toolchain: Clang 10 - x64 - ]]
    clang_x64_1000: {
        name: 'clang-10.0.0'
        struct_name: 'Toolchain_Clang_x64_1000'
        compiler_name: 'compiler-clang-x64-1000'

        generate_structure: (gen, toolchain_bin_dir, toolchain_dir, clang_version, tools_version) ->
            struct_name = 'Toolchain_Clang_x64_1000'
            compiler_name = 'compiler-clang-x64-1000'

            gen\structure struct_name, (gen) ->
                gen\variables { { 'ToolchainPath', toolchain_bin_dir } }

                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: "$ToolchainPath$\\clang-cl.exe"
                    extra_files: { }
                    compiler_family: 'MSVC'

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'clang' }
                    { 'ToolchainArchitecture', 'x64' }
                    { 'ToolchainToolset', '1000' }
                    { 'ToolchainFrontend', 'clang_cl' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', "$ToolchainPath$\\llvm-lib.exe" }
                    { 'ToolchainLinker', "$ToolchainPath$\\lld-link.exe" }
                    { 'ToolchainIncludeDirs', {
                        -- "#{toolchain_dir}\\lib\\clang\\10.0.0\\include",
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
            'Microsoft.VisualStudio.Component.VC.Llvm.Clang'
        }

    vswhere = VSWhere!
    vswhere\find products:'*', all:true, format:'json', version:version, requires:requirements

class VsClang
    @detect: (version) =>
        toolchain_list = { }

        -- Append all MSVC compilers
        for compiler in *detect_compilers version, requires
            path = compiler.installationPath

            os.chdir "#{path}/VC/", (current_dir) ->

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

                if tools_version and redist_version
                    os.chdir "Tools/Llvm/x64", ->
                        clang_version = nil

                        -- Read the Tools and Redist version files
                        os.chdir "lib/clang", ->
                            get_version = ->
                                result = "9.0.0" if os.isdir "9.0.0"
                                result = "10.0.0" if os.isdir "10.0.0"
                                result
                            clang_version = get_version!


                        clang_version_short = (clang_version\gsub '%.', '') if clang_version
                        clang_variable = "clang_x64_#{clang_version_short}"

                        if clang_version and toolchain_definitions[clang_variable]
                            toolchain_definition = toolchain_definitions[clang_variable]
                            toolchain_path = "#{current_dir}\\Tools\\Llvm\\x64\\bin"

                            table.insert toolchain_list, {
                                name: toolchain_definition.name
                                struct_name: toolchain_definition.struct_name
                                compiler_name: toolchain_definition.compiler_name
                                generate: (gen) -> toolchain_definition.generate_structure gen, toolchain_path, current_dir, clang_version, tools_version
                                path:toolchain_path
                            }

        toolchain_list

{ :VsClang }
