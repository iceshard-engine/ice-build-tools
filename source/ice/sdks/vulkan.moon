import Locator from require "ice.locator"
import Path, Dir, File from require "ice.core.fs"

class SDK_Vulkan extends Locator
    new: => super Locator.Type.CommonSDK, "Vulkan SDK Locator"
    locate: =>
        vulkan_sdk = os.getenv "VULKAN_SDK"
        if vulkan_sdk ~= nil and Dir\exists vulkan_sdk
            @\add_result {
                name: 'SDK-Vulkan'
                struct_name: 'SDK_Vulkan'
                location: vulkan_sdk
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
