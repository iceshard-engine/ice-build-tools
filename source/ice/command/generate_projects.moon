import Command, option, flag from require "ice.command"
import detect_compiler from require "ice.util.detect_compiler"

lfs = require 'lfs'

class GenerateProjectsCommand extends Command
    @description: "Generates project files for the selected IDE"
    @arguments: {
        option {
            name:'-s --build-system'
            description:'The build system for which projects will be generated. Currently only \'fastbuild\' is supported.'
            default:'fastbuild'
            args:1
        }
        flag {
            name:'-r --rebuild'
            description:'Regenerates all project files.'
            default:false
        }
        -- Visual studio related values
        option {
            name:'--vs-ver'
            description:'The Visual Studio version range that should be searched for. The latest version will be used always'
            default:'[15.0,17.0)'
            args:1
        }
        option {
            name:'--vs-products'
            description:'The Visual Studio product lines that should be considered. Available: Community, Professional, BuildTools'
            default:'*'
            args:1
        }
    }

    -- Build command call
    execute: (args, skip_fastbuild_target) =>
        compiler = detect_compiler {
            host: os.host!
            target: os.host!
            vstudio: { version:args.vs_ver, products:args.vs_products }
        }

        unless compiler
            print "No compiler was detected!"
            return false

        with compiler
            compiler_attributes = [{ name:k, value:v } for k, v in pairs compiler]
            table.sort compiler_attributes, (a, b) -> a.name < b.name

            -- FASTBuild build system
            if args.build_system == 'fastbuild'
                if file = io.open 'build/compiler_info.bff', 'w+'
                    file\write '// Generated file\n'
                    file\write ".#{name} = '#{value}'\n" for {:name, :value} in *compiler_attributes
                    file\close!

            -- Run conan in the build directory
            current_dir = lfs.currentdir!
            if lfs.chdir "build"

                if args.rebuild or not os.isfile 'conan.bff'
                    os.execute "conan install ../source --build=missing"

                -- Run fastbuilds 'solution' target
                unless skip_fastbuild_target
                    os.execute "fbuild -config ../source/fbuild.bff solution"

                lfs.chdir current_dir

        -- For now always return true
        true



{ :GenerateProjectsCommand }
