
import Json from require 'ice.util.json'

class VSCodeProjectGen
    new: (@project, @fbuild) =>

    create_tasks_file: (path, targets, args = {}) =>
        build_configs_base = {
            version: '2.0.0',
            tasks: { }
        }

        build_configs = build_configs_base
        if args.update
            if f = io.open path, "rb"
                build_configs = Json\decode (f\read "*a")
                error "Couldn't read JSon data from file '#{path}'" unless build_configs
                build_configs.version = build_configs_base.version unless build_configs.version
                build_configs.tasks = build_configs_base.tasks unless build_configs.tasks
                f\close!
            else
                error "Failed to open path '#{path}'"

        -- Get the updated tasks object
        build_configs = @update_tasks_json build_configs, targets

        -- Save
        if f = io.open path, "wb+"
            f\write Json\encode build_configs
            f\close!
            return true
        return false

    create_launch_file: (path, targets, args = {}) =>
        launch_configs_base = {
            version: '2.0.0',
            configurations: { }
        }

        launch_configs = launch_configs_base
        if args.update
            if f = io.open path, "rb"
                launch_configs = Json\decode (f\read "*a")
                error "Couldn't read JSon data from file '#{path}'" unless launch_configs
                launch_configs.version = launch_configs_base.version unless launch_configs.version
                launch_configs.configurations = launch_configs_base.configurations unless launch_configs.configurations
                f\close!
            else
                error "Failed to open path '#{path}'"

        -- Get the updated configurations object
        launch_configs = @update_launch_json launch_configs, targets

        -- Save
        if f = io.open path, "wb+"
            f\write Json\encode launch_configs
            f\close!
            return true
        return false

    -- [[ Implementation details ]]

    update_tasks_json: (tasks_json, targets) =>
        loaded_tasks = { }
        for task in *tasks_json.tasks
            loaded_tasks[task.label] = task
            loaded_tasks[task.label].referenced = false

        -- Go over targets, find tasks, update their values if needed
        for target in *targets
            label_build = "Build (#{target})"
            label_rebuild = "Rebuild (#{target})"
            label_compdb = "CompileDB (#{target})"

            if task = loaded_tasks[label_build]
                task.referenced = true
                task.command = "#{@project.workspace_dir}/#{@project.script}"
                task.args = { "build", "-t", target }
            else
                loaded_tasks[label_build] = {
                    referenced: true
                    label: label_build
                    type: "shell"
                    command: "#{@project.workspace_dir}/#{@project.script}"
                    args: { "build", "-t", target }
                    group: {
                        kind: "build"
                    }
                }

            if task = loaded_tasks[label_rebuild]
                task.referenced = true
                task.command = "#{@project.workspace_dir}/#{@project.script}"
                task.args = { "build", "-t", target, "-c" }
            else
                loaded_tasks[label_rebuild] = {
                    referenced: true
                    label: label_rebuild
                    type: "shell"
                    command: "#{@project.workspace_dir}/#{@project.script}"
                    args: { "build", "-t", target, "-c" }
                    group: {
                        kind: "build"
                    }
                }

            if task = loaded_tasks[label_compdb]
                task.referenced = true
                task.command = @fbuild.exe
                task.args = { "-config", @fbuild.script, "-compdb", target }
            elseif target\match "^all"
                loaded_tasks[label_compdb] = {
                    referenced: true
                    label: label_compdb
                    type: "shell"
                    command: @fbuild.exe
                    args: { "-config", @fbuild.script, "-compdb", target }
                    group: {
                        kind: "none"
                    }
                }

        -- Clear the previous tasks list
        tasks_json.tasks = { }

        -- Finalize the changes
        for _, task in pairs loaded_tasks
            -- Clear referenced member, safe the task
            if task.referenced
                task.referenced = nil
                table.insert tasks_json.tasks, task
            elseif (task.label\match "^Build %(") or (task.label\match "^Rebuild %(") or (task.label\match "^CompileDB %(")
                nil -- Ignore these tasks removing them
            else -- Unknown user task, keep without any changes
                task.referenced = nil
                table.insert tasks_json.tasks, task

        task_name_val = {
            Build: 1,
            Rebuild: 2,
            CompileDB: 3,
        }

        -- Sort final results
        table.sort tasks_json.tasks, (a, b) ->
            matched1 = a.label\match "^(%w+) %("
            matched2 = b.label\match "^(%w+) %("

            if task_name_val[matched1] and task_name_val[matched2]
                return task_name_val[matched1] < task_name_val[matched2] and a.label < b.label
            elseif task_name_val[matched1]
                return false -- User tasks are always before matched tasks
            elseif task_name_val[matched2]
                return true -- Matched task are always after user tasks
            else
                return a.label < b.label

        tasks_json

    update_launch_json: (configs_json, config_targets) =>
        loaded_configs = { }
        for config in *configs_json.configurations
            loaded_configs[config.name] = config
            loaded_configs[config.name].referenced = false

        for config_target in *config_targets
            config_name = "#{config_target.name} (#{config_target.pipeline}-#{config_target.platform}-#{config_target.config})"

            if config = loaded_configs[config_name]
                config.referenced = true
                config.program = config_target.executable
                config.cwd = config_target.working_dir

            else
                loaded_configs[config_name] = {
                    referenced: true
                    name: "#{config_target.name} (#{config_target.pipeline}-#{config_target.platform}-#{config_target.config})"
                    request: "launch"
                    type: os.osselect win:'cppvsdbg', unix:'gdb'
                    program: config_target.executable
                    args: { }
                    stopAtEntry: false
                    cwd: config_target.working_dir
                    environment: { }
                    console: "externalTerminal"
                }

        -- Clear the previous configuration list
        configs_json.configurations = { }

        -- Finalize the changes
        for _, config in pairs loaded_configs
            -- Clear referenced member, safe the config
            if config.referenced
                config.referenced = nil
                table.insert configs_json.configurations, config
            elseif config.environment.IBT_KEEP_CONFIG -- Special env value to keep user configs
                config.referenced = nil
                table.insert configs_json.configurations, config
            else
                nil -- Ignore other configs removing them

        -- Sort final results
        table.sort configs_json.configurations, (a, b) -> a.name < b.name

        configs_json

{ :VSCodeProjectGen }
