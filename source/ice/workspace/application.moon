import Application from require "ice.application"

import BuildCommand from require "ice.commands.build"
import UpdateCommand from require "ice.commands.update"
import LicenseCommand from require "ice.commands.license"
import DevenvCommand from require "ice.commands.devenv"
import ExecCommand from require "ice.commands.exec"
import ScriptCommand from require "ice.commands.script"
import SettingsCommand from require "ice.commands.settings"
import AndroidCommand from require "ice.commands.android"

class ProjectApplication extends Application
    @name: 'NewProject'
    @description: 'Workspace CLI tool'
    @commands: {
        'android': AndroidCommand
        'update': UpdateCommand
        'build': BuildCommand
        'license': LicenseCommand
        'devenv': DevenvCommand
        'exec': ExecCommand
        'script': ScriptCommand
        'settings': SettingsCommand
    }

    -- Plain call to the application
    execute: (args) => super!

{ :ProjectApplication }
