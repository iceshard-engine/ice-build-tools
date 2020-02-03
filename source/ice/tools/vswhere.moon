import Exec from require "ice.tools.exec"

class VSWhere extends Exec
    new: => super "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe"

    help: => @\run "/?"

    find: (args = {}) =>
        cmd = ""
        cmd ..= " -version #{args.version}" if args.version
        cmd ..= " -requires #{requirement}" for requirement in *(args.requires or {})
        cmd ..= " -products #{args.products}" if args.products
        cmd ..= " -latest" if args.latest

        results = { }

        unless args.properties and #args.properties > 0
            @\run cmd

        else
            for property in *args.properties
                lines = @\capture cmd .. " -format value -property #{property}"
                error "ERROR: No results for query: '#{cmd}'!" unless #lines > 0

                results[property] = lines[1]
        results

{ :VSWhere }
