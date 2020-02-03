import Exec from require "ice.tools.exec"

class VSWhere extends Exec
    new: => super "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe"

    help: => @\run "/?"

    find: (options = {}) =>
        cmd = ""
        cmd ..= " -version #{options.version}" if options.version
        cmd ..= " -requires #{requirement}" for requirement in *(options.requires or {})
        cmd ..= " -products #{options.products}" if options.products
        cmd ..= " -latest" if options.latest

        results = { }

        unless options.properties and #options.properties > 0
            @\run cmd

        else
            for property in *options.properties
                lines = @\capture cmd .. " -format value -property #{property}"
                error "ERROR: No results for query: '#{cmd}'!" unless #lines > 0

                results[property] = lines[1]
        results

{ :VSWhere }
