import XML, XMLNode from require "ice.util.xml"
import File, Dir, Path from require "ice.core.fs"
import Validation from require "ice.core.validation"
import Logger, LogCategory from require "ice.core.logger"

uuid = require "uuid.uuid"

class CLionConfiguration extends XMLNode
    @Attrib =
        Version: 'version'
        Type: 'type'
        Name: 'name'
        ProjectName: 'PROJECT_NAME'
        -- Build Related
        TargetName: 'TARGET_NAME'
        ConfigName: 'CONFIG_NAME'
        -- Execution related
        RunPath: 'RUN_PATH'
        WorkingDir: 'WORKING_DIR'
        ProgramParams: 'PROGRAM_PARAMS'
        RedirectInput: 'REDIRECT_INPUT'
        Elevate: 'ELEVATE'
        ExternalConsole: 'USE_EXTERNAL_CONSOLE'
        EmulateTerminal: 'EMULATE_TERMINAL'
        PassParentEnvs: 'PASS_PARENT_ENVS_2'

    name: => @dom._attr.name
    config: => @dom._attr[Attrib.ConfigName]
    target: => @dom._attr[Attrib.TargetName]


    -- <configuration TARGET_NAME="Unnamed" CONFIG_NAME="Unnamed" version="1" RUN_PATH="$PROJECT_DIR$/build/bin/x64/Linux-Debug-clang-21.0.0/test/test">
    --   <method v="2">
    --     <option name="CLION.COMPOUND.BUILD" enabled="true" />
    --   </method>
    -- </configuration>

    @create: (project, target, args) =>
        config = XMLNode\element 'configuration', {
            [@Attrib.Version]: '1'
            [@Attrib.Type]: 'CLionNativeAppRunConfigurationType'
            [@Attrib.Name]: args.long_name
            [@Attrib.ProjectName]: project
            -- Build Related
            [@Attrib.TargetName]: args.build_target
            -- [@Attrib.ConfigName]: args.config -- TODO: can we make use of this in a different way?
            [@Attrib.ConfigName]: args.build_target
            -- Execution Related
            [@Attrib.RunPath]: args.executable
            [@Attrib.WorkingDir]: args.working_dir
            [@Attrib.ProgramParams]: ''
            [@Attrib.RedirectInput]: 'false'
            [@Attrib.Elevate]: 'false'
            [@Attrib.ExternalConsole]: 'false'
            [@Attrib.EmulateTerminal]: 'false'
            [@Attrib.PassParentEnvs]: 'true'
        }
        if config
            option = XMLNode\element 'option', name:'CLION.COMPOUND.BUILD', enabled:'true'
            method = XMLNode\element 'method', v:'2'
            method._children = {option}
            config._children = {method}
        config

class CLionComponent extends XMLNode
    name: => @dom._attr.name

class CLionRunManager extends CLionComponent
    @filter = (el) -> el._name ~= 'component' or el._attr.name == 'RunManager'

    new: (...) =>
        super ...

        @nodes = { }
        @existing = {}
        for subdom in *(@dom._children or {})
            if subdom._attr
                name = subdom._attr[CLionConfiguration.Attrib.Name]
                target_name = subdom._attr[CLionConfiguration.Attrib.TargetName]
                if name and not @existing[name] and target_name
                    @existing[name] = target_name
                elseif name and not @nodes[name]
                    @nodes[name] = subdom

    selected: => @dom._attr.selected

    removeall: (targets) =>
        new_children = {}
        for subdom in *(@dom._children or {})
            found = false

            if subdom._attr
                target_name = subdom._attr[CLionConfiguration.Attrib.TargetName]

                for target in *(targets or {})
                    if target_name == target
                        found = true
                        break

            elseif subdom._name == 'list'
                found = true

            -- Don't add found items
            table.insert new_children, subdom unless found

        removed = #@dom._children - #new_children
        @dom._children = new_children
        removed

    configurations: =>
        result = { }
        for node in *(@dom._children or { })
            if node._type == 'ELEMENT' and node._name == 'configuration'
                table.insert result, CLionConfiguration node
        result
    
    add_configuration: (info) =>
        if not @existing[info.long_name] or @existing[info.long_name] == info.target
            table.insert @dom._children, CLionConfiguration\create info.project, info.target, info

    add_node: (info) =>
        if @nodes[info._attr.name]
            @nodes[info._attr.name]._children = info._children
        else 
            table.insert @dom._children, info

    sort_configurations: =>
        items = {}
        config_types = {
            ['CLionNativeAppRunConfigurationType']:'Native Application'
            ['ShConfigurationType']:'Shell Script'
        }

        for cdom in *(@dom._children or {})
            continue unless cdom._attr
            if config_name = cdom._attr[CLionConfiguration.Attrib.Name]
                config_type = cdom._attr[CLionConfiguration.Attrib.Type]
                table.insert items, XMLNode\element 'item', itemvalue:"#{config_types[config_type]}.#{config_name}"

        -- Create the list entry
        listdom = @find 'list' 
        unless listdom
            listdom = XMLNode\element 'list' 
            table.insert @dom._children, listdom
        listdom._children = items

