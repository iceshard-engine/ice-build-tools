import Locator from require "ice.locator"

class SDK_Vulkan extends Locator
    new: => super Locator.Type.CommonSDK, "Vulkan SDK Locator"
    locate: =>
        sdk_info = nil

        vulkan_sdk = os.getenv "VULKAN_SDK"
        if vulkan_sdk ~= nil and os.isdir vulkan_sdk
            sdk_info = { }
            sdk_info.name = 'SDK-Vulkan'
            sdk_info.struct_name = 'SDK_Vulkan'
            sdk_info.location = vulkan_sdk
            sdk_info.includedirs = {
                "#{vulkan_sdk}\\Include"
            }
            sdk_info.libdirs = {
                "#{vulkan_sdk}\\Lib"
            }
            sdk_info.libs = {
                "vulkan-1"
            }

            @\add_result sdk_info


{ :SDK_Vulkan }
