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
    @exec = 'where.exe'
    @path: (name) => (Where!\lines name)[1] or name

    new: => @exec = @@exec


{ :Exec, :Where }
