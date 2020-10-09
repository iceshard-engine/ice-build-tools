import Exec, Where from require "ice.tools.exec"

class FastBuild extends Exec
    new: (path) => super path or (os.iswindows and Where\path "fbuild.exe") or Where\path "fbuild"

    help: => @\run '-help'

    cache: (args) =>
        error "ERROR: Missig cache action!" unless args.action
        error "ERROR: Unknown cache action '#{args.action}'" unless args.action == 'info' or args.action == 'trim'

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

    build: (args) =>
        cmd = string.format " %s", (args and args.target) or "all"
        cmd ..= " -config #{args.config}" if args.config
        cmd ..= " -fastcancel"
        cmd ..= " -nosummaryonerror" unless args.summary ~= nil
        cmd ..= " -summary" if args.summary
        cmd ..= " -report" if args.report
        cmd ..= " -monitor" if args.monitor
        cmd ..= " -clean" if args.clean
        cmd ..= " -dist" if args.distributed
        cmd ..= " -cache" if args.cache
        cmd ..= " -verbose" if args.verbose

        @\run cmd

{ :FastBuild }
