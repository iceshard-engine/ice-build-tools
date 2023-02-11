
import IBT from require "ibt.ibt"

import Path, Dir, File from require "ice.core.fs"
import Validation from require "ice.core.validation"
import FastBuildGenerator from require "ice.generators.fastbuild"

import Locator from require "ice.locator"
import VsMSVC from require "ice.toolchain.vs_msvc"
import VsClang from require "ice.toolchain.vs_clang"
import Clang from require "ice.toolchain.clang"
import Gcc from require "ice.toolchain.gcc"

class BuildSystem
    new: (info) =>
        Validation\assert info.locators, "BuildSystem requires a list of locators to properly generate necessary files"
        Validation\assert info.profiles and #info.profiles > 0, "BuildSystem requires a list of profiles to properly generate necessary files"
        Validation\assert (Dir\exists info.workspace_dir), "BuildSystem requires a valid workspace directory. '#{info.workspace_dir}' does not exist"
        Validation\assert (Dir\exists info.output_dir), "BuildSystem requires a valid output directory. '#{info.output_dir}' does not exist"
        Validation\assert (Dir\exists info.source_dir), "BuildSystem requires a valid source directoru. '#{info.source_dir}' does not exist"

        -- TODO: Validate 'files' value

        @locators = info.locators
        @profiles = info.profiles
        @workspace_dir = info.workspace_dir
        @output_dir = info.output_dir
        @source_dir = info.source_dir
        @files = info.files

    workspace_info: =>
        execute_locators = (locator_type, detected_info) ->
            for locator in *@locators[locator_type]
                results = locator\locate_internal detected_info

        detected_info = {
            toolchains: { }
            platform_sdks: { }
            additional_sdks: { }
        }

        -- Go over all profiles we have defined and look for their toolchains
        for profile in *@profiles
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

        -- Re-Enable after we make sure that the test package is able to test properly
        -- Validation\assert toolchains and #toolchains > 0, "No supported toolchain detected!" unless
        -- Validation\assert platform_sdks and #platform_sdks > 0, "No supported platforms detected!" unless

        detected_info


class FastBuildBuildSystem extends BuildSystem
    new: (info) =>
        super info
        @user_includes = info.user_includes or { }

    generate: (args = { }) =>
        toolchains_file = Path\join @output_dir, 'fbuild_toolchains.bff'
        platforms_file = Path\join @output_dir, 'fbuild_platforms.bff'
        sdks_file = Path\join @output_dir, 'fbuild_sdks.bff'
        main_file = Path\join @output_dir, 'fbuild.bff'

        is_dirty = do
            res = true if args.force
            res = ((File\exists toolchains_file) and (File\exists platforms_file) and (File\exists sdks_file) and (File\exists main_file)) == false
            res
        return unless is_dirty

        outputs = {
            toolchains: FastBuildGenerator toolchains_file
            platforms: FastBuildGenerator platforms_file
            sdks: FastBuildGenerator sdks_file
        }

        { :toolchains, :platform_sdks, :additional_sdks } = @workspace_info!

        @generate_toolchains toolchains, outputs.toolchains
        @generate_platform_sdks platform_sdks, outputs.platforms
        @generate_additional_sdks additional_sdks, outputs.sdks
        @generate_main { name, gen.output for name, gen in pairs outputs }, FastBuildGenerator main_file

    generate_toolchains: (toolchains, gen) =>
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

    generate_sdk_entry = (sdk) -> (gen) ->
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

    generate_platform_sdks: (platforms, gen) =>
        sdk_list = { }
        sdk_names = { }

        for sdk in *platforms

            gen\line!
            gen\structure sdk.struct_name, generate_sdk_entry sdk

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

    generate_additional_sdks: (sdks, gen) =>
        sdk_list = { }
        sdk_names = { }

        for sdk in *sdks
            gen\line!
            gen\structure sdk.struct_name, generate_sdk_entry sdk

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

    generate_main: (generated, gen) =>
        gen\variables {
            { 'WorkspaceRoot', @workspace_dir }
            { 'WorkspaceBuildDir', Path.Unix\join @workspace_dir, @output_dir }
            { 'WorkspaceSourceDir', Path.Unix\join @workspace_dir, @source_dir }
            { 'WorkspaceCodeDir', Path.Unix\join @workspace_dir, @source_dir }
        }
        gen\line!

        gen\line '.ConanBuildTypes = {'
        gen\indented (gen) ->
            gen\line "'#{profile.id}'" for profile in *@profiles
        gen\line '}'

        gen\line!
        gen\line ".ConanModules_UNUSED = [ ]"
        for profile in *@profiles
            gen\line!
            gen\line ".ConanModules_#{profile.id} = [ ]"
            gen\line '{'
            gen\indented (gen) ->
                gen\include Path.Unix\join @workspace_dir, "#{profile\get_location!}/conan.bff"
                gen\line "^ConanModules_#{profile.id} = .ConanModules"
            gen\line '}'
        gen\line!

        gen\include Path.Unix\join @workspace_dir, generated.toolchains
        gen\include Path.Unix\join @workspace_dir, generated.platforms
        gen\include Path.Unix\join @workspace_dir, generated.sdks

        gen\line!
        gen\line ".UserSolutionName = '#{@files.solution_name}'" if @files.solution_name
        gen\line ".UserScriptFile = '#{@files.ibt}'"

        fbscripts = IBT.fbuild_scripts

        gen\line!
        gen\include Path.Unix\join fbscripts, "base_globals.bff"
        gen\include Path.Unix\join fbscripts, "base_compilers.bff"
        gen\include Path.Unix\join fbscripts, "base_platforms.bff"
        gen\include Path.Unix\join fbscripts, "base_configurations.bff"
        gen\include Path.Unix\join fbscripts, "base_pipelines.bff"

        gen\line!
        gen\line "// Project specific include files"
        gen\include Path.Unix\join @workspace_dir, include_path for include_path in *@user_includes

        -- if os.isfile "#{@workspace_dir}/#{project.hooks_script_location}"
        --     gen\line!
        --     gen\line '// Hook script, allowing to change PlatformList and ConfigurationList before actual project info gathering.'
        --     gen\include "#{@workspace_dir}/#{project.hooks_script_location}"

        gen\line!
        gen\line '.ProjectsResolved = { }'
        gen\line '{'
        gen\line '.Projects = { }'
        gen\include Path.Unix\join @workspace_dir, @files.fbuild_workspace_file
        gen\include Path.Unix\join fbscripts, "definition_project.bff"
        gen\line '}'

        gen\line!
        gen\include Path.Unix\join fbscripts, "definition_configurations.bff"
        gen\include Path.Unix\join fbscripts, "definition_alias.bff"

        -- if os.isfile "#{@workspace_dir}/#{project.alias_script_location}"
        --     gen\line!
        --     gen\line '// Alias script, allowing to change alias definitions before target creation.'
        --     gen\include "#{@workspace_dir}/#{project.alias_script_location}"

        gen\line!
        gen\include Path.Unix\join fbscripts, "targets_build.bff"
        gen\include Path.Unix\join fbscripts, "targets_devenv.bff"
        gen\include Path.Unix\join fbscripts, "targets_vsproject.bff" if os.iswindows and @files.solution_name
        gen\close!

{ :FastBuildBuildSystem }
