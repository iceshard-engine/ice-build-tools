import Locator from require 'ice.locator'
import Windows from require 'ice.platform.windows'

class SDK_Linux extends Locator
    new: => super Locator.Type.PlatformSDK, "Linux Platform Locator"
    locate: =>
        if os.isunix
            @\add_result {
                tags: { 'Linux', 'Unix', 'POSIX' }
                name: 'SDK-Linux'
                struct_name: 'SDK_Linux'
                includedirs: { }
                libdirs: { }
                libs: { }
            }

{ :SDK_Linux }
