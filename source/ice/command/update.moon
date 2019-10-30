import Command, option, flag from require "ice.command"
import detect_compiler from require "ice.util.detect_compiler"

lfs = require 'lfs'

class UpdateCommand extends Command
    @description: "Updates all dependencies in the project."
    @arguments: {
        flag {
            name:'-f --force'
            description:'Force updates all dependencies.'
            default:false
        }
    }

    -- Build command call
    execute: (args, skip_fastbuild_target) =>

        -- Run conan in the build directory
        os.indir "build", ->

            if args.force or not os.isfile 'tools/conanbuildinfo.txt'
                os.execute "conan install ../tools --build=missing"

            if args.force or not os.isfile 'conaninfo.txt'
                os.execute "conan install ../source --build=missing"



{ :UpdateCommand }
