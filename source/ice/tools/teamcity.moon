import Logger, Sink, LogLevel, Log from require "ice.core.logger"

is_enabled = false
is_string = (v) -> (type v) == "string"

make_service_message = (type, params) ->
    message_params = table.concat ["#{key}='#{value}'" for key, value in pairs (params or {})], ' '
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
        new: => super io.stdout, LogLevel.Info, nocolors:true, noheader:true

        write: (level, category, message) =>
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
        is_enabled = true
        Logger\register_sink 'stdout', MessageSink!

    @compilation_block = (opts, fn) =>
        return fn! unless  is_string opts.name

        service_message.compilationStarted compiler:opts.compiler
        fn!
        service_message.compilationFinished compiler:opts.compiler

    @process_block = (opts, fn) =>
        return fn! unless is_string opts.name

        service_message.blockOpened name:opts.name, flowId:opts.flowid, description:opts.description
        fn!
        service_message.blockClosed name:opts.name

{ :TeamCity }
