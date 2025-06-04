import Setting from require "ice.settings"
import Locator from require "ice.locator"
import Path, Dir, File from require "ice.core.fs"
import Wget from require "ice.tools.wget"
import Zip from require "ice.tools.zip"
import Json from require "ice.util.json"
import SDKList from require "ice.sdks"
import Log from require "ice.core.logger"

class SDK_Vulkan extends Locator
    @tags_url = "https://api.github.com/repos/KhronosGroup/Vulkan-Headers/tags"
    @download_url = "https://sdk.lunarg.com/sdk/download/{version}/linux/vulkansdk-linux-x86_64-{version}.tar.xz"

    @settings: {
        Setting "vulkan.version", default:'latest'
        Setting "vulkan.install_location", default:'build/vulkan'
    }

    new: =>
        super Locator.Type.CommonSDK, "Vulkan SDK Locator"
        SDKList\add @

    install: (version) =>
        Log\error "Currently Vulkan SDK installation is only available on Linux distributions." unless os.isunix

        version = Setting\get 'vulkan.version'
        if version == 'latest' or version == ''
            tags = Json\decode Wget\content @@tags_url
            version = tags[1].name\match "(%d+%.%d+%.%d+%.%d+)"

        install_path = Setting\get 'vulkan.install_location'
        package_name = "vulkansdk-linux-x86_64-#{version}.tar.xz"
        package_path = Path\join install_path, package_name

        -- Create the location and download the package
        Dir\create Path\parent package_path
        Wget\url (@@download_url\gsub "{version}", version), package_path

        -- Unpack and setup variables
        sdk_root = Path\join install_path, version
        sdk_path = Path\join sdk_root, 'x86_64'

        unless Dir\exists sdk_root
            Zip\extract package_path, install_path, use_tar:true, force:true

        Log\info "Vulkan SDK v#{version} installed under '#{sdk_root}'"

    _find_version: =>
        version = Setting\get 'vulkan.version'
        if version == '' or version == 'latest'
            version = 'unknown'
            install_path = Setting\get 'vulkan.install_location'
            return version unless Dir\exists install_path
            for version_dir in Dir\list install_path
                if Dir\exists Path\join install_path, version_dir, "x86_64"
                    version = version_dir
                    break
        version

    locate: =>
        vulkan_sdk_locations = {
            Path\join (Setting\get "vulkan.install_location"), @\_find_version!, 'x86_64'
            os.getenv "VULKAN_SDK"
        }

        vulkan_sdk = nil
        for candidate_path in *vulkan_sdk_locations
            Log\debug "Vulkan-SDK: Checking candidate path: #{candidate_path}"
            if Dir\exists candidate_path
                vulkan_sdk = candidate_path

        if vulkan_sdk ~= nil
            vk_version = { vulkan_sdk\match "(%d+)%.(%d+)%.(%d+)%.(%d+)" }
            vk_version = { major:vk_version[1], minor:vk_version[2], patch:vk_version[3], build:vk_version[4] }
            vk_version_string = "#{vk_version.major}.#{vk_version.minor}.#{vk_version.patch}.#{vk_version.build}"

            glslc_compiler = {
                name: "vk-glslc-#{vk_version.major}-#{vk_version.minor}-#{vk_version.patch}"
                executable: os.osselect win:(Path\join vulkan_sdk, "Bin/glslc.exe"), unix:(Path\join vulkan_sdk, "bin/glslc")
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
                version: vk_version_string
                struct_name: 'SDK_Vulkan'
                supported_platforms: { 'Windows' }
                location: vulkan_sdk
                binaries: Path\join vulkan_sdk, "Bin"
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
                runtime_libs: {
                    "shaderc_shared"
                }
            }


{ :SDK_Vulkan }
