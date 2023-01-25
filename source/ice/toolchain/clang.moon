import Where, Exec from require "ice.tools.exec"

toolchain_definitions = {
    generated: (ver_major) ->
        return {
            name: "clang-#{ver_major}.0.0"
            struct_name: "Toolchain_Clang_#{ver_major}00"
            compiler_name: "compiler-clang-#{ver_major}00"

            generate_structure: (gen, clang_path, ar_path) ->
                struct_name = "Toolchain_Clang_#{ver_major}00"
                compiler_name = "compiler-clang-#{ver_major}00"

                gen\structure struct_name, (gen) ->
                    gen\line!
                    gen\compiler
                        name: compiler_name
                        executable: clang_path
                        extra_files: { }

                    gen\line!
                    gen\variables {
                        { 'ToolchainCompilerFamily', 'clang' }
                        { 'ToolchainSupportedArchitectures', { 'x64' } }
                        { 'ToolchainToolset', "#{ver_major}00" }
                        { 'ToolchainFrontend', 'CLANG' }
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
    versions = { '9', '10', '11', '12', '13', '14', '15', '16' }
    results = { }

    ar_path = Where\path 'ar', log_file
    unless os.isfile ar_path
        return { }

    for clang_ver in *versions
        clang_path = Where\path "clang++-#{clang_ver}", log_file
        if clang_path
            clang_major, clang_minor, clang_patch = (((Exec clang_path)\lines '--version')[1]\gmatch "version (%d+).(%d+).(%d+)")!

            results[clang_major] = {
                ver: { major:clang_major, minor:clang_minor, patch:clang_patch }
                :clang_path
                :ar_path
            }
            results[clang_major .. '.' .. clang_minor] = {
                ver: { major:clang_major, minor:clang_minor, patch:clang_patch }
                :clang_path
                :ar_path
            }

    return results[ver_major] or { }

class Clang
    @detect: (conan_profile, log_file) =>
        toolchain_list = { }

        -- Only check for clang compiler versions
        unless conan_profile and conan_profile.compiler and conan_profile.compiler.name == 'clang'
            return

        if conan_profile.compiler.version
            ver_major = conan_profile.compiler.version

            compiler = detect_compilers ver_major, log_file
            if compiler.clang_path and compiler.ar_path

                clang_exe = compiler.clang_path
                clang_ver = compiler.ver.major

                if toolchain_definition = toolchain_definitions[clang_ver] or toolchain_definitions['generated']
                    -- If we got a function we try to generate the clang toolchain info
                    if (type toolchain_definition) == 'function'
                        toolchain_definition = toolchain_definition clang_ver

                    if toolchain_definition
                        table.insert toolchain_list, {
                            name: toolchain_definition.name
                            struct_name: toolchain_definition.struct_name
                            compiler_name: toolchain_definition.compiler_name
                            generate: (gen) -> toolchain_definition.generate_structure gen, clang_exe, compiler.ar_path
                        }

        toolchain_list

{ :Clang }
