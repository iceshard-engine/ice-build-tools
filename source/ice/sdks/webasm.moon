import Locator from require "ice.locator"
import WebAsm from require "ice.platform.webasm"
import Path, Dir, File from require "ice.core.fs"
import Json from require "ice.util.json"
import Exec from require "ice.tools.exec"

create_toolchain = (ver_major, emver, emver_full, arch_list) ->
    return {
        name: "em#{emver}-clang-#{ver_major}.0.0"
        struct_name: "Toolchain_EM#{emver}_Clang_#{ver_major}00"
        compiler_name: "compiler-em#{emver}-clang-#{ver_major}00"

        generate_structure: (gen, clang_path, ar_path, em_path) ->
            struct_name = "Toolchain_EM#{emver}_Clang_#{ver_major}00"
            compiler_name = "compiler-em#{emver}-clang-#{ver_major}00"

            gen\structure struct_name, (gen) ->
                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: clang_path
                    compiler_family: 'clang'
                    extra_files: { }

                gen\line!
                gen\variables {
                    { 'EMSDKPath', Path.Unix\normalize em_path }
                    { 'EMSDKVersion', emver_full }
                    { 'ToolchainCompilerFamily', 'em-clang' }
                    { 'ToolchainSupportedArchitectures', arch_list or { } }
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

class SDK_WebAsm extends Locator
    new: =>
        super Locator.Type.PlatformSDK, "WebAssembly Platform Locator"
        @settings = WebAsm.settings

    locate: =>
        if sdk_path = WebAsm\detect_webasm_sdk!
            sdk_path = sdk_path.location

            llvm_path = Path\join sdk_path, "upstream/bin"
            em_path = Path\join sdk_path, "upstream/emscripten"
            em_tools = {
                cc: Path\join em_path, os.osselect win:"emcc.bat", unix:"emcc",
                cxx: Path\join em_path, os.osselect win:"em++.bat", unix:"em++",
                ar: Path\join em_path, os.osselect win:"emar.bat", unix:"emar",
                clang: Path\join llvm_path, os.osselect win:"clang.exe", unix:"clang",
                file_packager: Path\join em_path, 'tools/file_packager.bat'
                -- clangpp: Path\join llvm_path, os.osselect win:"clang++.exe", unix:"clang++",
            }

            em_major, em_minor, em_patch = ((Exec em_tools.cc)\lines '--version')[1]\match "emcc[^%d]+(%d+).(%d+).(%d+)"
            em_full = "#{em_major}.#{em_minor}.#{em_patch}"

            clang_major, clang_minor, clang_patch = (((Exec em_tools.clang)\lines '--version')[1]\gmatch "version (%d+).(%d+).(%d+)")!
            toolchain_definition = create_toolchain clang_major, em_major, em_full, { 'webasm' }

            @\add_result {
                name: toolchain_definition.name
                struct_name: toolchain_definition.struct_name
                compiler_name: toolchain_definition.compiler_name
                generate: (gen) -> toolchain_definition.generate_structure gen, em_tools.cxx, em_tools.ar, sdk_path
            }, Locator.Type.Toolchain

            @\add_result {
                tags: { 'WebAsm', 'EmScripten' }
                name: 'SDK-WebAsm'
                struct_name: 'SDK_WebAsm'
                includedirs: { }
                libdirs: { }
                libs: { }
                compilers: { }
                tools: {
                    { name: 'EmScripten_FilePackager', path:em_tools.file_packager }
                }
            }

{ :SDK_WebAsm }
