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

import Conan from require "ice.tools.conan"
import FastBuild from require "ice.tools.fastbuild"
import FastBuildBuildSystem from require "ice.workspace.buildsystem"

import ProfileList, ConanProfiles from require "ice.workspace.profile"
import ProjectApplication from require "ice.workspace.application"

import Setting, Settings from require "ice.settings"
import Path, File, Dir from require "ice.core.fs"
import Json from require "ice.util.json"
import INIConfig from require "ice.util.iniconfig"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

build_conan_profiles = ->
install_conan_dependencies = ->

project_settings = {
    Setting 'project.script_file', required:true, predicate:File\exists
    Setting 'project.source_dir', required:true, default:'source/code', predicate:Dir\create
    Setting 'project.output_dir', required:true, default:'build', predicate:Dir\create
    Setting 'project.fbuild.config_file', required:true, default:'source/fbuild.bff', predicate:File\exists
    Setting 'project.fbuild.user_includes', default:{ }, predicate:(list) ->
        for file in *(list or { })
            return false unless File\exists file
        return true
    Setting 'project.fbuild.vstudio_solution_file', predicate:(v) -> (type v) == 'string'

    -- Conan related settings
    Setting 'project.conan.profiles', required:false, default:'source/conanprofiles.txt', predicate:File\exists
    Setting 'project.conan.dependencies', required:false, default:'source/conanfile.txt', predicate:File\exists
}

class Project
    @locators: {
        TC_MSVC
        SDK_Win32
        SDK_Linux
        SDK_Cpp_WinRT
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

        Validation\assert @output_directory ~= nil and @output_directory ~= "", "Invalid value for `output` => '#{@output_directory}'"
        Validation\assert @source_directory ~= nil and @source_directory ~= "", "Invalid value for `sources` => '#{@source_directory}'"
        Validation\assert @project_script ~= nil and @project_script ~= "", "Invalid value for `project_script` => '#{@project_script}'"

        Validation\assert @script_location ~= nil and @script_location ~= "", "Invalid value for `fastbuild_script` => '#{@script_location}'"
        Validation\assert (os.isfile @script_location), "Non existing file set in `fastbuild_script` => '#{@script_location}'"

        application = @['application_class'] @raw_settings

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

        -- TODO: Find a better solution to work with conan v2, as with this version we cannot call the same environment file twice
        -- This directly makes problems when using IBT as a 'compiler' in some fastbuild scripts.
        -- For now we generate a conanrunenv version that does not create the deactivate version on call
        -- GitHub: https://github.com/iceshard-engine/ice-build-tools/issues/7
        unless File\exists "build/tools/conanrunenv_mini.bat"
            for file in *Dir\find_files "build/tools", filter: (v) -> v\match "^conanrunenv"
                mini_env = { "@echo off" }

                -- Only keep the lines with the 'set' commands
                with File\open (Path\join "build/tools", file), mode:"rb+"
                    for line in \lines!
                        table.insert mini_env, line if line\match "^set \""
                    \close!

                    -- Save the new file, also required local modification of the .bat file
                    File\save (Path\join "build/tools", "conanrunenv_mini.bat"), (table.concat mini_env, "\n") .. "\n", mode:"wb"

        @build_system\generate!

        -- Execute FBuild to generate conan_profiles.txt
        build_conan_profiles @workspace_root, @output_directory, @
        install_conan_dependencies @profiles.list, false

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
            action: {
                build_conan_profiles: -> build_conan_profiles @workspace_root, @output_directory, @, force:true
                install_conan_dependencies: -> install_conan_dependencies @profiles.list, true
                generate_build_system_files: -> @build_system\generate force:true
            }

build_conan_profiles = (workspace_root, output_directory, out_table, opts = { }) ->
    -- Execute FBuild to generate conan_profiles.txt
    profiles_file = Path\join  workspace_root, output_directory, 'conan_profiles.txt'
    if (not File\exists profiles_file) or opts.force
        FastBuild!\build
            config: Path\join workspace_root, output_directory, 'fbuild.bff'
            target:'conan-profiles'

    Validation\assert (File\exists profiles_file), "The `profiles` file is not valid! No valid profile lists where loaded! => '#{profiles_file}'"
    out_table.profiles = ConanProfiles profiles_file, output_directory

install_conan_dependencies = (profiles, force_update) ->
    file_conan_profiles = Setting\get 'project.conan.profiles'
    file_conan_dependencies = Setting\get 'project.conan.dependencies'
    unless (File\exists file_conan_profiles) and (File\exists file_conan_dependencies)
        Log\info "No description for source dependencies found, skipping..."
        return

    create_resolver = (base_sections) ->
        (template, profile, config) ->
            sections = { }
            for section in *base_sections
                table.insert sections, { base:section, template:section }
                table.insert sections, { base:section, template:"#{section}-#{config}" }
                table.insert sections, { base:section, template:"#{section}-#{profile}" }
                table.insert sections, { base:section, template:"#{section}-#{profile}-#{config}" }

            result = { }
            for section in *sections
                values, meta = template\section section.template
                if values and meta
                    result[section.base] = { } unless result[section.base]

                    if meta.type == 'array'
                        table.insert result[section.base], val for val in *values
                    if meta.type == 'map'
                        result[section.base][key] = value for key, value in pairs values
                elseif not result[section.base]
                    result[section.base] = { }
            result

    conanfile_resolved = create_resolver {
        'requires'
        'tool_requires'
        'options'
        'generators'
    }

    conanprofile_resolved = create_resolver {
        'settings'
        'options'
        'buildenv'
        'conf'
        'buildenv'
        'runenv'
        'tool_requires'
    }

    for profile in *profiles
        location = profile.location
        Dir\create location

        profile_file = Path\join location, 'build_profile.txt'
        hostprofile_file = Path\join location, 'host_profile.txt'
        conanfile_file = Path\join location, 'conanfile.txt'
        conanrun_file = Path\join location, 'conanrun.bat'

        -- Execute conan for the generated profile
        if force_update or not ((File\exists profile_file) and (File\exists conanfile_file) and (File\exists hostprofile_file))
            profiles_template = INIConfig\open file_conan_profiles
            profile_info = conanprofile_resolved profiles_template, profile.profile, profile.config
            Validation\check profile_info, "Missing profile definition for profile: #{profile.name} (#{profile.profile})"
            profile_info.settings.build_type = profile.config

            for section, values in pairs profile_info
                updated_values = {}
                for key, value in pairs values
                    updated_values[key] = value\gsub '$%(([a-zA-Z0-9_]+)%)', (val) ->
                        profile.variables[val] or ''
                profile_info[section] = updated_values

            conanfile_template = INIConfig\open file_conan_dependencies
            conanfile_info = conanfile_resolved conanfile_template, profile.profile, profile.config

            for section, values in pairs conanfile_info
                updated_values = {}
                for key, value in pairs values
                    updated_values[key] = value\gsub '$%(([a-zA-Z0-9_]+)%)', (val) ->
                        profile.variables[val] or ''
                conanfile_info[section] = updated_values

            INIConfig\save profile_file, profile_info or { }
            INIConfig\save hostprofile_file, profile_info or { }
            INIConfig\save conanfile_file, conanfile_info

            Conan!\install
                conanfile:location
                update:false,
                profile:profile_file,
                install_folder:location
                build_policy:'missing'


{ :Project, :Locator }
