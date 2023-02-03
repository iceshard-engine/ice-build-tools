import Command, Setting, argument, option, flag from require "ice.command"
import Path, File, Dir from require "ice.core.fs"
import Log from require "ice.core.logger"

moonscript = require "moonscript"

class ScriptCommand extends Command
    @settings {
        Setting 'script.directory',
            default:'./tools/scripts'
            required:true
            predicate:(path) -> (Dir\exists path) or false, "The setting 'script.directory' points to a invalid location: '#{path}'"
    }
    @arguments {
        argument 'script',
            description: 'Searches for the given script file and tries to execute it.'
        argument 'script_args'
            description: 'Arguments to be passed to the script file. Provide after \'--\'.'
            args: '*'
        option 'scripts_folder',
            name: '-f --folder'
            argname: 'scripts folder'
            description: 'The location where to look for script files.'
            default: Setting\ref 'script.directory'
    }

    prepare: (args, project) =>
        args.folder = Path\normalize args.folder
        final_path = Path\join Dir\current!, args.folder

        -- Ensure the path exists
        unless Dir\exists final_path
            @fail "Script folder '#{final_path}' does not exist"

        -- Enter the directory
        Dir\enter final_path

    execute: (args, project) =>
        local loaded_script

        errors = { }
        moon_file = "#{args.script}.moon"
        lua_file = "#{args.script}.lua"

        if File\exists moon_file
            lua_file = nil
            loaded_script, errors = moonscript.loadfile moon_file

        elseif File\exists lua_file
            moon_file = nil
            loaded_script, errors = loadfile lua_file
        else
            errors = { "Neither '#{moon_file}' nor '#{lua_file}' exist in the '#{Dir\current!}' script directory."}

        if loaded_script == nil
            @fail "Failed to load script '#{moon_file or lua_file}' with errors:\n#{table.concat errors, ', '}"

        -- Hide the original arguments
        local_arg = arg
        export arg = args.script_args

        -- Execute the script
        Log\info "Executing script '#{moon_file or lua_file}' ..."
        success, error = pcall loaded_script

        -- Restore the original arguments
        export arg = local_arg

        -- Report errors if needed
        unless success
            return {
                return_code:-1
                message:"Script '#{args.script}' failed execution with '#{error}'"
            }

        return true


{ :ScriptCommand }
