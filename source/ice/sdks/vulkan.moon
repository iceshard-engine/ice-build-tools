import Locator from require "ice.locator"
import Path, Dir, File from require "ice.core.fs"

class SDK_Vulkan extends Locator
    new: => super Locator.Type.CommonSDK, "Vulkan SDK Locator"
    locate: =>
        vulkan_sdk = os.getenv "VULKAN_SDK"
        if vulkan_sdk ~= nil and Dir\exists vulkan_sdk
            vk_version = { (Path\name vulkan_sdk)\match "(%d+)%.(%d+)%.(%d+)%.%d+" }
            vk_version = { major:vk_version[1], minor:vk_version[2], patch:vk_version[3], build:vk_version[4] }

            glslc_compiler = {
                name: "vk-glslc-#{vk_version.major}-#{vk_version.minor}-#{vk_version.patch}"
                executable: Path\join vulkan_sdk, "Bin/glslc.exe"
                compiler_family: 'custom'
            }
            glslc_struct_name = "Toolchain_VK_GLSLC_#{vk_version.major}_#{vk_version.minor}"
            glslc_toolchain = {
                name: "vk-glslc-#{vk_version.major}-#{vk_version.minor}"
                struct_name: glslc_struct_name
                compiler_name: glslc_compiler.name
                generate: (gen) ->
                    gen\structure glslc_struct_name, (gen) ->
                        gen\line!
                        gen\compiler glslc_compiler

                        gen\line!
                        gen\variables {
                            { 'ToolchainCompilerFamily', 'vk-glslc' }
                            { 'ToolchainSupportedArchitectures', { 'Vulkan1.0', 'Vulkan1.1', 'Vulkan1.2', 'Vulkan1.3', 'OpenGL4.5' } }
                            { 'ToolchainToolset', "glslc-#{vk_version.major}#{vk_version.minor}-#{vk_version.patch}" }
                            { 'ToolchainFrontend', 'VKGLSLC' }
                            { 'ToolchainCompiler', glslc_compiler.name }
                            { 'ToolchainLibrarian', '' }
                            { 'ToolchainLinker', '' }
                            { 'ToolchainIncludeDirs', { } }
                            { 'ToolchainLibDirs', { } }
                            { 'ToolchainLibs', { } }
                        }
            }

            @\add_result glslc_toolchain, Locator.Type.Toolchain

            @\add_result {
                tags: { 'Vulkan' }
                name: 'GFX-Vulkan'
                struct_name: 'GFX_Vulkan'
                includedirs: { }
                libdirs: { }
                libs: { }
            }, Locator.Type.PlatformSDK

            @\add_result {
                name: 'SDK-Vulkan'
                struct_name: 'SDK_Vulkan'
                supported_platforms: { 'Windows' }
                location: vulkan_sdk
                defines: { 'VK_USE_PLATFORM_WIN32_KHR' }
                includedirs: {
                    Path\join vulkan_sdk, "Include"
                }
                libdirs: {
                    Path\join vulkan_sdk, "Lib"
                }
                libs: {
                    "vulkan-1"
                }
            }


{ :SDK_Vulkan }
