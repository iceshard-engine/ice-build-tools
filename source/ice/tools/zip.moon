import Exec, PowerShell, Where from require "ice.tools.exec"
import Validation from require "ice.core.validation"
import Path, File, Dir from require "ice.core.fs"

class Zip
    @extract: (file, dir, options = {}) =>
        Validation\assert (File\exists file), "[Unzip] Input file does not exist: #{file}"
        Validation\assert (Dir\exists dir) == false or options.force, "[Unzip] Destination '#{dir}' might not be empty, use 'force:true' if that's expected."

        if os.iswindows
            @exec = PowerShell "Expand-Archive"
            @exec\run "-LiteralPath \"#{file}\" -DestinationPath \"#{dir}\" " .. (options.force and '-Force' or '')
        else
            if options.use_tar
                ext = Path\extension file
                mode = if (ext == '.gz') or (ext == '.tgz') then 'z' else ''

                @exec = Exec "tar", nocheck:true
                @exec\run "-#{mode}xf #{file} -C #{dir}"
            else
                @exec = Exec "unzip", nocheck:true
                @exec\run "#{file} -d #{dir} " .. (options.force and '-o' or '')



{ :Zip }
