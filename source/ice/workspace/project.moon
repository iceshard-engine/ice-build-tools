import Locator from require "ice.locator"

import SDK_Vulkan from require "ice.sdks.vulkan"
import SDK_DX11 from require "ice.sdks.dx11"
import SDK_DX12 from require "ice.sdks.dx12"
import SDK_Win32 from require "ice.sdks.win32"
import SDK_Linux from require "ice.sdks.linux"
import SDK_Cpp_WinRT from require "ice.sdks.winrt_cpp"

import Conan from require "ice.tools.conan"
import FastBuildBuildSystem from require "ice.workspace.buildsystem"

import ProfileList from require "ice.workspace.profile"
import ProjectApplication from require "ice.workspace.application"

import Setting, Settings from require "ice.settings"
import Path, File, Dir from require "ice.core.fs"
import Json from require "ice.util.json"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

install_conan_dependencies = ->

project_settings = {
    Setting 'project.script_file', required:true, predicate:File\exists
    Setting 'project.source_dir', required:true, default:'source/code', predicate:Dir\create
    Setting 'project.output_dir', required:true, default:'build', predicate:Dir\create
    Setting 'project.conan.profiles_file', required:true, default:'source/conan_profiles.json', predicate:File\exists
    Setting 'project.fbuild.config_file', required:true, default:'source/fbuild.bff', predicate:File\exists
    Setting 'project.fbuild.user_includes', default:{ }, predicate:(list) ->
        for file in *(list or { })
            return false unless File\exists file
        return true
    Setting 'project.fbuild.vstudio_solution_file', predicate:(v) -> (type v) == 'string'
}

class Project
    new: (@name) =>
        ProjectApplication.name = @name

        @workspace_root = os.cwd!\gsub '\\', '/'
        @application_class = ProjectApplication

        @locators =
            [Locator.Type.Toolchain]: { }
            [Locator.Type.PlatformSDK]: { }
            [Locator.Type.CommonSDK]: { }

        -- Initialize with default locators
        @add_locator SDK_Win32!
        @add_locator SDK_Linux!
        @add_locator SDK_Cpp_WinRT!
        @add_locator SDK_DX11!
        @add_locator SDK_DX12!
        @add_locator SDK_Vulkan!

        @_load_settings 'tools/settings.json'

    _load_settings: (@project_settings_file) =>
        Validation\assert File\exists @project_settings_file, "Settings file does not exist: #{@project_settings_file}"

        @raw_settings = File\load @project_settings_file, mode:'r', parser:Json\decode

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
    add_locator: (locator) => table.insert @locators[locator.type], locator

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
        @profile_list = ProfileList\from_file @settings.project.conan.profiles_file

        @project_script = Setting\get 'project.script_file'
        @output_directory = Setting\get 'project.output_dir'
        @source_directory = Setting\get 'project.source_dir'
        @script_location = Setting\get 'project.fbuild.config_file'

        Validation\assert @output_directory ~= nil and @output_directory ~= "", "Invalid value for `output` => '#{@output_directory}'"
        Validation\assert @source_directory ~= nil and @source_directory ~= "", "Invalid value for `sources` => '#{@source_directory}'"
        Validation\assert @project_script ~= nil and @project_script ~= "", "Invalid value for `project_script` => '#{@project_script}'"

        Validation\assert @script_location ~= nil and @script_location ~= "", "Invalid value for `fastbuild_script` => '#{@script_location}'"
        Validation\assert (os.isfile @script_location), "Non existing file set in `fastbuild_script` => '#{@script_location}'"
        Validation\assert @profile_list\has_profiles!, "The `profiles` file is not valid! No valid profile lists where loaded! => '#{@profile_list}'"

        application = @['application_class'] @raw_settings
        selected_profiles = @profile_list\prepare_profiles @output_directory

        @build_system = FastBuildBuildSystem {
            locators:@locators
            profiles:selected_profiles
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

        install_conan_dependencies selected_profiles, false
        @build_system\generate!

        command_result = application\run
            script: @project_script
            workspace_dir: @workspace_root
            source_dir: @source_directory
            output_dir: @output_directory
            fastbuild_solution_name: @solution_name
            settings_file:@project_settings_file
            action: {
                install_conan_dependencies: -> install_conan_dependencies selected_profiles, true
                generate_build_system_files: -> @build_system\generate force:true
            }


install_conan_dependencies = (profiles, force_update) ->
    unless File\exists 'source/conanfile.txt'
        Log\info "No description for source dependencies found, skipping..." if not same_version
        return

    for profile in *profiles
        profile_location = profile\get_location!
        profile_file = profile\get_file!
        info_file = Path\join profile_location, "conaninfo.txt"

        -- Generate the profile file
        profile\generate!

        -- Execute conan for the generated profile
        if force_update or not (os.isfile info_file)
            Conan!\install
                conanfile:'source'
                update:false,
                profile:profile_file,
                install_folder:profile_location
                build_policy:'missing'

        -- Check for the new generated file
        unless os.isfile profile_file
            error "Generated Conan profile file 'conan_profile.txt' was not found in path #{profile_location}"


{ :Project, :Locator }
