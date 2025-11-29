import Locator from require "ice.locator"
import Windows from require "ice.platform.windows"

class SDK_Win32 extends Locator
    id: 'win32'
    name: 'Windows (x64)'

    new: => super Locator.Type.PlatformSDK, "Win32 Platform Locator"
    locate: =>
        if os.iswindows
            if win_sdk = Windows\detect_win10_sdk!
                makepri_tool = {
                    name: 'WinSDK_MakePri'
                    path: "#{win_sdk.directory}bin\\#{win_sdk.version}.0\\x64\\makepri.exe"
                }

                resource_compiler = {
                    name: 'win10-resource-compiler'
                    executable: "#{win_sdk.directory}bin\\#{win_sdk.version}.0\\x64\\rc.exe"
                    compiler_family: 'custom'
                }

                @\add_result {
                    tags: { 'Windows', 'Windows-10', 'DesktopApp' }
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

                    compilers: {
                        resource_compiler
                    }

                    tools: {
                        makepri_tool
                    }
                }

{ :SDK_Win32 }
