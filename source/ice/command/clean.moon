import Command, option, flag from require "ice.command"
import GenerateProjectsCommand from require "ice.command.generate_projects"

lfs = require 'lfs'

class CleanCommand extends GenerateProjectsCommand
    @description: "Generates project files for the selected IDE"
    @arguments: {
    }

    -- Helper method for recursive cleaning
    clean_directory: (path) =>
        print "Removing: #{path}"

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
        if lfs.chdir 'build'
            for name, mode in os.listdir '.', 'mode'
                if name == '.' or name == '..'
                    continue

                if mode == 'file'
                    os.remove name
                if mode == 'directory' and name ~= 'tools'
                    @\clean_directory name
                    os.rmdir name

{ :CleanCommand }
