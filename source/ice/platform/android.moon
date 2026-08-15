import Path, Dir, File from require "ice.core.fs"
import Version from require "ice.core.version"
import Exec, Where from require "ice.tools.exec"
import Zip from require "ice.tools.zip"
import Wget from require "ice.tools.wget"

import Setting from require "ice.settings"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

class SDKManager extends Exec
    new: (path, @sdkpath, @deprecated) => super path

    install: (opts = { }) =>
        return false unless opts.package
        args = "--sdk=#{@sdkpath} sdk install #{opts.package}"
        @\run args

    remove: (opts = { }) =>
        return false unless opts.package
        args = " --sdk=#{@sdkpath} sdk remove #{opts.package}"
        @\run args

    uninstall: (opts = { }) => @remove opts

    list: (opts = { }) =>
        args = "--sdk=#{@sdkpath} sdk list"
        args ..= " --all" unless opts.installed
        args ..= " --beta" if opts.channel == 'beta'
        args ..= " --canary" if opts.channel == 'canary'

        stage_builder = (origin_header, origin_pattern, store) ->
            (it, installed) ->
                header = origin_header\lower!
                pattern = origin_pattern
                results = { }
                updates = { }

                line = it!
                while line and not (line\lower!\match header)
                    line = it!
                return {} unless line 

                Log\debug "Starting with line: '#{line}'"
                line = it!

                while line
                    path, version_str, description = line\match pattern
                    break unless description

                    id = path\match "([^/]+/?[^%.]*)"
                    version = Version\from_str version_str

                    Log\debug "Matched: '#{path}' + '#{version_str}' + '#{description}'"
                    entry = { :id, :path, :version, :description }

                    table.insert results, entry
                    if store
                        entry.location = Path\join @sdkpath, path
                        installed[id] = entry
                    elseif installed[id] and installed[id].version < version
                        table.insert updates, entry
                    line = it!

                results, updates

        stage_installed = stage_builder 'Installed packages', '^%s+([^%s:]+)%s*([^%s:]+)%s*(.-)%s*$', true
        stage_available = stage_builder 'Available packages', '^%s+([^%s:]+)%s*([^%s:]+)%s*(.-)%s*$', false

        Log\debug "Invoking Android Manager with arguments: #{args}"

        lines_tab = @\lines args
        lines = ->
            tab = lines_tab
            idx = 0
            ->
                idx = idx + 1
                return tab[idx]

        results = { }
        installed = { }

        Log\debug "Checking installed Android packages..."
        results.installed = stage_installed lines!, installed
        Log\debug "Checking available Android packages..."
        results.available, results.updates = stage_available lines!, installed unless opts.installed

        return results.installed if opts.installed
        return results

