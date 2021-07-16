import Locator from require 'ice.locator'
import Windows from require 'ice.platform.windows'

class SDK_Linux extends Locator
    new: => super Locator.Type.PlatformSDK, "Linux Platform Locator"
    locate: =>
        sdk_list = { }

        if os.isunix
            sdk_info = {
                tags: { 'linux', 'unix' }
                name: 'SDK-Linux'
                struct_name: 'SDK_Linux'
                includedirs: { }
                libdirs: { }
                libs: { }
            }
            table.insert sdk_list, sdk_info

        sdk_list

{ :SDK_Linux }
