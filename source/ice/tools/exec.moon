require "ice.util.os"

class Exec
    new: (@exec) =>
        print "WARNING: #{@exec} does not exist!" unless os.isfile @exec

    run: (arguments) =>
        os.execute "\"#{@exec}\" #{arguments or ''}"

    capture: (arguments) =>
        result = { }
        if proc = io.popen "\"#{@exec}\" #{arguments or ''}"
            for line in proc\lines!
                table.insert result, line
            proc\close!
        result

{ :Exec }
