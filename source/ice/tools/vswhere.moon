import Exec from require "ice.tools.exec"
import Json from require "ice.util.json"

class VSWhere extends Exec
    new: => super "C:\\Program Files (x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe"

    help: => @\run "/?"

    find: (args = {}) =>
        cmd = ""
        cmd ..= " -version #{args.version}" if args.version
        cmd ..= " -requires #{requirement}" for requirement in *(args.requires or {})
        cmd ..= " -products #{args.products}" if args.products
        cmd ..= " -latest" if args.latest
        cmd ..= " -all" if args.all

        if args.properties and #args.properties > 0

            results = { }
            for property in *args.properties
                lines = @\lines cmd .. " -format value -property #{property}"
                error "ERROR: No results for query: '#{cmd}'!" unless #lines > 0

                results[property] = lines[1]
            return results

        elseif args.format == 'json'
            return Json\decode @\capture cmd .. " -format json"

        else
            @\run cmd

        true

class VStudio extends Exec
    new: => super (VSWhere!\find latest:true, properties:{ 'productPath' }).productPath

    start: (args = {}) =>
        cmd = ""
        cmd ..= " #{args.open}" if (os.isfile args.open) or (os.isdir  args.open)
        @\run cmd

{ :VSWhere, :VStudio }
