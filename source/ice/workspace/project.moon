import VsMSVC from require 'ice.toolchain.vs_msvc'
import VsClang from require 'ice.toolchain.vs_clang'
import Clang from require 'ice.toolchain.clang'

import Windows from require 'ice.platform.windows'
import Linux from require 'ice.platform.linux'
import SDKS from require 'ice.sdks.sdks'

import Conan from require 'ice.tools.conan'
import FastBuildGenerator from require 'ice.generators.fastbuild'
import ProjectApplication from require 'ice.workspace.application'

class Locator
    @Type: class
        @Toolchain: 'Toolchain'
        @PlatformSDK: 'Platform SDK'
        @CommonSDK: 'Common SDK'

    new: (@type, @name) =>
    locate: => false

class Project
    new: (@name) =>
        ProjectApplication.name = @name

        @ice_build_tools_version = os.getenv 'ICE_BUILT_TOOLS_VER'

        @application_class = ProjectApplication
        @generator_class = FastBuildGenerator

        @solution_name = "#{@name}.sln"
        @locators =
            [Locator.Type.Toolchain]: { }
            [Locator.Type.PlatformSDK]: { }
            [Locator.Type.CommonSDK]: { }

    script: (@project_script) =>
    application: (@application_class) =>

    fastbuild_hooks_script: (@hooks_script_location) =>
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

        @_detect_platform_fastbuild_variables { }
        @_detect_conan_fastbuild_variables { }
        @_build_fastbuild_workspace_script { }

        command_result = @application_class!\run
            source_dir: @source_directory
            output_dir: @output_directory
            fastbuild_solution_name: @solution_name
            generate:
                fbuild_platform_files: -> @_detect_platform_fastbuild_variables fbuild_detect_variables:true
                fbuild_workspace_files: -> @_build_fastbuild_workspace_script fbuild_workspace_script:true
                conan_source_files: -> @_detect_conan_fastbuild_variables conan_source_update:true
                conan_tools_files: -> @_detect_conan_fastbuild_variables conan_tools_update:true

    _detect_platform_fastbuild_variables: (args) =>
        toolchains = { }

        execute_locators = (locator_type, target_array) ->
            for locator in *@locators[locator_type]
                results = locator\locate!
                if (type results) == 'table' and #results > 0
                    table.insert target_array, result for result in *results


        if os.iswindows
            toolchains = { }
            msvc_toolchains = VsMSVC\detect '[16.0,17.0)'
            clang_toolchains = VsClang\detect '[16.0,17.0)'

            table.insert toolchains, toolchain for toolchain in *msvc_toolchains or { }
            table.insert toolchains, toolchain for toolchain in *clang_toolchains or { }

        if os.isunix
            toolchains = { }
            clang_toolchains = Clang\detect!

            table.insert toolchains, toolchain for toolchain in *clang_toolchains or { }

        execute_locators Locator.Type.Toolchain, toolchain_list

        platform_sdks = nil
        platform_sdks = Windows\detect_platform_sdks! if os.iswindows
        platform_sdks = Linux\detect! if os.isunix
        execute_locators Locator.Type.PlatformSDK, platform_sdks

        additional_sdks = SDKS\detect! or { }
        execute_locators Locator.Type.CommonSDK, additional_sdks

        force_detect = args.force_detect or args.fbuild_detect_variables

        error "No supported toolchain detected!" unless toolchains and #toolchains > 0

        if os.iswindows or os.isunix
            error "No supported platforms detected!" unless platform_sdks and #platform_sdks > 0
        else
            platform_sdks = { }

        os.mkdir @output_directory unless os.isdir @output_directory
        os.chdir @output_directory, (dir) ->
            if force_detect or not os.isfile "detected_toolchains.bff"
                gen = @.generator_class "detected_toolchains.bff"

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

            if force_detect or not os.isfile "detected_platforms.bff"
                gen = @.generator_class "detected_platforms.bff"

                sdk_list = { }
                sdk_names = { }

                for sdk in *platform_sdks

                    gen\line!
                    gen\structure sdk.struct_name, (gen) ->
                        gen\variables {
                            { 'SdkIncludeDirs', sdk.includedirs }
                            { 'SdkLibDirs', sdk.libdirs }
                            { 'SdkLibs', sdk.libs }
                        }

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

            if force_detect or not os.isfile "detected_sdks.bff"
                gen = @.generator_class "detected_sdks.bff"

                sdk_list = { }
                sdk_names = { }

                for sdk in *additional_sdks

                    gen\line!
                    gen\structure sdk.struct_name, (gen) ->
                        gen\variables {
                            { 'SdkIncludeDirs', sdk.includedirs }
                            { 'SdkLibDirs', sdk.libdirs }
                            { 'SdkLibs', sdk.libs }
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

    _detect_conan_fastbuild_variables: (args) =>
        @conan = Conan!

        if os.isfile 'tools/conanfile.txt'

            -- We are checking if we need to auto-update at least the ice-build-tools version!
            same_version = true
            for line in io.lines 'tools/conanfile.txt'
                version_match = (line\gmatch "ice%-build%-tools/(%d+.%d+.%d+)")!
                if version_match and version_match ~= ""
                    same_version = version_match == @ice_build_tools_version

            print "Running an different 'ice-built-tools-version' than requested, updating..." if not same_version

            if args.conan_tools_update or (not same_version) or (not os.isfile "build/tools/conaninfo.txt")
                @conan\install
                    conanfile:'tools'
                    update:args.conan_tools_update
                    install_folder:'build/tools'
                    build_policy:'missing'

        if os.isfile 'source/conanfile.txt'
            if args.conan_source_update or (not os.isfile "build/conaninfo.txt")
                @conan\install
                    conanfile:'source'
                    update:args.conan_source_update
                    install_folder:'build'
                    build_policy:'missing'

    _build_fastbuild_workspace_script: (args) =>
        assert (os.isdir @output_directory), "Directory '#{@output_directory}' does not exist!"

        workspace_root = os.cwd!\gsub '\\', '/'

        os.chdir @output_directory, (dir) ->
            if args.fbuild_workspace_script or (not os.isfile "fbuild.bff")
                gen = @.generator_class "fbuild.bff"
                fbscripts = os.getenv 'ICE_FBUILD_SCRIPTS'

                gen\variables {
                    { 'WorkspaceRoot', workspace_root }
                    { 'WorkspaceBuildDir', "#{workspace_root}/#{@output_directory}" }
                    { 'WorkspaceCodeDir', "#{workspace_root}/#{@source_directory}" }
                }
                gen\line!
                gen\include "conan.bff"
                gen\include "detected_toolchains.bff"
                gen\include "detected_platforms.bff"
                gen\include "detected_sdks.bff"

                gen\line!
                gen\line '.SDKList + .PlatformSDKList'
                gen\line '.SDKNames + .PlatformSDKNames'

                gen\line!
                gen\line ".UserSolutionName = '#{@solution_name}'"
                gen\line ".UserScriptFile = '#{@project_script}'"

                gen\line!
                gen\include "#{fbscripts}/base_globals.bff"
                gen\include "#{fbscripts}/base_toolchains.bff"
                gen\include "#{fbscripts}/base_platforms.bff"
                gen\include "#{fbscripts}/base_configurations.bff"

                if os.isfile "#{workspace_root}/#{@hooks_script_location}"
                    gen\line!
                    gen\line '// Hook script, allowing to change PlatformList and ConfigurationList before actual project info gathering.'
                    gen\include "#{workspace_root}/#{@hooks_script_location}"

                gen\line!
                gen\line '.ProjectsResolved = { }'
                gen\line '{'
                gen\line '.Projects = { }'
                gen\include "#{workspace_root}/#{@script_location}"
                gen\include "#{fbscripts}/definition_project.bff"
                gen\line '}'

                gen\line!
                gen\include "#{fbscripts}/definition_configurations.bff"
                gen\include "#{fbscripts}/definition_alias.bff"

                gen\line!
                gen\include "#{fbscripts}/targets_build.bff"
                if os.iswindows
                    gen\include "#{fbscripts}/targets_vsproject.bff"
                gen\close!

{ :Project, :Locator }
