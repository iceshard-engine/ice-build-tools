import Exec, PowerShell, Where from require "ice.tools.exec"
import Validation from require "ice.core.validation"
import File, Dir from require "ice.core.fs"

class Zip
    @extract: (file, dir, options = {}) =>
        Validation\assert (File\exists file), "[Unzip] Input file does not exist: #{file}"
        Validation\assert (Dir\exists dir) == false or options.force, "[Unzip] Destination '#{dir}' might not be empty, use 'force:true' if that's expected."

        if os.iswindows
            @exec = PowerShell "Expand-Archive"
            @exec\run "-LiteralPath \"#{file}\" -DestinationPath \"#{dir}\" " .. (options.force and '-Force' or '')
        else
            @exec = Exec "unzip"
            @exec\run "#{file} -d #{dir} " .. (options.force and '-o' or '')

{ :Zip }
