import MSVC from require 'ice.toolchain.msvc'
import Windows from require 'ice.platform.windows'
import SDKS from require 'ice.sdks.sdks'

import Conan from require 'ice.tools.conan'
import FastBuildGenerator from require 'ice.generators.fastbuild'

import Application from require 'ice.application'
import InstallCommand from require 'ice.commands.install'
import BuildCommand from require 'ice.commands.build'
import VStudioCommand from require 'ice.commands.vstudio'

class ProjectApplication extends Application
    @name: ''
    @description: 'Project command tool.'
    @commands: {
        'build': BuildCommand
        'install': InstallCommand
        'vstudio': VStudioCommand
        -- 'generate': GenerateCommand
    }

    -- Plain call to the application
    execute: (args) =>
        print "#{@@name} - v0.1-alpha"
        print ''
        print '> For more options see the -h,--help output.'


class Project
    new: (@name) =>
        ProjectApplication.name = @name

        @application_class = ProjectApplication
        @generator_class = FastBuildGenerator

        @solution_name = "#{@name}.sln"

    script: (@project_script) =>

    fastbuild_script: (@script_location) =>
    fastbuild_vstudio_solution: (name) =>
        @solution_name = "#{name}.sln"

    sources: (@source_directory) =>
    output: (@output_directory) =>
    working_dir: (@working_directory) =>

    finish: (force_detect) =>
        assert @output_directory ~= nil and @output_directory ~= "", "Invalid value for `output` => '#{@output_directory}'"
        assert @source_directory ~= nil and @source_directory ~= "", "Invalid value for `sources` => '#{@source_directory}'"
        assert @working_directory ~= nil and @working_directory ~= "", "Invalid value for `working_dir` => '#{@working_directory}'"
        assert @project_script ~= nil and @project_script ~= "", "Invalid value for `project_script` => '#{@project_script}'"

        command_result = @application_class!\run!

        @_detect_platform_fastbuild_variables command_result
        @_detect_conan_fastbuild_variables command_result
        @_build_fastbuild_workspace_script command_result

        os.chdir @[command_result.execute_location] or '.', ->
            command_result.execute @ if command_result.execute

    _detect_platform_fastbuild_variables: (args) =>
        toolchains = nil
        toolchains = MSVC\detect '[16.0,17.0)' if os.iswindows

        platform_sdks = nil
        platform_sdks = Windows\detect! if os.iswindows

        additional_sdks = SDKS\detect!

        force_detect = args.force_detect or args.fbuild_detect_variables

        error "No supported toolchain detected!" unless toolchains and #toolchains > 0
        error "No supported toolchain detected!" unless platform_sdks and #platform_sdks > 0

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

        if os.isfile 'tools\\conanfile.txt'
            if args.conan_tools_update or (not os.isfile "build/tools/conaninfo.txt")
                @conan\install conanfile:'tools', update:args.conan_tools_update, install_folder:'build/tools'

        if os.isfile 'source\\conanfile.txt'
            if args.conan_source_update or (not os.isfile "build/conaninfo.txt")
                @conan\install conanfile:'source', update:args.conan_source_update, install_folder:'build'

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
                gen\include "#{fbscripts}/targets_vsproject.bff"
                gen\close!



                -- ; Include the generated compiler definitions
                -- #include "scripts/target_configurations.bff"
                -- #include "scripts/aliases.bff"

                -- ; Workspace properties
                -- .WorkspaceBuildDir = '$WorkspaceRoot$/build'
                -- .WorkspaceCodeDir = '$WorkspaceRoot$/source/code'

                -- .ProjectsResolved = { }
                -- {
                --     .DefaultGroup = 'Unspecified'
                --     #include "code/projects.bff"
                --     #include "scripts/project_definition.bff"
                -- }

                -- #include "scripts/project_targets.bff"
                -- #include "scripts/project_vsprojects.bff"


{ :Project }
