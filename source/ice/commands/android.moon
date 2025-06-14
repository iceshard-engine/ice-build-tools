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

loc_project_build_template = Path\join (os.getenv 'IBT_DATA'), 'project_build.gradle.template.kts'
loc_project_settings_template = Path\join (os.getenv 'IBT_DATA'), 'project_settings.gradle.template.kts'
loc_module_build_template = Path\join (os.getenv 'IBT_DATA'), 'module_build.gradle.template.kts'

class AndroidCommand extends Command
    @settings {
        Setting 'android.projects', default:{}
        Setting 'android.gradle.build_template',
            default:loc_project_build_template
            predicate:(v) -> v == nil or File\exists v
        Setting 'android.gradle.settings_template',
            default:loc_project_settings_template
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
        option 'builddb',
            group: 'configure',
            name: '--db'
        option 'config',
            group: 'configure'
            name: '--config -p:Configuration'
        option 'abi',
            group: 'configure'
            name: '--abi -p:Platform'
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
        android_project = @_load_android_ini INIConfig\open "android_targets.txt", debug:false
        unless android_project and Dir\exists (android_project.location or '')
            @log\warning "No Android projects found for setup, skipping..."
            return true

        -- Setup the project files
        project_source_location = android_project.location
        project_build_location = @_wrapper_location

        target_settings_template = Path\join project_source_location, "settings.gradle.template.kts"
        target_build_template = Path\join project_source_location, "build.gradle.template.kts"
        if args.copy_templates
            @fail "[--copy-templates] Target directory '#{args.copy_templates}' does not exist!" unless Dir\exists args.copy_templates
            if File\copy loc_project_settings_template, target_settings_template
                @log\info "Copied project settings template from '#{loc_project_settings_template}' to '#{target_settings_template}'"
            if File\copy loc_project_build_template, target_build_template
                @log\info "Copied project build template from '#{loc_project_build_template}' to '#{target_build_template}'"

        -- Generate Gradle project directories
        Dir\create project_build_location
        Dir\enter project_build_location, ->
            settings_path = Setting\get 'android.gradle.settings_template'
            build_path = Setting\get 'android.gradle.build_template'

            settings_path = target_settings_template if File\exists target_settings_template
            build_path = target_build_template if File\exists target_build_template

            -- Try load load from settings, if files are missing

            @fail "File '#{settings_path}' does not exist." unless Path\exists settings_path
            @fail "File '#{build_path}' does not exist." unless Path\exists build_path

            @log\info "Selected project settings template from: #{settings_path}"
            @log\info "Selected project build template from: #{build_path}"

            @log\info "Writing settings file to: " .. (Path\join project_build_location, 'settings.gradle.kts')
            @log\info "Writing build file to: " .. (Path\join project_build_location, 'build.gradle.kts')
            File\save (Path\join project_build_location, 'settings.gradle.kts'), @_fill_template_file settings_path, android_project.context
            File\save (Path\join project_build_location, 'build.gradle.kts'), @_fill_template_file build_path, android_project.context

            sdk = Android\detect_android_sdk!
            File\save (Path\join project_build_location, 'local.properties'), table.concat {
                "sdk.dir=#{Path.Unix\normalize sdk.location}"
            }, '\n'
            File\save (Path\join project_build_location, 'gradle.properties'), table.concat {
                "android.useAndroidX=true"
            }, '\n'

        -- Go over the configuration file and find all android-gradle enabled projects
        processed_modules = { }
        for module_name, module_info in pairs android_project.modules
            module_info.name = module_name
            module_source_location = module_info.source_dir
            module_build_location = Path\join project_build_location, module_name

            -- Generate module gradle project files
            Dir\create module_build_location
            Dir\enter module_build_location, ->
                module_info.context.ScriptFile = project.script
                module_info.context.WorkspaceDir = project.workspace_dir
                module_info.context.BuildDir = project.output_dir
                module_info.context.DeployDir = project.deploy_dir
                template_file = Path\join module_source_location, "build.gradle.template.kts"

                if args.copy_templates and File\copy loc_module_build_template, template_file
                    @log\info "Copied module build template from '#{loc_module_build_template}' to '#{template_file}'"

                File\save 'build.gradle.kts', @_fill_template_file template_file, module_info.context

        Dir\enter project_build_location, ->
            -- Create a wrapper in the build location
            @gradle\run 'wrapper'

    _load_android_ini: (ini) =>
        android_targets = ini\section 'android_targets', 'array'

        module_names = { }
        project = modules:{}, plugins:{}, context:{}
        for target in *android_targets
            target_info = ini\section target, 'map'

            module_info = project.modules[target_info.android_module]
            unless module_info ~= nil
                project.location = Path\join target_info.source_dir, '..' unless project.location

                module_plugins = [{val\match '((id%(".+"%)) version ".+")'} for val in *(ini\section "#{target}-Gradle-Plugins", 'array') or { }]
                project.plugins[val[1]] = true for val in *module_plugins

                module_info = { targets:{ } }
                module_info.source_dir = target_info.source_dir
                module_info.config_sources = { }
                module_info.context = {
                    ProjectDir: target_info.source_dir
                    ProjectOutputDir: target_info.output_dir\gsub target_info.config, "${buildConfig}"
                    ProjectDeployDir: target_info.deploy_dir\gsub target_info.config, "${buildConfig}"
                    ProjectPlugins: [val[2] for val in *module_plugins]
                    CompileSDK: target_info.android_compilesdk
                    MinSDK: target_info.android_minsdk or target_info.android_compilesdk
                    TargetSDK: target_info.android_targetsdk or target_info.android_compilesdk
                    -- AndroidBuildToolsVersion: target_info.android_buildtoolsversion
                    ApplicationId: target_info.android_applicationid
                    Namespace: target_info.android_namespace
                    VersionCode: target_info.android_versioncode
                    VersionName: target_info.android_versionname
                    NDKVersion: target_info.android_ndkversion
                    ProjectJNISources: {}
                    ProjectCustomConfigurationTypes: {}
                }

                table.sort module_info.context.ProjectPlugins, (l, r) -> l < r

                -- module_info.flavourDimensions = { }
                -- module_info.flavours = { }
                -- module_info.dependencies = ini\section "#{target}-Android-Dependencies", 'array'
                project.modules[target_info.android_module] = module_info
                table.insert module_names, target_info.android_module

            config_lower = target_info.config\lower!

            macro_lines = module_info.context.ProjectCustomConfigurationTypes
            unless module_info.config_sources[config_lower]
                module_info.config_sources[config_lower] = { }
                unless (config_lower == 'debug') or (config_lower == 'release')
                    table.insert macro_lines, "create(\"#{config_lower}\") {"
                    if config_lower\match 'debug'
                        table.insert macro_lines, "    initWith(getByName(\"debug\"))"
                    else
                        table.insert macro_lines, "    initWith(getByName(\"release\"))"
                    table.insert macro_lines, "}"

            -- Store all ABI related JNI locations that will be later set
            table.insert module_info.config_sources[config_lower], target_info.android_deploy_dir

            table.insert module_info.targets, {
                target:target
                executable:target_info.executable
                output_dir:target_info.output_dir
                deploy_dir:target_info.deploy_dir
                working_dir:target_info.working_dir
                platform:target_info.platform
                config:target_info.config
                pipeline:target_info.pipeline
                name:target_info.name
            }

        -- Generate final macro lines for JNI sources
        for _, module_info in pairs project.modules
            macro_lines = module_info.context.ProjectJNISources
            for config_lower, config_sources in pairs module_info.config_sources
                table.insert macro_lines, "getByName(\"#{config_lower}\") {"
                for config_src in *config_sources
                    table.insert macro_lines, "    jniLibs.srcDir(\"#{config_src}\")"
                table.insert macro_lines, "}"

        -- Prepare a sorted array of plugins
        project.context.Plugins = [plugin for plugin in pairs project.plugins]
        table.sort project.context.Plugins, (l, r) -> l < r

        -- Prepare a list of modules
        project.context.ModuleIncludes = ["include(\":#{name}\")" for name in *module_names]
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
        @fail "Failed to generate compile commands for selected target!" unless FastBuild!\compdb output:args.out, target:target, config:config_file
        compdb = File\load compdb_file, parser:Json\decode

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

        idx = 0
        objects = {}
        for entry in *compdb
            table.insert objects, "OBJ#{idx}"
            table.insert ninja_file_contents, "build OBJ#{idx} : phony #{entry.output\gsub ':', '$:'}"
            idx += 1

        table.insert ninja_file_contents, "\n"
        -- table.insert ninja_file_contents, "build E$:/Projects/GitHub/engine/build/deploy/simple/Android35-x64-Android-Debug-ndk28-clang-19.0.0/x86_64/libsimple.so : phony " .. table.concat objects, ' '
        f = "E$:/Projects/GitHub/engine/build/deploy/simple/Android35-x64-Android-Debug-ndk28-clang-19.0.0/x86_64/libsimple.so"
        table.insert ninja_file_contents, "build #{f} : LINK " .. compdb[1].output\gsub ':', '$:'
        table.insert ninja_file_contents, "build libsimple.so : phony #{f}"
        table.insert ninja_file_contents, "\n"
        table.insert ninja_file_contents, "build all : phony #{f}"
        table.insert ninja_file_contents, "build all.passthrough : FBUILD\n"
            -- print entry.file

        -- contents = {
        --     "rule COMPILE"
        --     "  command = C$:/Users/dandi/AppData/Local/Android/Sdk/ndk/28.1.13356709/toolchains/llvm/prebuilt/windows-x86_64/bin/clang++.exe -c $in -o $out -target x86_64-none-linux-android35"
        --     "rule LINK"
        --     "  command = C$:/Users/dandi/AppData/Local/Android/Sdk/ndk/28.1.13356709/toolchains/llvm/prebuilt/windows-x86_64/bin/clang++.exe $in -o $out -target x86_64-none-linux-android35"
        --     "rule FBUILD"
        --     "  command = #{script_file} build all-Android35-x64-Debug"
        --     ""
        --     "build test0.o : COMPILE E$:/Projects/GitHub/engine/source/code/core/core/private/test.cxx"
        --     "build test1.o : COMPILE E$:/Projects/GitHub/engine/source/code/core/memsys/private/test.cxx"
        --     "build libtest.so : LINK test0.o"
        --     "build test : phony libtest.so"
        --     "build all : phony test"
        --     "build test.passthrough : FBUILD"
        --     ""
        -- }

        File\save ninja_file, table.concat ninja_file_contents, "\n"
        -- print k, v for k, v in pairs args

{ :AndroidCommand }
