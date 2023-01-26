import Application from require 'ice.application'

import BuildCommand from require 'ice.commands.build'
import UpdateCommand from require 'ice.commands.update'
import LicenseCommand from require 'ice.commands.license'
import DevenvCommand from require 'ice.commands.devenv'
import ExecCommand from require 'ice.commands.exec'

class ProjectApplication extends Application
    @name: 'NewProject'
    @description: 'Workspace CLI tool'
    @commands: {
        'update': UpdateCommand
        'build': BuildCommand
        'license': LicenseCommand
        'devenv': DevenvCommand
        'exec': ExecCommand
    }

    -- Plain call to the application
    execute: (args) => super!

{ :ProjectApplication }
