import Command, option, flag from require "ice.command"

class CleanCommand extends Command
    @description: "Cleans the 'build' directory from temporary build files."
    @arguments: { }

    -- Helper method for recursive cleaning
    clean_directory: (path) =>
        for name, mode in os.listdir path, 'mode'
            if name == '.' or name == '..'
                continue

            if mode == 'file'
                os.remove "#{path}/#{name}"
            if mode == 'directory'
                @\clean_directory "#{path}/#{name}"
                os.rmdir "#{path}/#{name}"

    -- Build command call
    execute: (args) =>
        print "Cleaning the 'build' directory..."
        os.indir "build", (path) ->

            for name, mode in os.listdir path, 'mode'
                if name == '.' or name == '..'
                    continue

                if mode == 'file'
                    os.remove name
                if mode == 'directory' and name ~= 'tools'
                    @\clean_directory name
                    os.rmdir name

        print "Clean finished."



{ :CleanCommand }
