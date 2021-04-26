import Locator from require 'ice.locator'
import Windows from require 'ice.platform.windows'

class SDK_Win32 extends Locator
    new: => super Locator.Type.PlatformSDK, "Win32 Platform Locator"
    locate: =>
        if os.iswindows
            if win_sdk = Windows\detect_win10_sdk!
                sdk_info = {
                    tags: { 'windows', 'windows-10' }
                    name: 'SDK-Windows-10'
                    struct_name: 'SDK_Windows_10'
                    includedirs: {
                        "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\ucrt"
                        "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\um"
                        "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\shared"
                    }
                    libdirs: {
                        "#{win_sdk.directory}Lib\\#{win_sdk.version}.0\\ucrt\\x64"
                        "#{win_sdk.directory}Lib\\#{win_sdk.version}.0\\um\\x64"
                    }
                    libs: { }
                }
                return { sdk_info }

{ :SDK_Win32 }
