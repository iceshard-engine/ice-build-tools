class Vulkan
    @detect: =>
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

        sdk_info

{ :Vulkan }