class Android
    @settings: {
        Setting "android.sdk_root" -- deprecated
        Setting "android.sdk.root"
        Setting "android.sdk.cmdline_tools_version"
        Setting 'android.gradle.version', default:'9.3.1'
        Setting 'android.gradle.package_url', default:"https://downloads.gradle.org/distributions/gradle-{ver}-bin.zip"
        Setting 'android.gradle.local_install', default:'build/gradle'
    }

    @detect_gradle: (opts = {}) =>
        gradle_ver = Setting\get 'android.gradle.version'
        gradle_local = Path\join Dir\current!, (Setting\get 'android.gradle.local_install')

        gradle_paths = {
            Path\join gradle_local, "gradle-#{gradle_ver}", "bin", os.osselect win:'gradle.bat', unix:'gradle'
            Where\path 'gradle', os.osselect unix:'/dev/null'
        }

        -- Check for common paths
        unless opts.force_install
            for path in *gradle_paths
                return Exec path if File\exists path

        -- Intall locally if requested
        gradle_bin = gradle_paths[1]
        if opts.install_if_missing or opts.force_install
            gradle_package = (Setting\get 'android.gradle.package_url')\gsub "{ver}", gradle_ver
            gradle_zip = "build/gradle-#{gradle_ver}-bin.zip"

            -- Download and extract the gradle zip into the local install path
            unless File\exists gradle_bin
                Wget\url gradle_package, gradle_zip unless File\exists gradle_zip
                Zip\extract gradle_zip, gradle_local, force:true
                Log\verbose "Installed Gradle at '#{gradle_bin}'"
            else
                Log\verbose "Gradle already installed at '#{gradle_bin}'"

        return (Exec gradle_bin) if File\exists gradle_bin

    @detect_android_sdk: =>
        possible_paths = {
            { source:'implicit', location: "#{os.env.LOCALAPPDATA or os.env.HOME}/Android/Sdk" }
            { source:'environment', location: os.env.ANDROID_SDK_ROOT }
            { source:'settings', location: Setting\get "android.sdk.root" }
            { source:'settings', location: Setting\get "android.sdk_root" }
        }

        sdk_root = nil
        for entry in *possible_paths

            if entry.location == nil
                Log\verbose "Skipping search for Android SDK from #{entry.source}"
                continue

            -- The new 'android' binary does not seem to handle '~' too well.
            --   We are replacing it ourselves here
            final_location = entry.location\gsub '~', os.env.HOME
            final_location = Path\normalize final_location

            if (Dir\exists final_location) == false
                Log\verbose "Skipping search for Android SDK in invalid path #{final_location}"
            else
                Log\verbose "Searching for Android SDK in #{entry.source} path #{final_location}..."
                Log\warning "Overriden Android SDK location from #{sdk_root} to #{final_location}" if sdk_root and sdk_root != final_location
                sdk_root = final_location

        -- Early exit if no sdk was found
        unless sdk_root
            Log\verbose "No Android SDK could be found, skipping..."
            return

        Log\verbose "Selected Android SDK at location #{sdk_root}"

        sdkmanager_bin = os.osselect win:"android.bat", unix:"android"
        cmdline_tools_basepath = Path\join sdk_root, "cmdline-tools"
        cmdline_tools_version = (Setting\get "android.sdk.cmdline_tools_version") or "latest"
        if cmdline_tools_version == "latest"
            Log\verbose "Searching for latest command-line tools package at #{cmdline_tools_basepath}"
            tools_path = Path\join cmdline_tools_basepath, cmdline_tools_version
            unless Dir\exists tools_path
                current_ver = Version\from_str "0.0"

                -- Run over each path and compare versions
                for path, m in Dir\list tools_path, recursive:false
                    path_ver = Version\from_str path
                    Log\verbose "Checking path #{path} for an expected version of command-line tools package..."
                    if path_ver and path_ver\newer current_ver
                        cmdline_tools_version = path
                        Log\verbose "Selecting new version for android command-line tools: #{cmdline_tools_version}"

            if Dir\exists tools_path
                Log\info "Selected version for android command-line tools: #{cmdline_tools_version}"
            else
                Log\error "Failed to find a valid version of command-line tools package"

        possible_paths = {
            { source:'cmdline-tools', location:Path\join cmdline_tools_basepath, cmdline_tools_version, "bin", sdkmanager_bin }
        }

        sdk_manager = nil
        for entry in *possible_paths
            final_location = Path\normalize entry.location

            if (File\exists final_location) == false
                Log\verbose "SdkManager (#{entry.source}) not found in path: #{final_location}"
            else
                Log\verbose "Selected SdkManager at path #{final_location}"
                sdk_manager = entry

        return nil unless sdk_manager
        Log\verbose "Found SDK manager under location: #{sdk_manager.location}"

        Validation\assert os.env.JAVA_HOME ~= nil, "The 'JAVA_HOME' variable does not exist"
        Validation\assert (Dir\exists os.env.JAVA_HOME), "The 'JAVA_HOME' path does not exist: #{os.env.JAVA_HOME}"

        return {
            location:sdk_root
            manager:SDKManager sdk_manager.location, sdk_root, sdk_manager.deprecated
            manager_is_deprecated:sdk_manager.deprecated
        }

{ :Android }
