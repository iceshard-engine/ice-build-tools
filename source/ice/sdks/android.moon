import Locator from require "ice.locator"
import Android from require "ice.platform.android"
import Path, Dir, File from require "ice.core.fs"
import Json from require "ice.util.json"
import Exec from require "ice.tools.exec"

create_toolchain = (ver_major, ndkver, arch_list) ->
    return {
        name: "ndk#{ndkver}-clang-#{ver_major}.0.0"
        struct_name: "Toolchain_NDK#{ndkver}_Clang_#{ver_major}00"
        compiler_name: "compiler-ndk#{ndkver}-clang-#{ver_major}00"

        generate_structure: (gen, clang_path, ar_path, ndk_path) ->
            struct_name = "Toolchain_NDK#{ndkver}_Clang_#{ver_major}00"
            compiler_name = "compiler-ndk#{ndkver}-clang-#{ver_major}00"

            gen\structure struct_name, (gen) ->
                gen\line!
                gen\compiler
                    name: compiler_name
                    executable: clang_path
                    extra_files: { }

                gen\line!
                gen\variables {
                    { 'NDKPath', ndk_path }
                    { 'ToolchainCompilerFamily', 'ndk-clang' }
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

class SDK_Android extends Locator
    new: =>
        super Locator.Type.PlatformSDK, "Android Platform Locator"
        @settings = Android.settings

    locate: =>
        if sdk = Android\detect_android_sdk!
            sdk_packages = sdk.manager\list installed:true

            -- Allowed Android 'Platforms'
            allowed = { }

            android_flavour = (toolchain, ndkmajor, apilevel, abi) ->
                return {
                    name: "Android#{apilevel}-NDK#{ndkmajor}-#{abi.arch}"
                    struct_name: "Flavour_Android#{apilevel}_NDK#{ndkmajor}_#{abi.arch}"
                    requires: { "Android#{apilevel}-API", toolchain, abi.arch }
                    variables: {
                        { 'BuildOptions', { "-target #{abi.llvm_triple}#{apilevel}" } }
                        { 'LinkLinkerOptions', { "-target #{abi.llvm_triple}#{apilevel}" } }
                    }
                }

            -- Go over all NDK packages
            flavours = { }
            for pkg in *sdk_packages
                continue unless pkg.path\lower!\match "ndk"
                if ndk = @_add_ndk sdk, pkg, allowed
                    for _, abi in pairs ndk.abis
                        for apilevel=ndk.platforms.min, ndk.platforms.max
                            table.insert flavours, android_flavour ndk.toolchain, ndk.version, apilevel, abi

            @\add_result {
                tags: { 'Android' }
                name: 'SDK-Android'
                struct_name: 'SDK_Android'
                includedirs: { }
                libdirs: { }
                libs: { }
                compilers: { }
                tools: { }
                flavours:flavours
            }

    _add_ndk: (sdk, pkg, allowed) =>
        ndk_path = Path\join sdk.location, pkg.location
        ndk_major = pkg.version\match '^(%d+)'

        abis = File\load (Path\join ndk_path, 'meta', 'abis.json'), parser:Json\decode
        platforms = File\load (Path\join ndk_path, 'meta', 'platforms.json'), parser:Json\decode

        toolchain_path = Path\join ndk_path, 'toolchains', 'llvm', 'prebuilt', 'windows-x86_64'
        clang_path = Path\join toolchain_path, 'bin', 'clang++.exe'
        ar_path = Path\join toolchain_path, 'bin', 'llvm-ar.exe'

        clang_major, clang_minor, clang_patch = (((Exec clang_path)\lines '--version')[1]\gmatch "version (%d+).(%d+).(%d+)")!
        toolchain_definition = create_toolchain clang_major, ndk_major, [abi.arch for _, abi in pairs abis]

        @\add_result {
            name: toolchain_definition.name
            struct_name: toolchain_definition.struct_name
            compiler_name: toolchain_definition.compiler_name
            generate: (gen) -> toolchain_definition.generate_structure gen, clang_path, ar_path, ndk_path
        }, Locator.Type.Toolchain

        return { toolchain:toolchain_definition.name, version:ndk_major, :abis, :platforms }

{ :SDK_Android }