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
        Setting 'android.gradle.wrapper', required:true, default:'build/android_gradle'
        Setting 'android.gradle.version', required:true, default:'8.1.1'
        Setting 'android.gradle.package_url', required:true, default:"https://downloads.gradle.org/distributions/gradle-{ver}-bin.zip"
    }
    @arguments {
        group 'general', description: "Basic options"
        argument 'mode',
            group: 'general'
            description: 'Selects the mode in which the command operates.'
            name: 'mode'
            choices: { 'build', 'setup' }
            default: 'build'
        group 'setup', description: "Setup options"
        option 'copy_templates',
            group: 'setup'
            description: 'Copies the template files stored in the package to the provided location. Skips files that arleady exist.'
            name: '--copy-templates'
            argname:'<path>'
    }

    prepare: (args, project) =>
        wrapper_script = Path\join (Setting\get 'android.gradle.wrapper'), (os.osselect win:'gradlew.bat', unix:'gradlew')

        -- Check we have access to gradlew or are in 'setup' mode
        unless Path\exists wrapper_script
            if args.mode == 'setup'
                java = Where\path 'java'
                @fail "Missing valid java installation. Make sure the 'java' command is visible!" unless java ~= nil

                gradle = Where\path 'gradle'
                @fail "Missing valid gradle installation. Make sure the 'gradle' command is visible!" unless gradle ~= nil
                @gradle = Exec gradle

                -- cmdline = Setting\get 'android.commandlinetools'
                -- @fail "Missing valid android commandline-tools installation. Make sure you've installed the tools and set the setting properly!" unless Path\exists cmdline
                -- @sdkmanager = Exec Path\join cmdline, 'bin', 'sdkmanager.bat'
            else
                @fail "Gradle wrapper not available, please run the '<ibt> android setup' command!"

        else
            @gradle = Exec (Path\join Dir\current!, wrapper_script)

        -- Enter the output directory
        Dir\enter project.output_dir

    execute: (args, project) =>
        return @execute_setup args, project if args.mode == "setup"
        @execute_build args, project

    execute_build: (args, project) =>
        wrapper_location = Path\join project.workspace_dir, (Setting\get 'android.gradle.wrapper')
        module_build_location = Path\join wrapper_location, 'build.gradle.kts'
        @log\warning "Command not implemented, please open '#{module_build_location}' project file in Android Studio!"

    execute_setup: (args, project) =>
        @log\info "Setting up environment for Android development..."

        -- Generate android_targets.txt configuration file
        FastBuild!\build
            config:Setting\get 'build.fbuild_config_file'
            target:'android-targets'
            clean:true

        -- If we can open android_targets.txt we continue generation
        android_project = @_load_android_ini INIConfig\open "android_targets.txt", debug:false
        @fail "No Android projects found for setup!" unless android_project and Dir\exists android_project.location or ""

        -- Setup the project files
        wrapper_location = Path\join project.workspace_dir, (Setting\get 'android.gradle.wrapper')
        project_source_location = android_project.location
        project_build_location = wrapper_location

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
                module_info.context = {
                    ProjectDir: target_info.source_dir
                    ProjectOutputDir: target_info.output_dir\gsub target_info.config, "${buildConfig}"
                    ProjectPlugins: [val[2] for val in *module_plugins]
                    CompileSDK: target_info.android_compilesdk
                    MinSDK: target_info.android_minsdk or target_info.android_compilesdk
                    TargetSDK: target_info.android_targetsdk or target_info.android_compilesdk
                    -- AndroidBuildToolsVersion: target_info.android_buildtoolsversion
                    ApplicationId: target_info.android_applicationid
                    Namespace: target_info.android_namespace
                    VersionCode: target_info.android_versioncode
                    VersionName: target_info.android_versionname
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

            -- Generating custom config requests
            macro_lines = module_info.context.ProjectJNISources
            table.insert macro_lines, "getByName(\"#{config_lower}\") {"
            table.insert macro_lines, "    jniLibs.srcDir(\"#{target_info.output_dir}\")"
            table.insert macro_lines, "}"

            macro_lines = module_info.context.ProjectCustomConfigurationTypes
            unless (config_lower == 'debug') or (config_lower == 'release')
                table.insert macro_lines, "create(\"#{config_lower}\") {"
                if config_lower\match 'debug'
                    table.insert macro_lines, "    initWith(getByName(\"debug\"))"
                else
                    table.insert macro_lines, "    initWith(getByName(\"release\"))"
                table.insert macro_lines, "}"

            table.insert module_info.targets, {
                target:target
                executable:target_info.executable
                output_dir:target_info.output_dir
                working_dir:target_info.working_dir
                platform:target_info.platform
                config:target_info.config
                pipeline:target_info.pipeline
                name:target_info.name
            }

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

{ :AndroidCommand }
