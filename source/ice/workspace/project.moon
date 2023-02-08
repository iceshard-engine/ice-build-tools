import Locator from require "ice.locator"

import SDK_Vulkan from require "ice.sdks.vulkan"
import SDK_DX11 from require "ice.sdks.dx11"
import SDK_DX12 from require "ice.sdks.dx12"
import SDK_Win32 from require "ice.sdks.win32"
import SDK_Linux from require "ice.sdks.linux"
import SDK_Cpp_WinRT from require "ice.sdks.winrt_cpp"

import Conan from require "ice.tools.conan"
import FastBuildGenerator from require "ice.generators.fastbuild"
import FastBuildBuildSystem from require "ice.workspace.buildsystem"

import ProfileList, Profile from require "ice.workspace.profile"
import ProjectApplication from require "ice.workspace.application"

import Path, File from require "ice.core.fs"
import Json from require "ice.util.json"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

-- import install_conan_tools, install_conan_source_dependencies from require "ice.workspace.util.conan_install_helpers"
install_conan_dependencies = ->
generate_fastbuild_variables_script = ->
generate_fastbuild_workspace_script = ->

class Project
    new: (@name) =>
        ProjectApplication.name = @name

        @workspace_root = os.cwd!\gsub '\\', '/'
        @ice_build_tools_version = os.getenv 'ICE_BUILT_TOOLS_VER'

        @application_class = ProjectApplication
        @generator_class = FastBuildGenerator

        @conan_profile = 'default'
        @profile_list = ProfileList!

        @solution_name = "#{@name}.sln"
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

    script: (@project_script) =>

    load_settings: (settings_path, settings_file = "settings.json") =>
        @project_settings_file = Path\join settings_path, settings_file
        @project_settings = File\contents @project_settings_file, mode:'r', parser:Json\decode

        -- Override settings with their os overrides
        for key, value in pairs (@project_settings[os.osname] or { })
            @project_settings[key] = value

        @project_script = @project_settings.script_file

    application: (@application_class) =>
    profiles: (profiles_file) =>
        @profile_list = ProfileList\from_file profiles_file

    fastbuild_hooks_script: (@hooks_script_location) =>
    fastbuild_alias_script: (@alias_script_location) =>

    fastbuild_script: (@script_location) =>
    fastbuild_vstudio_solution: (name) =>
        @solution_name = "#{name}.sln"

    add_locator: (locator) =>
        table.insert @locators[locator.type], locator

    sources: (@source_directory) =>
    output: (@output_directory) =>
    working_dir: (@working_directory) =>

    finish: (force_detect) =>
        Validation\assert @output_directory ~= nil and @output_directory ~= "", "Invalid value for `output` => '#{@output_directory}'"
        Validation\assert @source_directory ~= nil and @source_directory ~= "", "Invalid value for `sources` => '#{@source_directory}'"
        Validation\assert @working_directory ~= nil and @working_directory ~= "", "Invalid value for `working_dir` => '#{@working_directory}'"
        Validation\assert @project_script ~= nil and @project_script ~= "", "Invalid value for `project_script` => '#{@project_script}'"

        Validation\assert @script_location ~= nil and @script_location ~= "", "Invalid value for `fastbuild_script` => '#{@script_location}'"
        Validation\assert (os.isfile @script_location), "Non existing file set in `fastbuild_script` => '#{@script_location}'"
        Validation\assert @profile_list\has_profiles!, "The `profiles` file is not valid! No valid profile lists where loaded! => '#{@profile_list}'"

        application = @['application_class'] @project_settings
        selected_profiles = @profile_list\prepare_profiles @output_directory

        @build_system = FastBuildBuildSystem {
            locators:@locators
            profiles:selected_profiles
            workspace_dir:@workspace_root
            output_dir:@output_directory
            source_dir:@source_directory
            -- Files
            files: {
                ibt:@project_script
                solution_name:@solution_name
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
