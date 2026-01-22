import Logger, Sink, LogLevel, Log from require "ice.core.logger"
import Validation from require "ice.core.validation"
import Exec, Where from require "ice.tools.exec"

teamcity_is_enabled = false
is_number = (v) -> (type v) == "number"
is_string = (v) -> (type v) == "string"
is_string_n = (v, l) -> (type v) == "string" and #v <= l
is_function = (v) -> (type v) == "function"
is_string_or_number = (v) -> (is_string v) or (is_number v)

make_value = (value) ->
    replacements = { "'":"|'", '\n': '|n', '\r': '|r', '|': '||', '[': '|[', ']': '|]' }
    value\gsub "[%'%|%[%]\n\r]", (v) -> replacements[v]

make_service_message = (type, params) ->
    message_params = table.concat ["#{key}='#{make_value value}'" for key, value in pairs (params or {}) when is_string_or_number value], ' '
    "##teamcity[#{type} #{message_params or ''}]\n"

defined_inspections = {}
service_message = {
    message: (params) -> io.stdout\write make_service_message 'message', params
    blockOpened: (params) -> io.stdout\write make_service_message 'blockOpened', params
    blockClosed: (params) -> io.stdout\write make_service_message 'blockClosed', params
    compilationStarted: (params) -> io.stdout\write make_service_message 'compilationStarted', params
    compilationFinished: (params) -> io.stdout\write make_service_message 'compilationFinished', params
    buildProblem: (params) -> io.stdout\write make_service_message 'buildProblem', params
    testSuiteStarted: (params) -> io.stdout\write make_service_message 'testSuiteStarted', params
    testSuiteFinished: (params) -> io.stdout\write make_service_message 'testSuiteFinished', params
    testStarted: (params) -> io.stdout\write make_service_message 'testStarted', params
    testFinished: (params) -> io.stdout\write make_service_message 'testFinished', params
    inspectionType: (params) -> io.stdout\write make_service_message 'inspectionType', params
    inspection: (params) -> io.stdout\write make_service_message 'inspection', params
}

class TeamCity
class TeamCityExec extends Exec
    new: (@scope_name, ...) => super ...
    run: (arguments) => TeamCity\process_block name:@scope_name, description:"Executing: #{arguments}", ->
        super arguments
    capture: (arguments) => TeamCity\process_block name:@scope_name, description:"Capturing: #{arguments}", ->
        super arguments
    lines: (arguments) => TeamCity\process_block name:@scope_name, description:"Capturing (Lines): #{arguments}", ->
        super arguments

