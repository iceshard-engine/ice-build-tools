import Exec, Where from require "ice.tools.exec"

class FastBuild extends Exec
    new: (path) => super path or Where\path "fbuild.exe"

    help: => @\run '-help'

    cache: (args) =>
        error "ERROR: Missig cache action!" unless args.action
        error "ERROR: Unknown cache action '#{args.action}'" unless args.action == 'info' or args.action == 'trim'

        cmd = ""
        cmd ..= " -script #{args.script}" if args.script
        cmd ..= " -cache#{args.action}"
        cmd ..= " 5000" unless args.trim_size
        cmd ..= " #{args.trim_size}" if args.trim_size

        @\run cmd

    cache_info: (args) =>
        @\cache action:'info', script:args.script

    cache_trim: (args) =>
        @\cache action:'trim', script:args.script, trim_size:args.trim_size

    build: (args) =>
        cmd = string.format " %s", (args and args.target) or "all"
        cmd ..= " -script #{args.script}" if args.script
        cmd ..= " -fastcancel"
        cmd ..= " -nosummaryonerror" unless args.summary
        cmd ..= " -summary" if args.summary
        cmd ..= " -report" if args.report
        cmd ..= " -monitor" if args.monitor
        cmd ..= " -clean" if args.clean
        cmd ..= " -dist" if args.distributed
        cmd ..= " -cache" if args.cache
        cmd ..= " -verbose" if args.verbose

        @\run cmd

{ :FastBuild }
