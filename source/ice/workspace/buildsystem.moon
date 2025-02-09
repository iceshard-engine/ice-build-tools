
import IBT from require "ibt.ibt"

import Path, Dir, File from require "ice.core.fs"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"
import FastBuildGenerator from require "ice.generators.fastbuild"

import Locator from require "ice.locator"
import VsClang from require "ice.toolchain.vs_clang"
import Clang from require "ice.toolchain.clang"
import Gcc from require "ice.toolchain.gcc"

class BuildSystem
    new: (info) =>
        Validation\assert info.locators, "BuildSystem requires a list of locators to properly generate necessary files"
        -- Validation\assert info.profiles and #info.profiles > 0, "BuildSystem requires a list of profiles to properly generate necessary files"
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
                Log\verbose "Executing '#{locator.name}' locator ..."
                results = locator\locate_internal detected_info

        detected_info = {
            toolchains: { }
            platform_sdks: { }
            additional_sdks: { }
        }

        Log\info "Executing toolchain locators..."
        execute_locators Locator.Type.Toolchain, detected_info
        Log\info "Executing platform SDK locators..."
        execute_locators Locator.Type.PlatformSDK, detected_info
        Log\info "Executing 3rd-party SDK locators..."
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
            res = ((File\exists toolchains_file) and (File\exists platforms_file) and (File\exists sdks_file) and (File\exists main_file)) == false
            res = true if args.force
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
        Validation\assert toolchains != nil and #toolchains > 0, "No compatible toolchains found!"

        for toolchain in *toolchains
            continue if toolchain_generated[toolchain.name]
            toolchain_generated[toolchain.name] = true

            Log\info "Generating toolchain info for '#{toolchain.name}'..."
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
            { 'Binaries', sdk.binaries or '' }
            { 'Defines', sdk.defines or { } }
            { 'IncludeDirs', sdk.includedirs }
            { 'LibDirs', sdk.libdirs }
            { 'Libs', sdk.libs }
            { 'RuntimeLibs', sdk.runtime_libs or { } }
        }

        if sdk.runtime_libs and sdk.binaries
            gen\line!
            gen\structure 'RuntimeLibsPaths', (gen) ->
                lib_paths = { }
                for lib in *sdk.runtime_libs
                    table.insert lib_paths, Path\normalize Path\join sdk.binaries, "#{lib}"
                gen\variables {
                    { "KnownLibs", sdk.runtime_libs },
                    { "KnownLibsPath", lib_paths }
                }

        if sdk.supported_platforms
            gen\line!
            gen\variables { { 'SDKSupportedPlatforms', sdk.supported_platforms } }

        if sdk.compilers
            gen\line!
            for compiler in *(sdk.compilers or { })
                gen\compiler compiler

        if sdk.flavours and #sdk.flavours > 0
            sdk_flavours = { }

            for rule in *sdk.flavours
                continue unless rule.variables
                table.insert sdk_flavours, ".#{rule.struct_name}"

                gen\line!
                gen\structure rule.struct_name, (gen) ->
                    gen\variables {
                        { 'Name', rule.name }
                        { 'Requires', rule.requires or {} }
                    }
                    gen\variables rule.variables or { }

                    -- Used to deploy additional files for specific platform flavours
                    if rule.runtime
                        gen\structure "DependsOn", (gen) ->
                            gen\variables { { 'RuntimeExternal', rule.runtime } }

            gen\line!
            gen\variables { { 'Flavours', sdk_flavours } }

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

    generate_conanmodules: (profiles) =>
        conanmodules_file = Path.Unix\join @workspace_dir, @output_dir, "fbuild_conanmodules.bff"
        conanmodules_gen = FastBuildGenerator conanmodules_file
        gen = conanmodules_gen

        for profile in *(profiles or {})
            gen\line ".ConanProfiles + '#{profile.name}'"
            gen\line '{'
            gen\indented (gen) ->
                gen\line ".ConanModules = [ ]"
                conandeps_file = Path.Unix\join @workspace_dir, profile.location, 'conandeps.bff'
                gen\line "#if file_exists(\"#{conandeps_file}\")"
                gen\include conandeps_file
                gen\line "#endif"
                gen\line '^ConanProfilesModules + .ConanModules'
            gen\line '}'

        conanmodules_gen\close!

    generate_main: (generated, gen) =>
        gen\variables {
            { 'WorkspaceRoot', @workspace_dir }
            { 'WorkspaceBuildDir', Path.Unix\join @workspace_dir, @output_dir }
            { 'WorkspaceSourceDir', Path.Unix\join @workspace_dir, @source_dir }
            { 'WorkspaceCodeDir', Path.Unix\join @workspace_dir, @source_dir }
            { 'WorkspaceMainScript', Path.Unix\join @workspace_dir, @files.fbuild_workspace_file }
        }
        gen\line!

        gen\line '.ConanBuildTypes = {'
        gen\indented (gen) ->
            gen\line "'#{profile.id}'" for profile in *@profiles
        gen\line '}'

        gen\line!
        gen\line ".ConanProfiles = { }"
        gen\line ".ConanProfilesModules = { }"
        conanmodules_file = Path.Unix\join @workspace_dir, @output_dir, "fbuild_conanmodules.bff"
        gen\line "#if file_exists(\"#{conanmodules_file}\")"
        gen\include conanmodules_file
        gen\line "#endif"
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
        gen\include Path.Unix\join fbscripts, "targets_utility_conan.bff"
        gen\include Path.Unix\join fbscripts, "targets_utility_android.bff"
        gen\include Path.Unix\join fbscripts, "targets_utility_devenv.bff"
        gen\include Path.Unix\join fbscripts, "targets_utility_vsproject.bff" if os.iswindows and @files.solution_name
        gen\close!

    generate_conaninfo: (profiles) =>
        for profile in *profiles
            gen\line!
            gen\line ".ConanModules_#{profile.id} = [ ]"
            gen\line '{'
            gen\indented (gen) ->
                gen\include Path.Unix\join @workspace_dir, "#{profile\get_location!}/conandeps.bff"
                gen\line "^ConanModules_#{profile.id} = .ConanModules"
            gen\line '}'


{ :FastBuildBuildSystem }
