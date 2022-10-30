import Application from require 'ice.application'

import UpdateCommand from require 'ice.commands.update'
import BuildCommand from require 'ice.commands.build'
import VStudioCommand from require 'ice.commands.vstudio'

class ProjectApplication extends Application
    @name: 'NewProject'
    @description: 'Workspace CLI tool'
    @commands: {
        'build': BuildCommand
        'update': UpdateCommand
        'vstudio': VStudioCommand
    }

    -- Plain call to the application
    execute: (args) =>
        print "#{@@name} CLI - IBT/1.0.0"
        print ''
        print '> For more options see the -h,--help output.'

{ :ProjectApplication }
