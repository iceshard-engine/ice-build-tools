import Locator from require "ice.locator"

class SDK_DX12 extends Locator
    new: => super Locator.Type.CommonSDK, "DirectX 12 Locator"
    locate: (detected_info) =>
        has_win10_platform = false
        for platform in *detected_info.platform_sdks
            for tag in *platform.tags
                has_win10_platform = true if tag == "windows-10"

        if has_win10_platform
            @\add_result {
                name: 'SDK-DX12'
                struct_name: 'SDK_DX12'
                includedirs: { }
                libdirs: { }
                libs: { }
            }

{ :SDK_DX12 }