class CLionProject extends XMLNode
    new: (dom) =>
        unless dom
            dom = XMLNode\element 'project', version:'4'
        super dom

    run_manager: =>
        dom = @\get 'project.component', filter:CLionRunManager.filter
        dom._attr = name:'RunManager'
        CLionRunManager dom


class CLionExternalBuildManager extends XMLNode
    @filter = (el) -> el._name ~= 'component' or el._attr.name == 'CLionExternalBuildManager'

    new: (...) =>
        super ...

        -- Always clear this list?
        @dom._children = { }
        @added = { }

    add_target: (info) =>
        return if @added[info.build_target]
        @added[info.build_target] = true

        target_tool = XMLNode\element 'tool', actionId:"Tool_IBT IceShard_ibt-#{info.build_target}"
        target_build = XMLNode\element 'build', type:'TOOL'
        target_build._children = {target_tool}
        target_configuration = XMLNode\element 'configuration', id:uuid.v4!, name:info.build_target
        target_configuration._children = {target_build}
        target = XMLNode\element 'target', id:uuid.v4!, name:info.build_target, defaultType:'TOOL'
        target._children = {target_configuration}

        table.insert @dom._children, target

class CLionCustomTargets extends XMLNode
    external_build_manager: =>
        dom = @\get 'project.component', filter:CLionExternalBuildManager.filter
        dom._attr = name:'CLionExternalBuildManager'
        CLionExternalBuildManager dom


class CLionExternalTools extends XMLNode
    new: (...) =>
        super ...
        @dom = _type:'ELEMENT', _name:'toolSet', _attr:{name:"IBT IceShard"} unless @dom
        @dom._children = { }
        @added = { }

    add_tool: (target, tool) =>
        return if @added[target]
        @added[target] = true

        option_command = XMLNode\element 'option', name:'COMMAND', value:"./#{tool.script}"
        option_params = XMLNode\element 'option', name:'PARAMETERS', value:"build #{target}"
        option_workdir = XMLNode\element 'option', name:'WORKING_DIRECTORY', value:tool.working_dir
        exec = XMLNode\element 'exec'
        exec._children = {option_command, option_params, option_workdir}
        tool = XMLNode\element 'tool', 
            name:"ibt-#{target}"
            description:"Build action for given target"
            showInMainMenu:"false"
            showInEditor:"false"
            showInProject:"false"
            showInSearchPopup:"false"
            disabled:"false"
            useConsole:"true"
            showConsoleOnStdOut:"false"
            showConsoleOnStdErr:"false"
            synchronizeAfterRun:"true"
        tool._children = {exec}

        table.insert @dom._children, tool

