import Locator from require 'ice.locator'

class SDK_DX12 extends Locator
    new: => super Locator.Type.CommonSDK, "DirectX 12 Locator"
    locate: (platforms) =>
        sdk_info = nil

        has_win10_platform = false
        for platform in *platforms
            for tag in *platform.tags
                has_win10_platform = true if tag == "windows-10"

        if has_win10_platform
            sdk_info = {
                name: 'SDK-DX12'
                struct_name: 'SDK_DX12'
                includedirs: { }
                libdirs: { }
                libs: { }
            }

        { sdk_info }

{ :SDK_DX12 }
