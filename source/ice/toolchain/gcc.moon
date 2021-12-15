import Where, Exec from require "ice.tools.exec"

toolchain_definitions = {
    '11': {
        name: 'gcc-11.0.0'
        struct_name: 'Toolchain_gcc_x64_11'
        compiler_name: 'compiler-gcc-x64-11'

        generate_structure: (gen, gcc_path, ar_path) ->
            struct_name = 'Toolchain_gcc_x64_11'
            compiler_name = 'compiler-gcc-x64-11'

            gen\structure struct_name, (gen) ->
                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: gcc_path
                    extra_files: { }

                gen\line!
                gen\variables {
                    { 'ToolchainCompilerFamily', 'gcc' }
                    { 'ToolchainArchitecture', 'x64' }
                    { 'ToolchainToolset', '11' }
                    { 'ToolchainFrontend', 'gcc' }
                    { 'ToolchainCompiler', compiler_name }
                    { 'ToolchainLibrarian', ar_path }
                    { 'ToolchainLinker', gcc_path }
                    { 'ToolchainIncludeDirs', { } }
                    { 'ToolchainLibDirs', { } }
                    { 'ToolchainLibs', { } }
                }
    }
}

detect_compilers = (ver_major, log_file) ->
    execs = { 'g++', 'gcc', 'gcc-11' }
    results = { }

    ar_path = Where\path 'ar', log_file
    unless os.isfile ar_path
        return { }

    for exec in *execs
        gcc_path = Where\path "#{exec}", log_file
        if gcc_path
            gcc_ver_lines = ((Exec gcc_path)\lines '--version')
            gcc_major, gcc_minor, gcc_patch = (gcc_ver_lines[1]\gmatch "(%d+).(%d+).(%d+)")!

            results[gcc_major] = {
                ver: { major:gcc_major, minor:gcc_minor, patch:gcc_patch }
                :gcc_path
                :ar_path
            }
            results[gcc_major .. '.' .. gcc_minor] = {
                ver: { major:gcc_major, minor:gcc_minor, patch:gcc_patch }
                :gcc_path
                :ar_path
            }

    return results[ver_major] or { }

class Gcc
    @detect: (conan_profile, log_file) =>
        toolchain_list = { }

        if conan_profile and conan_profile.compiler and conan_profile.compiler.version
            ver_major = conan_profile.compiler.version

            compiler = detect_compilers ver_major, log_file
            if compiler.gcc_path and compiler.ar_path

                gcc_exe = compiler.gcc_path
                gcc_major = compiler.ver.major

                if toolchain_definition = toolchain_definitions[gcc_major]
                    table.insert toolchain_list, {
                        name: toolchain_definition.name
                        struct_name: toolchain_definition.struct_name
                        compiler_name: toolchain_definition.compiler_name
                        generate: (gen) -> toolchain_definition.generate_structure gen, gcc_exe, compiler.ar_path
                    }

        toolchain_list

{ :Gcc }
