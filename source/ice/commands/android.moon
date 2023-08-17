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

class AndroidCommand extends Command
    @settings {
        Setting 'android.projects', default:{}
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
        android_modules = @_load_android_ini INIConfig\open "android_targets.txt", debug:false

        -- Go over the configuration file and find all android-gradle enabled projects
        gradle_projects = { }
        for module_name, module_info in pairs android_modules
            wrapper_location = Path\join project.workspace_dir, (Setting\get 'android.gradle.wrapper')
            -- For Android a project is a Solution and the Module is the Project (in VS terms)
            module_location = module_info.source_dir
            project_location = Path\join module_info.source_dir, '..'
            module_build_location = Path\join wrapper_location, module_name
            project_build_location = Path\join module_build_location, '..'

            -- Generate base gradle project directories
            unless gradle_projects[project_build_location]
                Dir\create project_build_location
                Dir\enter project_build_location, ->
                    settings_path = Path\join project_location, "settings.gradle.template.kts"
                    build_path = Path\join project_location, "build.gradle.template.kts"
                    @fail "File '#{settings_path}' does not exist." unless Path\exists settings_path
                    @fail "File '#{settings_path}' does not exist." unless Path\exists build_path

                    @log\info "Writing settings file to: " .. (Path\join project_build_location, 'settings.gradle.kts')
                    @log\info "Writing build file to: " .. (Path\join project_build_location, 'build.gradle.kts')
                    File\save (Path\join project_build_location, 'settings.gradle.kts'), (File\load settings_path)
                    File\save (Path\join project_build_location, 'build.gradle.kts'), (File\load build_path)

                    sdk = Android\detect_android_sdk!
                    File\save (Path\join project_build_location, 'local.properties'), table.concat {
                        "sdk.dir=#{Path.Unix\normalize sdk.location}"
                    }, '\n'
                    File\save (Path\join project_build_location, 'gradle.properties'), table.concat {
                        "android.useAndroidX=true"
                    }, '\n'

                    -- Create the wrapper in the build location
                    @gradle\run 'wrapper'

                    gradle_projects[project_location] = {
                        location:project_location
                        build_location:project_build_location
                        settings_template:settings_path
                        build_template:build_path
                        modules:{}
                    }

            -- Extend module information
            module_info.name = module_name
            table.insert gradle_projects[project_location], {
                module_info
            }

            -- Generate module gradle project files
            Dir\create module_build_location
            Dir\enter module_build_location, ->
                module_info.context.ScriptFile = project.script
                module_info.context.WorkspaceDir = project.workspace_dir
                module_info.context.BuildDir = project.output_dir

                build_template_file = Path\join module_location, "build.gradle.template.kts"
                build_template = File\load build_template_file
                build_template = build_template\gsub '([ \t]*)%$%(([a-zA-Z_%.]+)%)', (spaces, key) ->
                    if value = module_info.context[key]
                        if (type value) == 'table'
                            return spaces .. (table.concat value, "\n#{spaces}")
                        else
                            return "#{spaces}#{value}"
                    else
                        return "#{spaces}<unknown-tag:#{key}>" unless value

                -- Save the build file
                File\save 'build.gradle.kts', build_template

    _load_android_ini: (ini) =>
        android_targets = ini\section 'android_targets', 'array'

        modules = { }
        for target in *android_targets
            target_info = ini\section target, 'map'

            module_info = modules[target_info.android_module]
            unless module_info ~= nil
                module_info = { targets:{ } }
                module_info.source_dir = target_info.source_dir
                module_info.context = {
                    ProjectDir: target_info.source_dir
                    ProjectOutputDir: target_info.output_dir
                    ProjectPlugins: ini\section "#{target}-Gradle-Plugins", 'array'
                    AndroidAPILevel: target_info.android_androidapilevel
                    AndroidMinSDK: target_info.android_minsdk or target_info.android_androidapilevel
                    AndroidTargetSDK: target_info.android_targetsdk or target_info.android_androidapilevel
                    AndroidBuildToolsVersion: target_info.android_buildtoolsversion
                    ApplicationId: target_info.android_applicationid
                    Namespace: target_info.android_namespace
                    VersionCode: target_info.android_versioncode
                    VersionName: target_info.android_versionname
                    ProjectCustomConfigurationTypes: {}
                }
                -- module_info.flavourDimensions = { }
                -- module_info.flavours = { }
                -- module_info.dependencies = ini\section "#{target}-Android-Dependencies", 'array'
                modules[target_info.android_module] = module_info

            -- Generating custom config requests
            custom_config = module_info.context.ProjectCustomConfigurationTypes
            config_lower = target_info.config\lower!
            is_debug = config_lower == 'debug'
            is_release = config_lower == 'release'
            unless is_debug or is_release
                table.insert custom_config, "create(\"#{config_lower}\") {"
                if config_lower\match 'debug'
                    table.insert custom_config, "    initWith(getByName(\"debug\"))"
                else
                    table.insert custom_config, "    initWith(getByName(\"release\"))"
                table.insert custom_config, "}"

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

        modules

{ :AndroidCommand }
