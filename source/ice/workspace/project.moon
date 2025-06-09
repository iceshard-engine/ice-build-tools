import Locator from require "ice.locator"

import SDK_Vulkan from require "ice.sdks.vulkan"
import SDK_DX11 from require "ice.sdks.dx11"
import SDK_DX12 from require "ice.sdks.dx12"
import SDK_Win32 from require "ice.sdks.win32"
import SDK_Linux from require "ice.sdks.linux"
import SDK_Cpp_WinRT from require "ice.sdks.winrt_cpp"
import SDK_Android from require "ice.sdks.android"
import SDK_WebAsm from require "ice.sdks.webasm"
import TC_MSVC from require "ice.toolchain.vs_msvc"
import TC_Clang from require "ice.toolchain.clang"

import Conan from require "ice.tools.conan"
import FastBuild from require "ice.tools.fastbuild"
import FastBuildBuildSystem from require "ice.workspace.buildsystem"

import ConanProfiles from require "ice.workspace.profile"
import ProjectApplication from require "ice.workspace.application"

import Setting, Settings from require "ice.settings"
import Path, File, Dir from require "ice.core.fs"
import Json from require "ice.util.json"
import INIConfig from require "ice.util.iniconfig"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

install_conan_dependencies = ->

project_settings = {
    Setting 'project.script_file', required:true, predicate:File\exists
    Setting 'project.source_dir', default:'source/code', predicate:Dir\create
    Setting 'project.output_dir', default:'build', predicate:Dir\create
    Setting 'project.fbuild.config_file', default:'source/fbuild.bff', predicate:File\exists
    Setting 'project.fbuild.user_includes', default:{ }, predicate:(list) ->
        for file in *(list or { })
            return false unless File\exists file
        return true
    Setting 'project.fbuild.vstudio_solution_file'
}

