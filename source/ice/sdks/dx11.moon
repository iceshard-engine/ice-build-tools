import Locator from require 'ice.locator'

class SDK_DX11 extends Locator
    new: => super Locator.Type.CommonSDK, "DirectX 11 Locator"
    locate: (platforms) =>
        sdk_info = nil

        has_win10_platform = false
        for platform in *platforms
            for tag in *platform.tags
                has_win10_platform = true if tag == "windows-10"

        if has_win10_platform
            sdk_info = {
                name: 'SDK-DX11'
                struct_name: 'SDK_DX11'
                includedirs: { }
                libdirs: { }
                libs: {
                    'DXGI'
                    'D3D11'
                    'dxguid'
                }
            }

        { sdk_info }

{ :SDK_DX11 }
