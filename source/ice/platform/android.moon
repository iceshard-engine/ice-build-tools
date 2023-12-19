import Path, Dir, File from require "ice.core.fs"
import Exec from require "ice.tools.exec"

import Setting from require "ice.settings"
import Log from require "ice.core.logger"

class SDKManager extends Exec
    new: (path, @deprecated) => super path

    install: (opts = { }) =>
        return false unless opts.package
        args = "--install #{opts.package}"
        @\run args

    uninstall: (opts = { }) =>
        return false unless opts.package
        args = "--uninstall #{opts.package}"
        @\run args

    list: (opts = { }) =>
        args = "--list"
        args = "--list_installed" if (not @deprecated and opts.installed)
        args ..= "--channel=#{opts.channel}" if opts.channel

        stage_builder = (origin_header, origin_pattern) ->
            (it) ->
                header = origin_header\lower!
                pattern = origin_pattern
                results = { }

                line = it!
                while not (line\lower!\match header)
                    line = it!

                -- Gather stage specific labels
                t0, t1, t2, t3 = it!\match pattern
                return results unless t2

                t0 = t0\lower!
                t1 = t1\lower!
                t2 = t2\lower!
                t3 = t3\lower! if t3

                -- Next line is '-----' so we wan't to skip it
                it!

                v0, v1, v2, v3 = it!\match pattern
                while v2 ~= nil
                    table.insert results, { [t0]:v0, [t1]:v1, [t2]:v2, [t3]:v3 } if v3
                    table.insert results, { [t0]:v0, [t1]:v1, [t2]:v2 } if not v3
                    v0, v1, v2, v3 = it!\match pattern
                results

        stage_installed = stage_builder 'installed packages', '%s*([^|%[]-)%s*|%s*([^|]-)%s*|%s*([^|]-)%s*|%s*([^|]-)%s*$'
        stage_available = stage_builder 'available packages', '%s*([^|%[]-)%s*|%s*([^|]-)%s*|%s*([^|]-)%s*$'
        stage_updates = stage_builder 'available updates', '%s*([^|%[]-)%s*|%s*([^|]-)%s*|%s*([^|]-)%s*$'

        lines = do
            tab = @\lines args
            idx = 0
            ->
                idx = idx + 1
                return tab[idx]

        results = { }
        results.installed = stage_installed lines
        results.available = stage_available lines unless opts.installed
        results.updates = stage_updates lines unless opts.installed

        return results.installed if opts.installed
        return results

class Android
    @settings: {
        Setting "android.sdk_root"
    }

    @detect_android_sdk: =>
        possible_paths = {
            { source:'implicit', location: "#{os.env.LOCALAPPDATA}/Android/Sdk" }
            { source:'environment', location: os.env.ANDROID_SDK_ROOT }
            { source:'settings', location: Setting\get "android.sdk_root" }
        }

        sdk_root = nil
        for entry in *possible_paths
            entry.location = Path\normalize entry.location

            if entry.location == nil
                Log\verbose "Skipping search for Android SDK from #{entry.source}"
            elseif (Dir\exists entry.location) == false
                Log\verbose "Skipping search for Android SDK in invalid path #{entry.location}"
            else
                Log\verbose "Searching for Android SDK in #{entry.source} path #{entry.location}..."
                Log\warning "Overriden Android SDK location from #{sdk_root} to #{entry.location}" if sdk_root and sdk_root != entry.location
                sdk_root = entry.location
        Log\verbose "Selected Android SDK at location #{sdk_root}"

        possible_paths = {
            { deprecated:true, source:'tools', location:Path\join sdk_root, "tools", "bin", "sdkmanager.bat" }
            { source:'cmdline-tools', location:Path\join sdk_root, "cmdline-tools", "latest", "bin", "sdkmanager.bat" }
        }

        sdk_manager = nil
        for entry in *possible_paths
            entry.location = Path\normalize entry.location

            if (File\exists entry.location) == false
                Log\verbose "SdkManager (#{entry.source}) not found in path: #{entry.location}" -- TODO: Verbose
            else
                Log\verbose "Selected SdkManager at path #{entry.path}"
                sdk_manager = entry


        return nil unless sdk_manager
        Log\warning "Detected deprecated SDK manager tools, consider installing the 'cmdline-tools;latest' package to avoid issues!" if sdk_manager.deprecated

        return {
            location:sdk_root
            manager:SDKManager sdk_manager.location, sdk_manager.deprecated
            manager_is_deprecated:sdk_manager.deprecated
        }

    @detect_android_ndk: =>
        return {}

{ :Android }
