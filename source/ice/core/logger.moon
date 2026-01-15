
class Colors
    class Color
        new: (num) =>
            @str = "#{string.char(27)}[#{num}m" if true else ""

        -- ToString conversion
        __tostring: => @str

    @Reset = Color 0
    @Black = Color 30
    @Red = Color 31
    @Green = Color 32
    @Yellow = Color 33
    @Blue = Color 34
    @Magenta = Color 35
    @Cyan = Color 36
    @White = Color 37

class LogCategory
    new: (tag) => @tag = tag\upper!

    -- Default global category
    @Global = { tag:'' }

class LogLevel
    @Debug = { tag:'DBG', prio:1000, color:Colors.Magenta }
    @Verbose = { tag:'VER', prio:500, color:Colors.White }
    @Info = { tag:'INF', prio:100, color:Colors.Cyan }
    @Warning = { tag:'WRN', prio:10, color:Colors.Yellow }
    @Error = { tag:'ERR', prio:1, color:Colors.Red }
    @Critical = { tag:'CRT', prio:0, color:Colors.Red }

    @get = (val, default) =>
        return default unless val
        return val if (val.tag and val.prio)
        return @[val] or default

class VoidFile
    write: =>

class MemoryFile
    write: (value) => value -- Just return the value

global_header_size = 0

class Sink
    new: (@file, @level, config) =>
        @fn = ->
        unless config.quiet
            @file = io.open config.file, config.mode if config.file
            @fn = @file\write

        fmt_full = (level, category, msg_lines) ->
            header_size = (#level.tag + 2 + 1 + #category.tag)
            global_header_size = header_size if header_size > global_header_size
            spacing = string.rep ' ', (global_header_size - header_size) + (category.tag == '' and 0 or 1)

            sep = '>'
            for msg in msg_lines\gmatch '([^\n]+)\n?'
                @.fn string.format "%s#{spacing}#{sep} #{msg}\n", "#{level.color}[#{level.tag}]#{Colors.Reset} #{category.tag}"
                sep = '|'

        fmt_nocolors = (level, category, msg_lines) ->
            header_size = (#level.tag + 2 + 1 + #category.tag)
            global_header_size = header_size if header_size > global_header_size
            spacing = string.rep ' ', (global_header_size - header_size) + (category.tag == '' and 0 or 1)

            sep = '>'
            for msg in msg_lines\gmatch '([^\n]+)\n?'
                @.fn string.format "%s#{spacing}#{sep} #{msg}\n", "[#{level.tag}] #{category.tag}"
                sep = '|'

        fmt_noheader = (level, category, msg) -> @.fn "#{level.color}#{msg}#{Colors.Reset}\n"
        fmt_noheader_nocolors = (level, category, msg) -> @.fn "#{msg}\n"

        @fmt = fmt_full
        @fmt = fmt_noheader if config.noheader
        @fmt = fmt_nocolors if config.nocolors
        @fmt = fmt_noheader_nocolors if config.noheader and config.nocolors

        @level = LogLevel\get config.level if config.level
        @max_level = LogLevel.Critical
        @max_level = LogLevel\get config.max_level if config.max_level

    write: (level, category, msg) =>
        @.fmt level, category, msg if (level.prio <= @level.prio) and (level.prio >= @max_level.prio)

    -- Function-like interface
    __call: (level, category, msg) => @\write level, category, msg

deep_copy = (t) ->
    result = { }
    for k, v in pairs t
        if (type v) == 'table' and v.__class == nil
            result[k] = deep_copy v
        else
            result[k] = v
    result

global_instance = { }

class Log
class Logger
    new: (@category, args = {}, force_raw) =>
        assert @category and @category.tag != nil, "Logger objects require a LogCategory object on the first parameter!"

        args.stdout = args.stdout or { }
        args.stdout.max_level = args.stdout.max_level or LogLevel.Warning
        args.stderr = args.stderr or { }
        args.log = args.log or { }
        args.log.mode = 'a+'
        args.log.mode = 'w+' if args.log.reset
        args.log.nocolors = not args.log.forcecolors
        args.logfile = args.logfile or args.log.file
        args.logfile = io.open args.logfile, args.log.mode if (type args.logfile) == 'string'
        args.logfile = VoidFile! unless args.logfile
        args.log.file = nil

        -- Apply shared config values
        shared_properties = {
            'nocolors': true
            'noheader': true
        }

        for prop, value in pairs args
            continue unless shared_properties[prop]

            args.log[prop] = args.log[prop] or value
            args.stdout[prop] = args.stdout[prop] or value
            args.stderr[prop] = args.stderr[prop] or value

        if force_raw
            args.stdout.nocolors = true
            args.stdout.noheader = true
            args.stderr.nocolors = true
            args.stderr.noheader = true
            args.log.nocolors = true
            args.log.noheader = true

        -- Create the sinks
        @outputs = {
            stdout:(Sink io.stdout, LogLevel.Info, args.stdout)
            stderr:(Sink io.stderr, LogLevel.Error, args.stderr)
            log:(Sink args.logfile, LogLevel.Info, args.log)
        }

        @output_format = Sink MemoryFile!, LogLevel.Debug, args.format or { noheader:true, nocolors:true }


    log: (msg, category, level, ...) =>
        -- Format the message
        msg = string.format msg, ...

        -- Send it to each sink
        sink level, category, msg for _, sink in pairs @outputs

    format: (msg, level, ...) =>
        @.output_format (LogLevel\get level, LogLevel.Info), @category, string.format msg, ...
    debug: (msg, ...) => @\log msg, @category, LogLevel.Debug, ...
    verbose: (msg, ...) => @\log msg, @category, LogLevel.Verbose, ...
    info: (msg, ...) => @\log msg, @category, LogLevel.Info, ...
    warning: (msg, ...) => @\log msg, @category, LogLevel.Warning, ...
    error: (msg, ...) => @\log msg, @category, LogLevel.Error, ...

    @init = (args, raw_logger) =>
        return if global_instance.logger ~= nil

        -- If a logger instance is passed we assign it directly
        if (type args) == Logger
            global_instance.logger = args
            global_instance.raw_logger = raw_logger or args
            Log.raw = global_instance.raw_logger
        else
            global_instance.logger = Logger LogCategory.Global, args
            args.logfile = global_instance.logger.outputs.log.file
            global_instance.init_args = deep_copy args
            global_instance.raw_logger = Logger LogCategory.Global, args, true
            Log.raw = global_instance.raw_logger

    @create = (category, args) => Logger category, args or global_instance.init_args

    @register_sink = (id, sink) =>
        global_instance.logger.outputs[id] = sink

class Log
    @format = (msg, level, ...) => global_instance.get!\format msg, level, ...
    @debug = (msg, ...) => global_instance.get!\debug msg, ...
    @verbose = (msg, ...) => global_instance.get!\verbose msg, ...
    @info = (msg, ...) => global_instance.get!\info msg, ...
    @warning = (msg, ...) => global_instance.get!\warning msg, ...
    @error = (msg, ...) => global_instance.get!\error msg, ...

global_instance.get = ->
    Logger\init {} unless global_instance.logger
    global_instance.logger

{ :Log, :Logger, :LogCategory, :LogLevel, :Sink }
