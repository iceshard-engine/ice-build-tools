import Logger, Sink, LogLevel, Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

teamcity_is_enabled = false
is_string = (v) -> (type v) == "string"
is_function = (v) -> (type v) == "function"

make_service_message = (type, params) ->
    message_params = table.concat ["#{key}='#{value}'" for key, value in pairs (params or {}) when is_string value], ' '
    "##teamcity[#{type} #{message_params or ''}]\n"

service_message = {
    message: (params) -> io.stdout\write make_service_message 'message', params
    blockOpened: (params) -> io.stdout\write make_service_message 'blockOpened', params
    blockClosed: (params) -> io.stdout\write make_service_message 'blockClosed', params
    compilationStarted: (params) -> io.stdout\write make_service_message 'compilationStarted', params
    compilationFinished: (params) -> io.stdout\write make_service_message 'compilationFinished', params
}


class TeamCity
    class MessageSink extends Sink
        new: (file, level, max_level) => super file, level, nocolors:true, noheader:true, :max_level

        write: (level, category, message) =>
            -- Filter out messages based on level
            return unless (level.prio <= @level.prio) and (level.prio >= @max_level.prio)

            replacements = { "'":"|'", '\n': '|n', '\r': '|r', '|': '||', '[': '|[', ']': '|]' }
            message = message\gsub "[%'%|%[%]\n\r]", (v) -> replacements[v]

            if level == LogLevel.Info
                @.fn make_service_message 'message', text:message, status:'NORMAL'
            elseif level == LogLevel.Warning
                @.fn make_service_message 'message', text:message, status:'WARNING'
            elseif level == LogLevel.Error
                @.fn make_service_message 'message', text:message, status:'FAILURE'
            elseif level == LogLevel.Critical
                @.fn make_service_message 'message', text:message, status:'ERROR'

    @enable = =>
        teamcity_is_enabled = true
        -- Register for both stderr and stdout
        Logger\register_sink 'stdout', MessageSink io.stdout, LogLevel.Info, LogLevel.Info
        Logger\register_sink 'stderr', MessageSink io.stderr, LogLevel.Warning, LogLevel.Critical

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
