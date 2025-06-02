require "ice.util.os"

import Log from require "ice.core.logger"
import File from require "ice.core.fs"

class Exec
    new: (@exec, opts = {}) =>
        Log\warning "#{@exec} does not exist!" unless opts.nocheck or File\exists @exec

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


class Where
    @path: (name, err_log) =>
        args = name
        args ..= " 2>>#{err_log}" if err_log

        if os.iswindows
            -- Previously (Exec 'where.exe') but couldn't find all possible executables / scripts
            line = ((PowerShell "Get-Command")\lines name, "Path")[1]
            line = nil if line\match "is not recognized"
            return line
        else
            ((Exec 'which', nocheck:true)\lines args)[1]

    @exec: (name, err_log) =>
        path = Where\path name, err_log
        if path ~= nil
            return Exec path, nocheck:true

{ :PowerShell, :Exec, :Where }
