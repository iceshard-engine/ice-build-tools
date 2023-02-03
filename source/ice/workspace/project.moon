import Locator from require "ice.locator"

import VsMSVC from require "ice.toolchain.vs_msvc"
import VsClang from require "ice.toolchain.vs_clang"
import Clang from require "ice.toolchain.clang"
import Gcc from require "ice.toolchain.gcc"

import SDK_Vulkan from require "ice.sdks.vulkan"
import SDK_DX11 from require "ice.sdks.dx11"
import SDK_DX12 from require "ice.sdks.dx12"
import SDK_Win32 from require "ice.sdks.win32"
import SDK_Linux from require "ice.sdks.linux"
import SDK_Cpp_WinRT from require "ice.sdks.winrt_cpp"

import Conan from require "ice.tools.conan"
import FastBuildGenerator from require "ice.generators.fastbuild"

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

        install_conan_dependencies selected_profiles, false
        generate_fastbuild_variables_script selected_profiles, @locators, @output_directory, false
        generate_fastbuild_workspace_script selected_profiles, @output_directory, @source_directory, @, false

        command_result = application\run
            script: @project_script
            workspace_dir: @workspace_root
            source_dir: @source_directory
            output_dir: @output_directory
            fastbuild_solution_name: @solution_name
            action: {
                install_conan_dependencies: -> install_conan_dependencies selected_profiles, true
                generate_fastbuild_variables_script: -> generate_fastbuild_variables_script selected_profiles, @locators, @output_directory, true
                generate_fastbuild_workspace_script: -> generate_fastbuild_workspace_script selected_profiles, @output_directory, @source_directory, @, true
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


generate_fastbuild_variables_script = (profiles, locators, output_dir, force_update) ->
    log_file = 'build/compiler_detection.log'
    File\delete log_file

    execute_locators = (locator_type, detected_info) ->
        for locator in *locators[locator_type]
            results = locator\locate_internal detected_info

    detected_info = {
        toolchains: { }
        platform_sdks: { }
        additional_sdks: { }
    }

    -- Go over all profiles we have defined and look for their toolchains
    for profile in *profiles
        if os.iswindows
            compiler_version = tonumber profile.compiler.version
            toolchain_version = "[#{compiler_version}.0,#{compiler_version+1}.0)"

            msvc_toolchains = VsMSVC\detect toolchain_version
            clang_toolchains = VsClang\detect toolchain_version

            table.insert detected_info.toolchains, toolchain for toolchain in *msvc_toolchains or { }
            table.insert detected_info.toolchains, toolchain for toolchain in *clang_toolchains or { }

        if os.isunix
            clang_toolchains = Clang\detect profile, log_file
            gcc_toolchains = Gcc\detect profile, log_file

            table.insert detected_info.toolchains, toolchain for toolchain in *clang_toolchains or { }
            table.insert detected_info.toolchains, toolchain for toolchain in *gcc_toolchains or { }

    -- execute_locators Locator.Type.Toolchain, toolchains -- Currently unused
    execute_locators Locator.Type.PlatformSDK, detected_info
    execute_locators Locator.Type.CommonSDK, detected_info

    -- Extract variables
    { :toolchains, :platform_sdks, :additional_sdks } = detected_info

    error "No supported toolchain detected!" unless toolchains and #toolchains > 0
    if os.iswindows or os.isunix
        error "No supported platforms detected!" unless platform_sdks and #platform_sdks > 0

    os.mkdir output_dir unless os.isdir output_dir
    os.chdir output_dir, (dir) ->
        if force_update or not (os.isfile "detected_toolchains.bff")
            gen = FastBuildGenerator "detected_toolchains.bff"

            toolchain_list = { }
            toolchain_names = { }

            toolchain_generated = {}
            for toolchain in *toolchains
                continue if toolchain_generated[toolchain.name]
                toolchain_generated[toolchain.name] = true

                toolchain.generate gen

                table.insert toolchain_names, toolchain.name
                table.insert toolchain_list, toolchain.struct_name
                gen\line!

            gen\line '.ToolchainList = {'
            gen\indented (gen) ->
                gen\line ".#{value}" for value in *toolchain_list
            gen\line '}'

            gen\line '.ToolchainNames = {'
            gen\indented (gen) ->
                gen\line "'#{value}'" for value in *toolchain_names
            gen\line '}\n'

            gen\close!

        if force_update or not (os.isfile "detected_platforms.bff")
            gen = FastBuildGenerator "detected_platforms.bff"

            sdk_list = { }
            sdk_names = { }

            for sdk in *platform_sdks

                gen\line!
                gen\structure sdk.struct_name, (gen) ->
                    gen\variables {
                        { 'Tags', sdk.tags or { } }
                        { 'IncludeDirs', sdk.includedirs }
                        { 'LibDirs', sdk.libdirs }
                        { 'Libs', sdk.libs }
                    }

                    unless not sdk.compilers
                        gen\line!
                        for compiler in *(sdk.compilers or { })
                            gen\compiler compiler

                    tool_names = { }
                    unless not sdk.tools
                        gen\line!
                        for tool in *(sdk.tools or { })
                            gen\line ".#{tool.name} = '#{tool.path}'"
                            table.insert tool_names, tool.name

                    gen\line!
                    gen\variables { { 'SDKToolNames', tool_names } }

                table.insert sdk_names, sdk.name
                table.insert sdk_list, sdk.struct_name

            gen\line!
            gen\line '.PlatformSDKList = {'
            gen\indented (gen) ->
                gen\line ".#{value}" for value in *sdk_list
            gen\line '}'

            gen\line '.PlatformSDKNames = {'
            gen\indented (gen) ->
                gen\line "'#{value}'" for value in *sdk_names
            gen\line '}'

            gen\close!

        if force_update or (not os.isfile "detected_sdks.bff")
            gen = FastBuildGenerator "detected_sdks.bff"

            sdk_list = { }
            sdk_names = { }

            for sdk in *additional_sdks

                gen\line!
                gen\structure sdk.struct_name, (gen) ->
                    gen\variables {
                        { 'IncludeDirs', sdk.includedirs }
                        { 'LibDirs', sdk.libdirs }
                        { 'Libs', sdk.libs }
                    }

                table.insert sdk_names, sdk.name
                table.insert sdk_list, sdk.struct_name

            gen\line!
            gen\line '.SDKList = {'
            gen\indented (gen) ->
                gen\line ".#{value}" for value in *sdk_list
            gen\line '}'

            gen\line '.SDKNames = {'
            gen\indented (gen) ->
                gen\line "'#{value}'" for value in *sdk_names
            gen\line '}'

            gen\close!

generate_fastbuild_workspace_script = (profiles, output, source, project, force_update) ->
    assert (os.isdir output), "Directory '#{output}' does not exist!"

    os.chdir output, (dir) ->
        if force_update or (not os.isfile "fbuild.bff")
            gen = FastBuildGenerator "fbuild.bff"
            fbscripts = os.getenv 'ICE_FBUILD_SCRIPTS'

            workspace_root = project.workspace_root

            gen\variables {
                { 'WorkspaceRoot', workspace_root }
                { 'WorkspaceBuildDir', "#{workspace_root}/#{output}" }
                { 'WorkspaceCodeDir', "#{workspace_root}/#{source}" }
            }
            gen\line!

            gen\line '.ConanBuildTypes = {'
            gen\indented (gen) ->
                gen\line "'#{profile.id}'" for profile in *profiles
            gen\line '}'

            for profile in *profiles
                gen\line!
                gen\line ".ConanModules_#{profile.id} = [ ]"
                gen\line '{'
                gen\indented (gen) ->
                    gen\include "#{workspace_root}/#{profile\get_location!}/conan.bff"
                    gen\line "^ConanModules_#{profile.id} = .ConanModules"
                gen\line '}'
            gen\line!

            gen\include "detected_toolchains.bff"
            gen\include "detected_platforms.bff"
            gen\include "detected_sdks.bff"

            gen\line!
            gen\line '.SDKList + .PlatformSDKList'
            gen\line '.SDKNames + .PlatformSDKNames'

            gen\line!
            gen\line ".UserSolutionName = '#{project.solution_name}'"
            gen\line ".UserScriptFile = '#{project.project_script}'"

            gen\line!
            gen\include "#{fbscripts}/base_globals.bff"
            gen\include "#{fbscripts}/base_compilers.bff"
            gen\include "#{fbscripts}/base_platforms.bff"
            gen\include "#{fbscripts}/base_configurations.bff"
            gen\include "#{fbscripts}/base_pipelines.bff"

            if os.isfile "#{workspace_root}/#{project.hooks_script_location}"
                gen\line!
                gen\line '// Hook script, allowing to change PlatformList and ConfigurationList before actual project info gathering.'
                gen\include "#{workspace_root}/#{project.hooks_script_location}"

            gen\line!
            gen\line '.ProjectsResolved = { }'
            gen\line '{'
            gen\line '.Projects = { }'
            gen\include "#{workspace_root}/#{project.script_location}"
            gen\include "#{fbscripts}/definition_project.bff"
            gen\line '}'

            gen\line!
            gen\include "#{fbscripts}/definition_configurations.bff"
            gen\include "#{fbscripts}/definition_alias.bff"

            if os.isfile "#{workspace_root}/#{project.alias_script_location}"
                gen\line!
                gen\line '// Alias script, allowing to change alias definitions before target creation.'
                gen\include "#{workspace_root}/#{project.alias_script_location}"

            gen\line!
            gen\include "#{fbscripts}/targets_build.bff"
            gen\include "#{fbscripts}/targets_devenv.bff"
            gen\include "#{fbscripts}/targets_vsproject.bff" if os.iswindows
            gen\close!

{ :Project, :Locator }
