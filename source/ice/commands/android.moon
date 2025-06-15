import Command, group, argument, option, flag from require "ice.command"
import Exec, Where from require "ice.tools.exec"
import FastBuild from require "ice.tools.fastbuild"
import Path, Dir, File from require "ice.core.fs"
import Validation from require "ice.core.validation"
import Setting from require "ice.settings"
import Log from require "ice.core.logger"
import Android from require "ice.platform.android"

import INIConfig from require "ice.util.iniconfig"
import Json from require "ice.util.json"

loc_workspace_build_template = Path\join (os.getenv 'IBT_DATA'), 'project_build.gradle.template.kts'
loc_workspace_settings_template = Path\join (os.getenv 'IBT_DATA'), 'project_settings.gradle.template.kts'
loc_project_build_template = Path\join (os.getenv 'IBT_DATA'), 'module_build.gradle.template.kts'

class AndroidCommand extends Command
    @settings {
        Setting 'android.projects', default:{}
        Setting 'android.gradle.build_template',
            default:loc_workspace_build_template
            predicate:(v) -> v == nil or File\exists v
        Setting 'android.gradle.settings_template',
            default:loc_workspace_settings_template
            predicate:(v) -> v == nil or File\exists v
        Setting 'android.gradle.wrapper', default:'build/android_gradlew'
        Setting 'android.gradle.abi_pipeline_mapping', default:{'x86_64':'x64', 'arm64-v8a':'ARMv8'}
    }

    @arguments {
        group 'general', description: "Basic options"
        argument 'mode',
            group: 'general'
            description: 'Selects the mode in which the command operates.'
            name: 'mode'
            choices: { 'build', 'setup', 'sdk', 'configure' }
            default: 'build'
        group 'build', description: "Build options"
        option 'target',
            group: 'build'
            description: 'The target task to be executed by the gradle wrapper.'
            name: '-t --target'
            default: 'assemble'
            argname: '<gradle_task>'
        flag 'rerunn_tasks',
            group: 'build'
            description: 'Re-runs all dependent tasks for the given target task.'
            name: '--rerun-tasks'
        group 'setup', description: "Setup options"
        option 'copy_templates',
            group: 'setup'
            description: 'Copies the template files stored in the package to the provided location. Skips files that arleady exist.'
            name: '--copy-templates'
            argname:'<path>'
        flag 'install_gradle',
            group: 'setup'
            description: 'Downloads the gradle binary into the build directory to be used for Android projects. (Local installation)'
            name: '--install-gradle'
        group 'sdk', description: "SDK management options"
        option 'list_sdks',
            group: 'sdk'
            name: '-l --list'
            description: 'Lists currently installed SDK packages.'
            choices: { 'all', 'outdated' }
            default: 'all'
            defmode: 'arg'
        option 'update_sdks',
            group: 'sdk'
            description: 'Updates the selected SDKs. Multiple entries can be provided. Use the SDK \'id\' for the value.'
            name: '-u --update'
            count: '*'

        -- Work In Progress
        group 'configure', description: "Configuration options"
        option 'name',
            group: 'configure',
            name: '--name'
        option 'builddb',
            group: 'configure',
            name: '--db'
        option 'config',
            group: 'configure'
            name: '--config'
        option 'abi',
            group: 'configure'
            name: '--abi'
        option 'pipeline',
            group: 'configure'
            name: '--pipeline'
        option 'ndkver',
            group: 'configure'
            name: '--ndk-version'
        option 'out',
            group: 'configure'
            name: '--out'
    }

    prepare: (args, project) =>
        @requires_conan = args.mode == 'build'
        @_wrapper_location = Path\join project.workspace_dir, (Setting\get 'android.gradle.wrapper')
        @_wrapper_script = Path\join @_wrapper_location, (os.osselect win:'gradlew.bat', unix:'gradlew')

        -- Check we have access to gradlew or are in 'setup' mode
        unless Path\exists @_wrapper_script
            if args.mode == 'setup' or args.mode == 'build' or args.mode == 'sdk'
                java = Where\path 'java'
                @fail "Missing valid java installation. Make sure the 'java' command is visible!" unless java ~= nil

                -- Find a valid gradle installation
                @gradle = Android\detect_gradle install_if_missing:args.install_gradle

                @fail "Missing valid gradle installation. Make sure the 'gradle' command is visible or run this command with '--install-gradle' flag!" unless @gradle ~= nil
                @log\verbose "Gradle installation found at '#{@gradle.exec}'"

                -- cmdline = Setting\get 'android.commandlinetools'
                -- @fail "Missing valid android commandline-tools installation. Make sure you've installed the tools and set the setting properly!" unless Path\exists cmdline
                -- @sdkmanager = Exec Path\join cmdline, 'bin', 'sdkmanager.bat'
            else
                @fail "Gradle wrapper not available, please run the '<ibt> android setup' command!"

        else
            @gradle = Exec @_wrapper_script

        -- Enter the output directory
        Dir\enter project.output_dir

    execute: (args, project) =>
        return @execute_sdkman args, project if args.mode == "sdk"
        return @execute_setup args, project if args.mode == "setup"
        return @execute_configure args, project if args.mode == "configure"
        @execute_build args, project

    execute_sdkman: (args, project) =>
        sdk = Android\detect_android_sdk!
        @fail "Missing Android SDK Manager installation!" unless sdk

        package = sdk.manager\list installed:false

        final_table = { }
        final_ordered_table = { }
        for e in *package.installed
            id = e.path\match "([^;]+;?[^%.]*)"
            if final_table[id] ~= nil
                @log\warning "Multiple packages with the same major version found: #{final_table[id].path} != #{e.path}"

            if not final_table[id]
                final_table[id] = {
                    id: id
                    path: e.path
                    name: e.description
                    location: e.location
                    version: { current:e.version }
                }
                table.insert final_ordered_table, final_table[id]

            elseif final_table[id].version.current < e.version
                final_table[id].version.current = e.version

        for e in *package.available
            id = e.path\match "([^;]+;?[^%.]*)"
            if (id\match "ndk;") and final_table[id]
                newest = final_table[id].version.newest or final_table[id].version.current
                if newest < e.version
                    final_table[id].version.newest = e.version

        for e in *package.updates
            id = e.id\match "([^;]+;?[^%.]*)"
            if id and final_table[id]
                newest = final_table[id].version.newest or final_table[id].version.current
                if newest < e.available
                    final_table[id].version.newest = e.available

        -- Final output
        @log\info "SDK location: #{sdk.location}"

        if args.list
            @log\info "Installed packages:"
            for package in *final_ordered_table
                if args.list == 'outdated' and package.version.newest
                    @log\info "#{package.name}\n- id: #{package.id}\n- version: #{package.version.current}\n- available: #{package.version.newest}"
                elseif args.list ~= 'outdated'
                    if package.version.newest
                        @log\info "#{package.name}\n- id: #{package.id}\n- version: #{package.version.current}\n- available: #{package.version.newest}"
                    else
                        @log\info "#{package.name}\n- id: #{package.id}\n- version: #{package.version.current}"

        elseif args.update and #args.update > 0
            for package in *args.update
                info = final_table[package]
                if info and info.version.newest
                    if package\match "ndk;"
                        sdk.manager\install package:"ndk;#{info.version.newest}"
                        sdk.manager\uninstall package:info.path
                    else
                        sdk.manager\install package:info.path
                else
                    @fail "Package #{package} was not available for updating."

    execute_build: (args, project) =>
        @fail "Missing target to execute build!" unless args.target

        -- Run setup before calling build if wrapper script is not available
        unless File\exists @_wrapper_script
            @execute_setup {}, project
            @gradle = Exec @_wrapper_script

        Dir\enter @_wrapper_location, ->
            @gradle\run "#{args.target} #{args.rerun_tasks and '--rerun-tasks' or ''}"

    execute_setup: (args, project) =>
        @log\info "Setting up environment for Android development..."

        -- Generate command line proxy for android studio
        @_generate_gradle_batch_proxy project

        -- Generate android_targets.txt configuration file
        FastBuild!\build
            config:Setting\get 'build.fbuild_config_file'
            target:'android-targets'
            clean:true

        -- If we can open android_targets.txt we continue generation
        workspace = @_load_android_projects_all project, INIConfig\open "android_projects.txt", debug:false
        unless #workspace.projects > 0
            @log\warning "No valid Android projects found, skipping..."
            return true

        -- Setup the project files
        workspace_source_location = workspace.templates_location
        workspace_build_location = @_wrapper_location


        target_settings_template = Path\join workspace_source_location, "settings.gradle.template.kts"
        target_build_template = Path\join workspace_build_location, "build.gradle.template.kts"
        if args.copy_templates
            @fail "[--copy-templates] Target directory '#{args.copy_templates}' does not exist!" unless Dir\exists args.copy_templates
            if File\copy loc_workspace_settings_template, target_settings_template
                @log\info "Copied project settings template from '#{loc_workspace_settings_template}' to '#{target_settings_template}'"
            if File\copy loc_workspace_build_template, target_build_template
                @log\info "Copied project build template from '#{loc_workspace_build_template}' to '#{target_build_template}'"

        -- Generate Gradle workspace directories
        @log\info "Preparing workspace location..."
        Dir\create workspace_build_location
        Dir\enter workspace_build_location, ->
            settings_path = Setting\get 'android.gradle.settings_template'
            build_path = Setting\get 'android.gradle.build_template'

            settings_path = target_settings_template if File\exists target_settings_template
            build_path = target_build_template if File\exists target_build_template

            -- Try load load from settings, if files are missing

            @fail "File '#{settings_path}' does not exist." unless Path\exists settings_path
            @fail "File '#{build_path}' does not exist." unless Path\exists build_path

            @log\info "Selected project settings template from: #{settings_path}"
            @log\info "Selected project build template from: #{build_path}"

            @log\info "Writing settings file to: " .. (Path\join workspace_build_location, 'settings.gradle.kts')
            @log\info "Writing build file to: " .. (Path\join workspace_build_location, 'build.gradle.kts')
            File\save (Path\join workspace_build_location, 'settings.gradle.kts'), @_fill_template_file settings_path, workspace.context
            File\save (Path\join workspace_build_location, 'build.gradle.kts'), @_fill_template_file build_path, workspace.context

            sdk = Android\detect_android_sdk!
            sdk_location = Path.Unix\normalize sdk.location
            sdk_location = sdk_location\gsub ':', '\\:' if os.iswindows

            File\save (Path\join workspace_build_location, 'local.properties'), table.concat {
                "sdk.dir=#{sdk_location}" -- TODO: Escape on windows only
            }, '\n'
            File\save (Path\join workspace_build_location, 'gradle.properties'), table.concat {
                "android.useAndroidX=true"
            }, '\n'

        for project in *workspace.projects
            context = project.context
            project_source_location = project.location
            project_build_location = Path\join workspace_build_location, project.name
            @log\info "Preparing project location '#{project_build_location}'..."

            -- Generate module gradle project files
            Dir\create project_build_location
            Dir\enter project_build_location, ->
                template_file = Path\join project_source_location, "build.gradle.template.kts"

                if args.copy_templates and File\copy loc_project_build_template, template_file
                    @log\info "Copied module build template from '#{loc_project_build_template}' to '#{template_file}'"

                File\save 'build.gradle.kts', @_fill_template_file template_file, context

        Dir\enter workspace_build_location, ->
            -- Create a wrapper in the build location
            @gradle\run 'wrapper'

    _load_android_projects_all: (ibt_project, projects_ini) =>
        project_list = projects_ini\section 'projects', 'array'

        plugins = { }
        workspace = projects:{ }, context:{ }
        for project_name in *project_list
            project = @_load_android_project ibt_project, INIConfig\open "android_targets_#{project_name}.txt"

            plugins[plugin] = true for plugin in *project.plugins
            table.insert workspace.projects, project

        if #project_list > 0
            workspace.templates_location = Path\join workspace.projects[1].location, '..'

            plugins = [plugin for plugin in pairs plugins]
            table.sort plugins, (a, b) -> a < b
            workspace.context.Plugins = plugins

        -- Prepare a list of modules
        workspace.context.ModuleIncludes = ["include(\":#{project.name}\")" for project in *workspace.projects]
        workspace

    _load_android_project: (ibt_project, ini) =>
        info_general = ini\section 'general', 'map'
        info_plugins = ini\section 'gradle_plugins', 'array'
        info_abis = ini\section 'supported_abis', 'array'
        info_targets = ini\section 'android_targets', 'array'

        project = info_general
        project.plugins = info_plugins
        project.targets = { }
        project.abis = info_abis
        project.jnis = { }
        project.context = {
            ProjectName: info_general.name
            ProjectDir: info_general.location
            CompileSDK: info_general.android_compilesdk
            MinSDK: info_general.android_minsdk or target_info.android_compilesdk
            TargetSDK: info_general.android_targetsdk or target_info.android_compilesdk
            ApplicationId: info_general.android_applicationid
            Namespace: info_general.android_namespace
            VersionCode: info_general.android_versioncode
            VersionName: info_general.android_versionname
            NDKVersion: info_general.android_ndkversion
            ProjectPlugins: info_plugins
            ProjectJNISources: { }
            ProjectCustomConfigurationTypes: {}
            IBTBuildSystemIntegration: @_generate_gradle_ninja_proxy ibt_project, project
        }

        @log\verbose "Finished context creation for '#{project.name}'"

        seen_configs = { }
        for target in *info_targets
            target_info = ini\section target, 'map'
            @log\verbose "Checking target '#{target}'..."

            config_lower = target_info.config\lower!
            macro_lines = project.context.ProjectCustomConfigurationTypes
            unless seen_configs[config_lower]
                seen_configs[config_lower] = { }
                unless (config_lower == 'debug') or (config_lower == 'release')
                    @log\info "Generating new config '#{config_lower}' for Gradle"

                    table.insert macro_lines, "create(\"#{config_lower}\") {"
                    if config_lower\match 'debug'
                        table.insert macro_lines, "    initWith(getByName(\"debug\"))"
                    else
                        table.insert macro_lines, "    initWith(getByName(\"release\"))"
                    table.insert macro_lines, "}"

            -- Store all ABI related JNI locations that will be later set
            project.jnis[config_lower] = { } unless project.jnis[config_lower]
            table.insert project.jnis[config_lower], target_info.android_deploy_dir

            table.insert project.targets, {
                target:target
                executable:target_info.executable
                output_dir:target_info.output_dir
                deploy_dir:target_info.deploy_dir
                working_dir:target_info.working_dir
                platform:target_info.platform
                config:target_info.config
                pipeline:target_info.pipeline
                name:project.name
            }

        -- Generate final macro lines for JNI sources
        macro_lines = project.context.ProjectJNISources
        for config_lower, paths in pairs project.jnis
            table.insert macro_lines, "getByName(\"#{config_lower}\") {"
            for path in *paths
                table.insert macro_lines, "    jniLibs.srcDir(\"#{path}\")"
            table.insert macro_lines, "}"

        project

    _fill_template_file: (template_file, context) =>
        template = File\load template_file
        template = template\gsub '([ \t]*)%$%(([a-zA-Z_%.]+)([a-zA-Z_%.\'%{%} ]*)%)', (spaces, key, format) ->
            format = format\match "'([a-zA-Z_%.\'%{%} ]+)'"
            format = format\gsub "%{%}", "%%s" if format
            format = "%s" unless format

            if value = context[key]
                if (type value) == 'table'
                    return spaces .. (table.concat [string.format format, val for val in *value], "\n#{spaces}")
                else
                    return "#{spaces}#{string.format format, value}"
            else
                return "#{spaces}<unknown-tag:#{key}>" unless value
        template

    _generate_gradle_ninja_proxy: (ibt, project) =>
        abis_string = table.concat ["\"#{abi}\"" for abi in pairs project.abis], ', '
        makefile_file = Path.Unix\join ibt.workspace_dir, ibt.output_dir, 'fbuild.windows.fdb' -- TODO: is this right?
        configure_batch = Path.Unix\join ibt.workspace_dir, ibt.output_dir, 'ibt_android.bat'
        return {
            "// IBT Generated - BEGIN"
            "externalNativeBuild {"
            "    experimentalProperties[\"ninja.abiFilters\"] = listOf(#{abis_string})"
            "    experimentalProperties[\"ninja.path\"] = \"E:/Projects/GitHub/engine/build/fbuild.windows.fdb\""
            "    experimentalProperties[\"ninja.configure\"] = \"#{configure_batch}\""
            "    experimentalProperties[\"ninja.arguments\"] = listOf("
            "        \"--db=\\${ndk.moduleMakeFile}\","
            "        \"--name=#{project.name}\","
            "        \"--abi=\\${ndk.abi}\","
            "        \"--config=\\${ndk.variantName}\","
            "        \"--out=\\${ndk.buildRoot}\","
            "        \"--pipeline=Android#{project.android_compilesdk}\","
            "        \"--ndk-version=\\${ndk.moduleNdkVersion}\","
            "        \"-p:Configuration=\\${ndk.variantName}\"," -- This and the following line are necessary so gradle does not complain about missing values not passed to the config script.
            "        \"-p:Platform=\\${ndk.abi}\","
            "    )"
            "}"
            "// IBT Generated - END"
        }


    _generate_gradle_batch_proxy: (project) =>
        script = (Path\join project.workspace_dir, project.script) unless Path\is_absolute project.script

        lines = {
            ":: This file was generated by IBT to integrate AndroidStudio (Gradle) with the IBT build system."
            "@ECHO off"
            "SETLOCAL"
            "\n:: Helper variable to keep the selected arguments"
            "set SELECTED_ARGS="
            "\n:: Parse all arguments and strip everything that starts with '-p:' since it's not parsed properly by IBT."
            ":parse_arguments"
            "set ARG=%~1"
            "if NOT \"%ARG:~0,3%\" == \"-p:\" ("
            "    set SELECTED_ARGS=%SELECTED_ARGS% %ARG%"
            ")"
            "shift"
            "if not \"%~1\"==\"\" goto parse_arguments"
            "\n:: Call IBT to configure the selected Android native target"
            "call \"#{script}\" android configure %SELECTED_ARGS%"
        }
        File\save (Path\join project.workspace_dir, project.output_dir, 'ibt_android.bat'), table.concat lines, '\n'

    execute_configure: (args, project) =>
        abi_to_pipeline_map = Setting\get 'android.gradle.abi_pipeline_mapping'
        pipeline_arch = abi_to_pipeline_map[args.abi]
        Log\info "Mapped ABI '#{args.abi}' to the '#{pipeline_arch}' pipeline arch"
        config = args.config\gsub '^%w', (c) -> c\upper!
        Log\info "Mapped config '#{args.config}' to '#{config}'"
        Log\info "Selected NDK version: #{args.ndk_version}"
        args.pipeline ..= "-" if args.pipeline and args.pipeline ~= ""
        Log\info "Selected Pipeline: #{args.pipeline}#{pipeline_arch}"
        target = "all-#{args.pipeline}#{pipeline_arch}-#{config}"

        script_file = (Path\join project.workspace_dir, project.script) unless Path\is_absolute project.script
        config_file = Path\join project.workspace_dir, project.output_dir, (Setting\get 'build.fbuild_config_file')
        compdb_file = Path\join args.out, "compile_commands.json"
        -- libs_file = Path\join project.workspace_dir, project.output_dir, 'android_libs.txt'
        targets_file = Path\join project.workspace_dir, project.output_dir, "android_targets_#{args.name}.txt"
        @fail "Failed to generate compile commands for '#{target}'!" unless FastBuild!\compdb output:args.out, target:target, config:config_file
        @fail "Failed to generate android lib targets for '#{target}'!" unless FastBuild!\build target:'android-targets', config:config_file
        compdb = File\load compdb_file, parser:Json\decode
        -- libs = INIConfig\open libs_file
        targets = INIConfig\open targets_file

        first_entry = compdb[1]
        compiler = first_entry.arguments[1]

        ninja_file = Path\join args.out, "build.ninja"
        ninja_file_contents = {
            "# Ninja file generated by IBT to support AndroidStudio (Gradle)"
            "rule FBUILD"
            "  command = #{script_file} build #{target}"
            "rule LINK"
            "  command = #{script_file} build $out"
            ""
        }

        idx = 0
        for entry in *compdb
            table.insert ninja_file_contents, "rule COMPILE#{idx}"
            command = table.concat entry.arguments, ' '
            table.insert ninja_file_contents, "  command = #{command\gsub ':', '$:'}"
            idx += 1

        table.insert ninja_file_contents, "\n"

        idx = 0
        for entry in *compdb
            table.insert ninja_file_contents, "build #{entry.output\gsub ':', '$:'} : COMPILE#{idx} #{entry.file\gsub ':', '$:'}"
            idx += 1

        table.insert ninja_file_contents, "\n"
        table.insert ninja_file_contents, "build linker_dummy.o : FBUILD\n"

        target_id = "#{args.name}-#{args.pipeline}#{pipeline_arch}-Android-#{config}-NDK#{args.ndk_version}"
        target_info = targets\section target_id, 'map'
        target_path = target_info.executable\gsub ':', '$:'
        target_libs = {}

        table.insert ninja_file_contents, "build #{target_path} : LINK linker_dummy.o"
        table.insert ninja_file_contents, "build #{target_info.libname} : phony #{target_path}"
        table.insert target_libs, name:args.name, libname:target_info.libname

        for lib in *target_libs
            table.insert ninja_file_contents, "build #{lib.name} : phony #{lib.libname}"

        -- table.insert ninja_file_contents, "build all : phony #{all_targets}"
        -- table.insert ninja_file_contents, "build all.passthrough : FBUILD\n"
        table.insert ninja_file_contents, '\n'

        File\save ninja_file, table.concat ninja_file_contents, "\n"

{ :AndroidCommand }
