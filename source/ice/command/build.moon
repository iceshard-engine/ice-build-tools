import Command, option, flag from require "ice.command"
import GenerateProjectsCommand from require "ice.command.generate_projects"

class BuildCommand extends GenerateProjectsCommand
    @description: "Builds the engine in the Release configuration."
    @arguments: {
        option {
            name:'-s --build-system'
            description:'The build system for which projects will be generated. Currently only \'fastbuild\' is supported.'
            default:'fastbuild'
            choices: { 'fastbuild', 'msbuild' }
            args:1
        }
        option {
            name:'-t --target'
            description:'The target which should be build.'
            default:'all-x64-ReleaseDebug'
            args:1
        }
        flag {
            name:'-c --clean'
            description:'Runs a clean build.'
            default:false,
        }
        flag {
            name:'-v --verbose'
            description:'Runs the build commands in verbose mode.'
            default:false
        }
        flag {
            name:'--monitor'
            description:'Runs fastbuild with support for monitoring apps.'
            default:true
        }
        flag {
            name:'-d,--distributed'
            description:'Runs fastbuild with work distribution to remote workers.'
            default:true
        }
        flag {
            name:'--cache'
            description:'Runs fastbuild with caching enabled.'
            default:false
        }
    }

    -- Build command call
    execute: (args) =>
        result = false

        -- Generate projects first
        super { rebuild:args.clean, build_system:args.build_system }, true

        current_dir = lfs.currentdir!
        if lfs.chdir "build"
            additonal_arguments = ""
            additonal_arguments ..= " -verbose" if args.verbose
            additonal_arguments ..= " -clean" if args.clean
            additonal_arguments ..= " -monitor" if args.monitor
            additonal_arguments ..= " -dist" if args.distributed
            additonal_arguments ..= " -cache" if args.cache



            -- Run fastbuild with the right target
            build_result = os.execute "fbuild -config ../source/fbuild.bff #{args.target} #{additonal_arguments}"
            lfs.chdir current_dir

            result = build_result == 0

        -- Return the command result
        result



{ :BuildCommand }
