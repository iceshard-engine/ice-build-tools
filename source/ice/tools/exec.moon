require "ice.util.os"

import Log from require "ice.core.logger"
import File from require "ice.core.fs"

class Exec
    new: (@exec) =>
        Log\warning "#{@exec} does not exist!" unless File\exists @exec

    run: (arguments) =>
        os.execute "\"#{@exec}\" #{arguments or ''}"

    capture: (arguments) =>
        result = ""
        if proc = io.popen "\"#{@exec}\" #{arguments or ''}"
            result = proc\read '*a'
            proc\close!
        result

    lines: (arguments) =>
        result = { }
        if proc = io.popen "\"#{@exec}\" #{arguments or ''}"
            for line in proc\lines!
                table.insert result, line
            proc\close!
        result


class PowerShell
    new: (@exec) =>
    run: (arguments, attrib) =>
        cmd = "powershell.exe \"& {#{@exec} #{arguments or ''}}\""
        if attrib
            cmd = "powershell.exe \"& {(#{@exec} #{arguments or ''}).#{attrib}}\""

        os.execute cmd

    capture: (arguments, attrib) =>
        cmd = "powershell.exe \"& {#{@exec} #{arguments or ''}}\""
        if attrib
            cmd = "powershell.exe \"& {(#{@exec} #{arguments or ''}).#{attrib}}\""

        result = ""
        if proc = io.popen cmd
            result = proc\read '*a'
            proc\close!
        result

    lines: (arguments, attrib) =>
        cmd = "powershell.exe \"& {#{@exec} #{arguments or ''}}\""
        if attrib
            cmd = "powershell.exe \"& {(#{@exec} #{arguments or ''}).#{attrib}}\""

        result = { }
        if proc = io.popen cmd
            for line in proc\lines!
                table.insert result, line
            proc\close!
        result


class Where extends Exec
    @exec = os.iswindows and 'where.exe' or 'which'
    @path: (name, err_log) =>
        args = name
        args ..= " 2>>#{err_log}" if err_log

        if os.iswindows
            ((PowerShell "Get-Command")\lines name, "Path")[1]
        else
            (Where!\lines args)[1]

    new: => @exec = @@exec


{ :PowerShell, :Exec, :Where }