class Project
    @locators: {
        TC_MSVC
        TC_Clang
        SDK_Win32
        SDK_Linux
        -- SDK_Cpp_WinRT
        SDK_DX11
        SDK_DX12
        SDK_Vulkan
        SDK_Android
        SDK_WebAsm
    }

    new: (@name) =>
        ProjectApplication.name = @name

        @workspace_root = os.cwd!\gsub '\\', '/'
        @application_class = ProjectApplication

        @locators =
            [Locator.Type.Toolchain]: { }
            [Locator.Type.PlatformSDK]: { }
            [Locator.Type.CommonSDK]: { }

        -- Initialize with default locators
        @add_locator locator_type! for locator_type in *(@@locators or {})
        @_load_settings 'tools/settings.json'

        -- Deserialize all settings
        Settings\deserialize @raw_settings

    _load_settings: (@project_settings_file) =>
        Validation\assert File\exists @project_settings_file, "Settings file does not exist: #{@project_settings_file}"

        @raw_settings = File\load @project_settings_file, mode:'r', parser:Json\decode
        @raw_settings = { } if (type @raw_settings) == 'string'

        override_values = (src_tab, target_tab) ->
            for key, value in pairs src_tab
                if target_tab[key] ~= nil and (type src_tab[key]) != (type target_tab[key])
                    Log\error "Mismatched types when applying '#{os.osname}' settings."
                elseif (type target_tab[key]) == 'table'
                    override_values src_tab[key], target_tab[key]
                else
                    target_tab[key] = src_tab[key]

        -- Override settings with their os overrides
        override_values @raw_settings[os.osname] or { }, @raw_settings

        @settings = { }
        for setting in *project_settings
            setting\deserialize @raw_settings, @settings

    application: (@application_class) =>
    add_locator: (locator) =>
        table.insert @locators[locator.type], locator
        for setting in *(locator.settings or {})
            table.insert project_settings, setting

    set: (setting, value) => Settings\set setting, value

    profiles: (profiles_file) =>
        Log\warning "The 'Project::profiles_file' method is deprecated.\nPlease use 'Project::set \"project.conan.profiles_file\", <value>' instead or the 'settings.json' file."
        Settings\set 'project.conan.profiles_file', profiles_file

    fastbuild_script: (script_location) =>
        Log\warning "The 'Project::fastbuild_script' method is deprecated.\nPlease use 'Project::set \"project.fbuild.config_file\", <value>' instead or the 'settings.json' file."
        Settings\set 'project.fbuild.config_file', script_location

    fastbuild_vstudio_solution: (name) =>
        Log\warning "The 'Project::fastbuild_vstudio_solution' method is deprecated.\nPlease use 'Project::set \"project.fbuild.vstudio_solution_file\", <value>' instead or the 'settings.json' file."
        Settings\set 'project.fbuild.vstudio_solution_file', "#{name}.sln"

    sources: (source_directory) =>
        Log\warning "The 'Project::sources' method is deprecated.\nPlease use 'Project::set \"project.source_dir\", <value>' instead or the 'settings.json' file."
        Settings\set 'project.source_dir', source_directory

    output: (output_directory) =>
        Log\warning "The 'Project::sources' method is deprecated.\nPlease use 'Project::set \"project.output_dir\", <value>' instead or the 'settings.json' file."
        Settings\set 'project.output_dir', output_directory

    load_settings: =>  Log\warning "The 'Project::load_settings' method is deprecated and can be safely removed."
    working_dir: => Log\warning "The 'Project::working_dir' method is deprecated and can be safely removed."

    finish: (force_detect) =>
        @project_script = Setting\get 'project.script_file'
        @output_directory = Setting\get 'project.output_dir'
        @source_directory = Setting\get 'project.source_dir'
        @script_location = Setting\get 'project.fbuild.config_file'
        @output_directory_abs = Path\join @workspace_root, @output_directory

        Validation\assert @output_directory ~= nil and @output_directory ~= "", "Invalid value for `output` => '#{@output_directory}'"
        Validation\assert @source_directory ~= nil and @source_directory ~= "", "Invalid value for `sources` => '#{@source_directory}'"
        Validation\assert @project_script ~= nil and @project_script ~= "", "Invalid value for `project_script` => '#{@project_script}'"

        Validation\assert @script_location ~= nil and @script_location ~= "", "Invalid value for `fastbuild_script` => '#{@script_location}'"
        Validation\assert (os.isfile @script_location), "Non existing file set in `fastbuild_script` => '#{@script_location}'"

        application = @['application_class'] @raw_settings, @locators[Locator.Type.PlatformSDK]

        -- File containing the forced platform
        forced_platform_file = Path\join @output_directory, 'selected_platform.txt'
        if File\exists forced_platform_file
            platform_id = File\load forced_platform_file
            for locator in *@locators[Locator.Type.PlatformSDK]
                if locator.id == platform_id
                    @locators[Locator.Type.PlatformSDK] = { locator }
                    break

        @build_system = FastBuildBuildSystem {
            locators:@locators
            profiles:{} -- selected_profiles
            workspace_dir:@workspace_root
            output_dir:@output_directory
            source_dir:@source_directory
            user_includes:Setting\get 'project.fbuild.user_includes'
            -- Files
            files: {
                ibt:@project_script
                solution_name:Setting\get 'project.fbuild.vstudio_solution_file'
                fbuild_workspace_file:@script_location
            }
        }

        conan_soft_init = -> Dir\enter @workspace_root, ->
            @build_system\generate!

            -- If we use conanfile.py instead of conanfile.txt we generate things a bit different.
            --   In such a case conan is the main caller not 'IBT' so we need to follow CONAN workflow
            --   NOTE: Projects should use 'conan create .' to build in such a case
            file_conan_py = File\exists 'conanfile.py'

            -- Don't generate anything if conanfile.py is present, the 'conan' is responsible for generating necessary files.
            if file_conan_py == false
                -- Execute FBuild to generate conan_profiles.txt
                @profiles = ConanProfiles\find_required_profiles @output_directory_abs
                @profiles\install_all!

                -- Secondary call to generate 'fbuild_conanmodules.bff' file
                -- We can do it in two stages, becase the first stage only checks for available pipelines, it does not require any compile data to be present yet
                @build_system\generate_conanmodules @profiles.list

        command_result = application\run
            script: @project_script
            workspace_dir: @workspace_root
            source_dir: @source_directory
            output_dir: @output_directory
            fastbuild_solution_name: @solution_name
            settings_file:@project_settings_file
            forced_platform_file:forced_platform_file
            action: {
                init_conan: -> conan_soft_init!
                generate_build_system_files: -> @build_system\generate force:true
                build_conan_profiles: -> @profiles = ConanProfiles\find_required_profiles @output_directory_abs, force:true
                build_conan_modules: (list) -> @build_system\generate_conanmodules list
                install_conan_dependencies: -> @profiles\install_all force:true
                generate_conanmodules_file: -> @build_system\generate_conanmodules @profiles.list
            }

{ :Project, :Locator }
