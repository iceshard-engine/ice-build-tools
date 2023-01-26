import BaseCommand, argument, option, flag from require 'ice.commands.base'
moonscript = require 'moonscript'

class ScriptCommand extends BaseCommand
    @settings: { }
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
            default: './tools/scripts'
    }


    prepare: (args, project) =>
        args.folder = args.folder\sub 3 if args.folder\match "^%.[\\/]"
        cwd = os.cwd!
        cwd = (cwd\gsub '\\', '/') if os.iswindows

        final_path = "#{cwd}/#{args.folder}"
        if os.isdir final_path
            os.chdir final_path
        else
            return {
                return_code: -1
                message: "Script folder #{final_path} does not exist"
            }

    execute: (args, project) =>
        loaded_script, errors = moonscript.loadfile "#{args.script}.moon" if os.isfile "#{args.script}.moon"
        loaded_script, errors = loadfile "#{args.script}.lua" if os.isfile "#{args.script}.lua"
        unless loaded_script
            return {
                return_code:-1
                message:"Failed to load script '#{args.script}' with errors:\n#{errors}"
            }

        -- Hide the original arguments
        local_arg = arg
        export arg = args.script_args

        -- Execute the script
        print "Executing script '#{args.script}' ..."
        success, error = pcall loaded_script

        -- Restore the original arguments
        export arg = local_arg

        -- Report errors if needed
        unless success
            return {
                return_code:-1
                message:"Script '#{args.script}' failed execution with '#{error}'"
            }


{ :ScriptCommand }