class TeamCity
    @Exec = TeamCityExec

    class MessageSink extends Sink
        new: (file, level, max_level) => super file, level, nocolors:true, noheader:true, :max_level

        write: (level, category, message) =>
            -- Filter out messages based on level
            return unless (level.prio <= @level.prio) and (level.prio >= @max_level.prio)

            -- replacements = { "'":"|'", '\n': '|n', '\r': '|r', '|': '||', '[': '|[', ']': '|]' }
            -- message = message\gsub "[%'%|%[%]\n\r]", (v) -> replacements[v]

            if level == LogLevel.Info
                @.fn make_service_message 'message', text:message, status:'NORMAL'
            elseif level == LogLevel.Warning
                @.fn make_service_message 'message', text:message, status:'WARNING'
            elseif level == LogLevel.Error
                @.fn make_service_message 'message', text:message, status:'FAILURE'
            elseif level == LogLevel.Critical
                @.fn make_service_message 'message', text:message, status:'ERROR'

    @info = (message) => Log\info message if teamcity_is_enabled
    @warning = (message) => Log\warning message if teamcity_is_enabled
    @error = (message) => Log\error message if teamcity_is_enabled

    @enable = =>
        teamcity_is_enabled = true
        -- Register for both stderr and stdout
        Logger\register_sink 'stdout', MessageSink io.stdout, LogLevel.Info, LogLevel.Info
        Logger\register_sink 'stderr', MessageSink io.stderr, LogLevel.Warning, LogLevel.Critical

    @inspection_type = (opts) =>
        return -> unless teamcity_is_enabled

        Validation\assert (is_string_n opts.id, 255), "Inspection type requires 'id' to be of type 'string[0..255]', got '#{type opts.id}'"
        Validation\assert (is_string_n opts.name, 255), "Inspection type requires 'name' to be of type 'string[0..255]', got '#{type opts.name}'"
        Validation\assert (is_string_n opts.category, 255), "Inspection type requires 'category' to be of type 'string[0..255]', got '#{type opts.category}'"
        Validation\assert (opts.severity == nil or is_string_n opts.severity, 255), "Inspection type requires optional 'severity' to be of type 'string[0..255]', got '#{type opts.severity}'"

        -- Improve the description.
        opts.description = "<h2>#{opts.description.title}</h2><p>#{opts.description.content}</p>" if (is_string opts.description.title) and (is_string opts.description.content)
        opts.description = "<html><body>#{opts.description}</body></html>" if is_string opts.description
        Validation\assert (is_string_n opts.description, 4000), "Inspection type requires 'description' to be of type 'string[0..4000]', got '#{type opts.description}'"

        -- Store the inspection type details
        defined_inspections[opts.id] = opts
        typeid = opts.id
        severity = opts.severity

        -- Remove parameters not used during type definition and report the inspection type
        opts.severity = nil
        service_message.inspectionType opts

        (iopts) => TeamCity\inspection typeid:typeid, file:iopts.file, line:iopts.line, message:iopts.message, severity:severity

    @inspection = (opts) =>
        return unless teamcity_is_enabled

        -- Fix typeId field name
        opts.typeId = opts.typeid
        opts.typeid = nil

        Validation\assert (is_string_n opts.typeId, 255), "Inspection requires 'typeid' to be of type 'string[0..255]', got '#{type opts.typeId}'"
        Validation\assert (is_string_n opts.file, 4000), "Inspection requires 'file' to be of type 'string[0..4000]', got '#{type opts.file}'"

        insp_type = defined_inspections[opts.typeId]
        Validation\assert (insp_type ~= nil), "Inspection '#{opts.typeId}' is undefined! Define the inspection type with 'TeamCity\\inspection_type' first!"

        -- Prepare optional parameters
        -- opts.message = "<html><body>#{opts.message}</body></html>" if is_string opts.message
        opts.severity = opts.severity or insp_type.severity

        -- Additional checks
        Validation\assert (opts.message == nil or is_string_n opts.message, 4000), "Inspection requires optional 'message' to be of type 'string[0..4000]', got '#{type opts.message}'"
        Validation\assert (opts.severity == nil or is_string_n opts.severity, 255), "Inspection requires optional 'severity' to be of type 'string[0..255]', got '#{type opts.severity}'"
        Validation\assert (opts.line == nil or is_number opts.line), "Inspection requires optional 'line' to be of type 'integer', got '#{type opts.line}'"

        -- Final touches
        opts.SEVERITY = opts.severity
        opts.severity = nil

        -- Report the inspection
        service_message.inspection opts

    @build_problem = (opts) =>
        Validation\assert (is_string_n (opts.description or opts.desc), 4000), "BuildProblem requires 'description' to be of type 'string[0..4000]', got: '#{type (opts.description or opts.desc)}'"
        Validation\assert (opts.identity == nil or is_string_n opts.identity, 60), "BuildProblem requires optional 'identity' to be of type 'string[0..60]', got: '#{type (opts.identity)}'"

        service_message.buildProblem opts

    -- @test_suite = (opts, fn) =>
    --     return unless Validation\ensure (is_function fn), "Expected 'function' as second argument to 'compile_block' got '#{type fn}'"
    --     return fn! unless teamcity_is_enabled

    --     service_message.testSuiteStarted compiler:opts.compiler
    --     result = fn!
    --     service_message.testSuiteFinished compiler:opts.compiler
    --     result

    -- @test = (opts, fn) =>
    --     return unless Validation\ensure (is_function fn), "Expected 'function' as second argument to 'compile_block' got '#{type fn}'"
    --     return fn! unless teamcity_is_enabled

    --     service_message.testStarted compiler:opts.compiler
    --     result = fn!
    --     service_message.testFinished compiler:opts.compiler
    --     result

    @compile_block = (opts, fn) =>
        return unless Validation\ensure (is_function fn), "Expected 'function' as second argument to 'compile_block' got '#{type fn}'"
        return fn! unless teamcity_is_enabled

        service_message.compilationStarted compiler:opts.compiler
        result = fn!
        service_message.compilationFinished compiler:opts.compiler
        result

    @process_block = (opts, fn) =>
        return unless Validation\ensure (is_function fn), "Expected 'function' as second argument to 'process_block' got '#{type fn}'"
        return fn! unless teamcity_is_enabled
        return unless Validation\ensure (is_string opts.name), "Expected string value 'name' for a process block, got '#{type opts.name}'"

        service_message.blockOpened name:opts.name, flowId:opts.flowid, description:opts.description
        result = fn!
        service_message.blockClosed name:opts.name
        result

{ :TeamCity }
