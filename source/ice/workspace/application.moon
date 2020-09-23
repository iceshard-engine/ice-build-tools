import Application from require 'ice.application'

import InstallCommand from require 'ice.commands.install'
import BuildCommand from require 'ice.commands.build'
import VStudioCommand from require 'ice.commands.vstudio'

class ProjectApplication extends Application
    @name: ''
    @description: 'Workspace command tool.'
    @commands: {
        'build': BuildCommand
        'install': InstallCommand
        'vstudio': VStudioCommand
    }

    -- Plain call to the application
    execute: (args) =>
        print "#{@@name} - v0.1-alpha"
        print ''
        print '> For more options see the -h,--help output.'

{ :ProjectApplication }
