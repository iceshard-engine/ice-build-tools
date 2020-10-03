import VSWhere from require "ice.tools.vswhere"

toolchain_definitions = {
    --[[ Toolchain: Clang 10 - x64 - ]]
    clang_x64_1000: {
        name: 'clang-x64-1000'
        struct_name: 'Toolchain_Clang_x64_1000'
        compiler_name: 'compiler-clang-x64-1000'

        generate_structure: (gen, toolchain_bin_dir, toolchain_dir, clang_version) ->
            struct_name = 'Toolchain_Clang_x64_1000'
            compiler_name = 'compiler-clang-x64-1000'

            gen\structure struct_name, (gen) ->
                gen\variables { { 'ToolchainPath', toolchain_bin_dir } }

                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: "$ToolchainPath$\\clang.exe"
                    extra_files: { }

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'clang' }
                    { 'ToolchainArchitecture', 'x64' }
                    { 'ToolchainToolset', '1000' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', "$ToolchainPath$\\llvm-ar.exe" }
                    { 'ToolchainLinker', "$ToolchainPath$\\clang.exe" }
                    { 'ToolchainIncludeDirs', { } }
                    { 'ToolchainLibDirs', { } }
                    { 'ToolchainLibs', { } }
                }
    }
}

detect_compilers = (version, requirements) ->
    unless (type requirements) == "table" and #requirements > 0
        requirements = {
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

            -- Try to enter this directory,
            os.chdir "#{path}/VC/Tools/Llvm/x64", (current_dir) ->
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
                    toolchain_path = "#{current_dir}\\bin"

                    table.insert toolchain_list, {
                        name: toolchain_definition.name
                        struct_name: toolchain_definition.struct_name
                        compiler_name: toolchain_definition.compiler_name
                        generate: (gen) -> toolchain_definition.generate_structure gen, toolchain_path, current_dir, clang_version
                        path:toolchain_path
                    }

        toolchain_list

{ :VsClang }
