import Vulkan from require 'ice.sdks.vulkan'

class SDKS
    @detect: =>
        sdk_list = { }

        if vulkan_sdk = Vulkan\detect!
            table.insert sdk_list, vulkan_sdk

        sdk_list

{ :SDKS }
