import Where, Exec from require "ice.tools.exec"

toolchain_definitions = {
    '9': {
        name: 'clang-9.0.0'
        struct_name: 'Toolchain_Clang_x64_900'
        compiler_name: 'compiler-clang-x64-900'

        generate_structure: (gen, clang_path, ar_path) ->
            struct_name = 'Toolchain_Clang_x64_900'
            compiler_name = 'compiler-clang-x64-900'

            gen\structure struct_name, (gen) ->
                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: clang_path
                    extra_files: { }

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'clang' }
                    { 'ToolchainArchitecture', 'x64' }
                    { 'ToolchainToolset', '900' }
                    { 'ToolchainFrontend', 'clang' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', ar_path }
                    { 'ToolchainLinker', clang_path }
                    { 'ToolchainIncludeDirs', { } }
                    { 'ToolchainLibDirs', { } }
                    { 'ToolchainLibs', { } }
                }
    }
    '10': {
        name: 'clang-10.0.0'
        struct_name: 'Toolchain_Clang_x64_1000'
        compiler_name: 'compiler-clang-x64-1000'

        generate_structure: (gen, clang_path, ar_path) ->
            struct_name = 'Toolchain_Clang_x64_1000'
            compiler_name = 'compiler-clang-x64-1000'

            gen\structure struct_name, (gen) ->
                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: clang_path
                    extra_files: { }

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'clang' }
                    { 'ToolchainArchitecture', 'x64' }
                    { 'ToolchainToolset', '1000' }
                    { 'ToolchainFrontend', 'clang' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', ar_path }
                    { 'ToolchainLinker', clang_path }
                    { 'ToolchainIncludeDirs', { } }
                    { 'ToolchainLibDirs', { } }
                    { 'ToolchainLibs', { } }
                }
    }
    '11': {
        name: 'clang-11.0.0'
        struct_name: 'Toolchain_Clang_x64_1100'
        compiler_name: 'compiler-clang-x64-1100'

        generate_structure: (gen, clang_path, ar_path) ->
            struct_name = 'Toolchain_Clang_x64_1100'
            compiler_name = 'compiler-clang-x64-1100'

            gen\structure struct_name, (gen) ->
                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: clang_path
                    extra_files: { }

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'clang' }
                    { 'ToolchainArchitecture', 'x64' }
                    { 'ToolchainToolset', '1100' }
                    { 'ToolchainFrontend', 'clang' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', ar_path }
                    { 'ToolchainLinker', clang_path }
                    { 'ToolchainIncludeDirs', { } }
                    { 'ToolchainLibDirs', { } }
                    { 'ToolchainLibs', { } }
                }
    }
    '12': {
        name: 'clang-12.0.0'
        struct_name: 'Toolchain_Clang_x64_1200'
        compiler_name: 'compiler-clang-x64-1200'

        generate_structure: (gen, clang_path, ar_path) ->
            struct_name = 'Toolchain_Clang_x64_1200'
            compiler_name = 'compiler-clang-x64-1200'

            gen\structure struct_name, (gen) ->
                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: clang_path
                    extra_files: { }

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'clang' }
                    { 'ToolchainArchitecture', 'x64' }
                    { 'ToolchainToolset', '1200' }
                    { 'ToolchainFrontend', 'clang' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', ar_path }
                    { 'ToolchainLinker', clang_path }
                    { 'ToolchainIncludeDirs', { } }
                    { 'ToolchainLibDirs', { } }
                    { 'ToolchainLibs', { } }
                }
    }
}

detect_compilers = (ver_major , log_file) ->
    versions = { '9', '10', '11', '12', '13' }
    results = { }

    ar_path = Where\path 'ar', log_file
    unless os.isfile ar_path
        return { }

    for ver in *versions
        clang_path = Where\path "clang++#{ver}", log_file
        if clang_path
            results[ver] = {
                :clang_path
                :ar_path
            }

    return results[ver_major] or { }

class Clang
    @detect: (conan_profile, log_file) =>
        toolchain_list = { }

        if conan_profile and conan_profile.compiler and conan_profile.compiler.version
            ver_major = conan_profile.compiler.version

            compiler = detect_compilers ver_major, log_file
            if compiler.clang_path and compiler.ar_path

                clang_exe = compiler.clang_path
                clang_ver = (((Exec clang_exe)\lines '--version')[1]\gmatch "version (%d+).(%d+).(%d+)")!

                unless clang_ver == ver_major
                    return

                if toolchain_definition = toolchain_definitions[clang_ver]
                    table.insert toolchain_list, {
                        name: toolchain_definition.name
                        struct_name: toolchain_definition.struct_name
                        compiler_name: toolchain_definition.compiler_name
                        generate: (gen) -> toolchain_definition.generate_structure gen, clang_exe, compiler.ar_path
                    }

        toolchain_list

{ :Clang }
