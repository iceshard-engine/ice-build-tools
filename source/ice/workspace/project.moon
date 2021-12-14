import Locator from require 'ice.locator'

import VsMSVC from require 'ice.toolchain.vs_msvc'
import VsClang from require 'ice.toolchain.vs_clang'
import Clang from require 'ice.toolchain.clang'
import Gcc from require 'ice.toolchain.gcc'

import SDK_Vulkan from require 'ice.sdks.vulkan'
import SDK_DX11 from require 'ice.sdks.dx11'
import SDK_DX12 from require 'ice.sdks.dx12'
import SDK_Win32 from require 'ice.sdks.win32'
import SDK_Linux from require 'ice.sdks.linux'
import SDK_Cpp_WinRT from require 'ice.sdks.winrt_cpp'

import Conan from require 'ice.tools.conan'
import FastBuildGenerator from require 'ice.generators.fastbuild'

import ProfileList, Profile from require 'ice.workspace.profile'
import ProjectApplication from require 'ice.workspace.application'

-- import install_conan_tools, install_conan_source_dependencies from require 'ice.workspace.util.conan_install_helpers'
install_conan_dependencies = ->
generate_fastbuild_variables_script = ->
generate_fastbuild_workspace_script = ->

class Project
    new: (@name) =>
        ProjectApplication.name = @name

        @ice_build_tools_version = os.getenv 'ICE_BUILT_TOOLS_VER'

        @application_class = ProjectApplication
        @generator_class = FastBuildGenerator

        @conan_profile = 'default'
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
        assert @output_directory ~= nil and @output_directory ~= "", "Invalid value for `output` => '#{@output_directory}'"
        assert @source_directory ~= nil and @source_directory ~= "", "Invalid value for `sources` => '#{@source_directory}'"
        assert @working_directory ~= nil and @working_directory ~= "", "Invalid value for `working_dir` => '#{@working_directory}'"
        assert @project_script ~= nil and @project_script ~= "", "Invalid value for `project_script` => '#{@project_script}'"

        application = @application_class!

        selected_profile = @profile_list\prepare_profile @output_directory

        install_conan_dependencies selected_profile, false
        generate_fastbuild_variables_script selected_profile, @locators, @output_directory, false
        generate_fastbuild_workspace_script selected_profile, @output_directory, @source_directory, @, false

        command_result = application\run
            source_dir: @source_directory
            output_dir: @output_directory
            conan_profile: @conan_profile
            fastbuild_solution_name: @solution_name
            action: {
                install_conan_dependencies: -> install_conan_dependencies selected_profile, true
                generate_fastbuild_variables_script: -> generate_fastbuild_variables_script selected_profile, @locators, @output_directory, true
                generate_fastbuild_workspace_script: -> generate_fastbuild_workspace_script selected_profile, @output_directory, @source_directory, @, true
            }


install_conan_dependencies = (profile, force_update) ->
    unless os.isfile 'source/conanfile.txt'
        print "No description for source dependencies found, skipping..." if not same_version
        return

    profile_paths = profile\generate_conan_profiles!

    for profile_path in *profile_paths
        profile_file = "#{profile_path}/conan_profile.txt"
        info_file = "#{profile_path}/conaninfo.txt"

        unless os.isfile profile_file
            error "Generated Conan profile file 'conan_profile.txt' was not found in path #{profile_path}"

        if force_update or not (os.isfile info_file)
            Conan!\install
                conanfile:'source'
                update:false,
                profile:profile_file,
                install_folder:profile_path
                build_policy:'missing'

generate_fastbuild_variables_script = (profile, locators, output_dir, force_update) ->

    execute_locators = (locator_type, detected_info) ->
        for locator in *locators[locator_type]
            results = locator\locate_internal detected_info

    detected_info = {
        toolchains: { }
        platform_sdks: { }
        additional_sdks: { }
    }

    if os.iswindows
        compiler_version = tonumber profile.compiler.version
        toolchain_version = "[#{compiler_version}.0,#{compiler_version+1}.0)"

        msvc_toolchains = VsMSVC\detect toolchain_version
        clang_toolchains = VsClang\detect toolchain_version

        table.insert detected_info.toolchains, toolchain for toolchain in *msvc_toolchains or { }
        table.insert detected_info.toolchains, toolchain for toolchain in *clang_toolchains or { }

    if os.isunix
        -- #TODO (#6): https://github.com/iceshard-engine/ice-build-tools/issues/6
        -- clang_toolchains = Clang\detect profile
        clang_toolchains = Gcc\detect profile

        table.insert detected_info.toolchains, toolchain for toolchain in *clang_toolchains or { }


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

            for toolchain in *toolchains
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

                    unless not sdk.tools
                        gen\line!
                        for tool in *(sdk.tools or { })
                            gen\compiler tool

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

generate_fastbuild_workspace_script = (profile, output, source, project, force_update) ->
    assert (os.isdir output), "Directory '#{output}' does not exist!"

    workspace_root = os.cwd!\gsub '\\', '/'

    os.chdir output, (dir) ->
        if force_update or (not os.isfile "fbuild.bff")
            gen = FastBuildGenerator "fbuild.bff"
            fbscripts = os.getenv 'ICE_FBUILD_SCRIPTS'

            gen\variables {
                { 'WorkspaceRoot', workspace_root }
                { 'WorkspaceBuildDir', "#{workspace_root}/#{output}" }
                { 'WorkspaceCodeDir', "#{workspace_root}/#{source}" }
            }
            gen\line!

            gen\line '.ConanBuildTypes = {'
            gen\indented (gen) ->
                gen\line "'#{build_type}'" for { build_type, _ } in *profile\get_profile_pairs!
            gen\line '}'

            for { build_type, profile_path } in *profile\get_profile_pairs!
                gen\line!
                gen\line ".ConanModules_#{build_type} = [ ]"
                gen\line '{'
                gen\indented (gen) ->
                    gen\include "#{profile_path}/conan.bff"
                    gen\line "^ConanModules_#{build_type} = .ConanModules"
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
            if os.iswindows
                gen\include "#{fbscripts}/targets_vsproject.bff"
            gen\close!

{ :Project, :Locator }
