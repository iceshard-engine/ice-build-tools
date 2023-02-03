import Exec, Where from require "ice.tools.exec"
import Json from require "ice.util.json"

import File, Dir from require "ice.core.fs"
import Log from require "ice.core.logger"
import Match, Validation from require "ice.core.validation"

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
                Log\warning "No results for query: '#{cmd}'!" unless #lines > 0

                results[property] = lines[1]
            return results

        elseif args.format == 'json'
            return Json\decode @\capture cmd .. " -format json"

        else
            @\run cmd

        -- Return empty table
        { }

class VStudio extends Exec
    new: => super (VSWhere!\find latest:true, properties:{ 'productPath' }).productPath

    start: (args = {}) =>
        if Validation\check os.iswindows, "The 'VStudio' tool is available only on Windows!"
            cmd = ""
            cmd ..= " #{args.open}" if (File\exists args.open) or (Dir\exists args.open)

            -- Use 'start' to not block on the terminal
            os.execute "start #{cmd}"

class VSCode extends Exec
    new: (path) => super path or Where\path "code"

    start: (args = {}) =>
        success, errs = Match\table args, open:{ fn:Dir\exists, errmsg:(p) -> "Trying to open VSCode for invalid directory '#{p}'" }
        Log\error err for err in *errs

        if success
            cmd = ""
            cmd ..= " #{args.open}"

            -- Use 'start' to not block on the terminal
            Log\debug "[VSCode] Executing command '\"#{@exec}\" #{cmd}'"
            os.execute "\"#{@exec}\" #{cmd}"

{ :VSWhere, :VStudio, :VSCode }
