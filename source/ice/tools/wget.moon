import Exec, PowerShell, Where from require "ice.tools.exec"
import Validation from require "ice.core.validation"
import File, Dir from require "ice.core.fs"

class Wget
    @url: (url, dest, options = {}) =>
        unless Validation\ensure (File\exists dest) == false or options.force, "[Unzip] Destination file '#{dest}' already exists, use 'force:true' if that's expected."
            return

        if os.iswindows
            @exec = PowerShell "Invoke-WebRequest"
            @exec\run "-Uri '#{url}' -OutFile '#{dest}'"
        else
            @exec = Exec "wget"
            @exec\run (options.allow_unsecure and '' or '--https-only') .. " -o #{dest} #{url}"

    @content: (url) =>
        if os.iswindows
            @exec = PowerShell "Invoke-WebRequest"
            return @exec\capture "-Uri '#{url}'", 'Content'
        else
            assert false

{ :Wget }