class CLionProjectGen
    new: (@project, @config, @fbuild) =>
        @log = Logger\create LogCategory 'clion' 
        @clion_dir = Path\join project.workspace_dir, ".idea"
        @clion_wksfile = Path\join @clion_dir, "workspace.xml"
        @clion_customtargets = Path\join @clion_dir, "customTargets.xml"
        @clion_externaltools = Path\join @clion_dir, "tools", "IBT IceShard.xml"

    generate: (opts) =>
        clean = true
        clean or= not File\exists @clion_wksfile
        @log\iinfo clean, "Generating all required files in directory: #{@clion_dir}"

        -- Generate all necessary files
        targets = @\generate_workspace opts
        @\generate_custom_targets targets
        @\generate_external_tools targets

        @config\close!

    generate_workspace: (opts = {}) =>
        -- Load the existing workspace file
        @log\verbose "Loading workspace file from path: #{@clion_wksfile} (clean: #{opts.clean and 'true' or 'false'})"
        project = CLionProject!
        unless opts.clean
            if wskxml = File\load @clion_wksfile
                @log\debug "Decoding file contents: #{type wskxml}"
                wksxml_decoded = XML\decode wskxml
                @log\debug "Decoded file contents: #{type wksxml_decoded}"
                project = CLionProject wksxml_decoded

        -- Get the run-manager component
        @log\verbose "Accessing run-manager component..."
        @run_manager = project\run_manager!

        @log\debug "Reading target information..."
        run_targets = @config\section 'run_targets', 'array'
        build_targets = @config\section 'build_targets', 'array'
        @log\verbose "Removing existing ibt targets..."

        -- Remove existing run targets
        removed_targets = @run_manager\removeall run_targets
        @log\verbose "Removed #{removed_targets} targets..."

        -- Move over all build targets and create configurations
        switches_test = {}
        switches = {}
        targets = {}
        @log\verbose "Updating #{#run_targets} targets..."
        for target in *(run_targets or {})
            section = @config\section target, 'map'
            section.target = target
            section.build_target = "all-#{section.pipeline}-#{section.config}"
            section.project = 'iceshard'
            section.long_name = "#{section.name}-#{section.pipeline}-#{section.config}"
            table.insert targets, section

            -- TODO: Create build targets for non-existing run targetss
            @log\verbose "Updating: #{target}"
            @run_manager\add_configuration section

            unless switches_test["#{section.pipeline}-#{section.config}"]
                switches_test["#{section.pipeline}-#{section.config}"] = true
                switch_config = @\generate_compdb_switch section
                table.insert switches, switch_config

        for _, switch_config in pairs switches
            @run_manager\add_node switch_config

        -- Generate the new workspace file
        @run_manager\sort_configurations!
        File\save @clion_wksfile, XML\encode project.dom
        return targets, project

    generate_compdb_switch: (section) => 
        config = XMLNode\element 'configuration', name:"Switch to #{section.pipeline}-#{section.config} (IceShard)", type:"ShConfigurationType"
        config._children = {
            XMLNode\element 'option', name:'EXECUTE_SCRIPT_FILE', value:'false'
            XMLNode\element 'option', name:'EXECUTE_IN_TERMINAL', value:'false'
            XMLNode\element 'option', name:'SCRIPT_TEXT', value:"./ice.sh exec fbuild -config ./build/fbuild.bff -compdb all-#{section.pipeline}-#{section.config}"
            XMLNode\element 'option', name:'SCRIPT_WORKING_DIRECTORY', value:'$PROJECT_DIR$'
            XMLNode\element 'option', name:'SCRIPT_PATH', value:'./ice.sh'
            XMLNode\element 'option', name:'SCRIPT_OPTIONS', value:"exec fbuild -config ./build/fbuild.bff -compdb all-#{section.pipeline}-#{section.config}"
            XMLNode\element 'option', name:'INDEPENDENT_SCRIPT_PATH', value:'true'
            XMLNode\element 'option', name:'INDEPENDENT_SCRIPT_WORKING_DIRECTORY', value:'true'
            XMLNode\element 'option', name:'INDEPENDENT_INTERPRETER_PATH', value:'true'
            XMLNode\element 'option', name:'INTERPRETER_PATH', value:'/bin/bash'
            XMLNode\element 'option', name:'INTERPRETER_OPTIONS', value:''
            XMLNode\element 'envs'
            XMLNode\element 'method', v:'2'
        }
        config

    generate_custom_targets: (targets) =>
        -- Load the existing custom targets file
        custom = CLionCustomTargets!
        if targetsxml = File\load @clion_customtargets
            custom = CLionCustomTargets XML\decode targetsxml

        build_manager = custom\external_build_manager!

        -- Generate targets
        -- TODO: Move the setup to a different location
        math.randomseed os.time!
        uuid.set_rng (n) ->
            result = ""
            for i=1,n 
                result ..= string.char math.random 0,255
            result ..= string.char 0
            result

        -- Create build targets
        for target in *targets
            build_manager\add_target target

        File\save @clion_customtargets, XML\encode custom.dom, decl:XML\decl!

    generate_external_tools: (infos) =>
        -- Load the existing custom targets file
        tools = CLionExternalTools!
        if toolsxml = File\load @clion_externaltools
            tools = CLionExternalTools XML\decode toolsxml

        -- Create tool targets
        for info in *infos
            tools\add_tool info.build_target, script:@project.script, working_dir:@project.workspace_dir

        File\save @clion_externaltools, XML\encode tools.dom, decl:XML\decl!

{ :CLionProjectGen }