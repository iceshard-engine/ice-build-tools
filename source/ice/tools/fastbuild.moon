import Exec, Where from require "ice.tools.exec"
import Validation from require "ice.core.validation"
import Log from require "ice.core.logger"
import Dir from require "ice.core.fs"

class FastBuild extends Exec
    new: (path) => super path or (os.iswindows and Where\path "fbuild.exe") or Where\path "fbuild"

    help: => @\run '-help'

    cache: (args) =>
        return unless Validation\ensure args.action, "Missig cache action parameter!"
        return unless Validation\ensure args.action == 'info' or args.action == 'trim', "Unknown cache action '#{args.action}'"

        cmd = ""
        cmd ..= " -config #{args.config}" if args.config
        cmd ..= " -cache#{args.action}"
        cmd ..= " 5000" unless args.trim_size
        cmd ..= " #{args.trim_size}" if args.trim_size

        @\run cmd

    cache_info: (args) =>
        @\cache action:'info', config:args.config

    cache_trim: (args) =>
        @\cache action:'trim', config:args.config, trim_size:args.trim_size

    list_targets: (args) =>
        cmd = ""
        cmd ..= " -config #{args.config}" if args.config
        cmd ..= " -showtargets"

        @\capture cmd

    compdb: (args) =>
        -- Fixup the passed args
        args.compilation_database = true
        @build_from args.output, args

    build_from: (output, args) =>
        return unless Dir\create output
        args.output = nil

        Dir\enter output, ->
            @build args
        true

    build: (args) =>
        cmd = string.format " %s", (args and args.target) or "all"
        cmd ..= " -config #{args.config}" if args.config
        cmd ..= " -nosummaryonerror" if args.nosummaryonerror
        cmd ..= " -summary" if args.summary
        cmd ..= " -report" if args.report
        cmd ..= " -monitor" if args.monitor
        cmd ..= " -clean" if args.clean
        cmd ..= " -dist" if args.distributed
        cmd ..= " -cache" if args.cache
        cmd ..= " -verbose" if args.verbose
        cmd ..= " -compdb" if args.compilation_database or args.compdb
        Log\verbose "FBuild args: #{cmd}"

        result = @\run cmd
        Validation\ensure result == 0, "Failed FASTBuild build with targets: #{(args and args.target) or 'all'}"
        result

{ :FastBuild }
