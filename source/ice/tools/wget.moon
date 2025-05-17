import Exec, PowerShell, Where from require "ice.tools.exec"
import Validation from require "ice.core.validation"
import File, Dir from require "ice.core.fs"

class Wget
    @url: (url, dest, options = {}) =>
        Validation\assert (File\exists dest) == false or options.force, "[Unzip] Destination file '#{dest}' already exists, use 'force:true' if that's expected."

        if os.iswindows
            @exec = PowerShell "Invoke-WebRequest"
            @exec\run "-Uri '#{url}' -OutFile '#{dest}'"
        else
            @exec = Exec "wget"
            @exec\run (options.allow_unsecure and '' or '--https-only') .. " -o #{dest} #{url}"

{ :Wget }
