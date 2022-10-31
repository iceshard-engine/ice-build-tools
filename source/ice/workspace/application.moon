import Application from require 'ice.application'

import BuildCommand from require 'ice.commands.build'
import UpdateCommand from require 'ice.commands.update'
import LicenseCommand from require 'ice.commands.license'
import VStudioCommand from require 'ice.commands.vstudio'

class ProjectApplication extends Application
    @name: 'NewProject'
    @description: 'Workspace CLI tool'
    @commands: {
        'update': UpdateCommand
        'build': BuildCommand
        'license': LicenseCommand
        'vstudio': VStudioCommand
    }

    -- Plain call to the application
    execute: (args) => super!

{ :ProjectApplication }
