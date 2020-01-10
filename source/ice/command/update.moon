import Command, option, flag from require "ice.command"
import detect_compiler from require "ice.util.detect_compiler"

lfs = require 'lfs'

class UpdateCommand extends Command
    @description: "Updates all dependencies in the project."
    @arguments: {
        flag {
            name:'--tools'
            description:'Force update on tool dependnecies'
            default:false
        }
        flag {
            name:'-f --force'
            description:'Force updates all dependencies.'
            default:false
        }
    }

    -- Build command call
    execute: (args, skip_fastbuild_target) =>

        -- Run conan in the build directory
        unless os.isdir "build/tools"
            assert (os.mkdirs "build/tools"), "Couldn't create required directories"

        os.indir "build/tools", ->

            if args.force or args.tools or not (os.isfile 'conanbuildinfo.txt')
                os.execute "conan install ../../tools --build=missing --update"

            if args.force or not os.isfile 'conaninfo.txt'
                os.execute "conan install ../../source --build=missing --update"

{ :UpdateCommand }
