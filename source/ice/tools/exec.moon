require "ice.util.os"


class Exec
    new: (@exec) =>
        print "WARNING: #{@exec} does not exist!" unless os.isfile @exec

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


class Where extends Exec
    @exec = os.iswindows and 'where.exe' or 'which'
    @path: (name, err_log) =>
        args = name
        args ..= " 2>>#{err_log}" if err_log

        (Where!\lines args)[1]

    new: => @exec = @@exec


{ :Exec, :Where }
