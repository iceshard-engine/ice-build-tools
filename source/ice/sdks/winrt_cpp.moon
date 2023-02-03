import Locator from require "ice.locator"
import Windows from require "ice.platform.windows"

class SDK_Cpp_WinRT extends Locator
    new: => super Locator.Type.PlatformSDK, "C++/WinRT Platform Locator"
    locate: =>
        if os.iswindows
            win_sdk = Windows\detect_win10_sdk!
            win_sdk_winrt = os.isdir "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\cppwinrt" if win_sdk ~= nil

            if win_sdk and win_sdk_winrt
                makepri_tool = {
                    name: 'WinSDK_MakePri'
                    path: "#{win_sdk.directory}bin\\#{win_sdk.version}.0\\x64\\makepri.exe"
                }

                @\add_result {
                    tags: { 'Windows', 'Windows-10', 'WinRT', 'StoreApp' }
                    name: 'SDK-Windows-10-CXX-WinRT'
                    struct_name: 'SDK_Windows_10_CXX_WinRT'
                    includedirs: {
                        "#{win_sdk.directory}Include\\#{win_sdk.version}.0\\cppwinrt"
                    }
                    libdirs: {
                    }
                    libs: {
                        "RuntimeObject"
                        "WindowsApp"
                    }

                    tools: {
                        makepri_tool
                    }
                }

{ :SDK_Cpp_WinRT }
