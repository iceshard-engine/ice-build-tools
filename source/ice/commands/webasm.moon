import Command, group, argument, option, flag from require "ice.command"
import Exec, Where from require "ice.tools.exec"
import FastBuild from require "ice.tools.fastbuild"
import Path, Dir, File from require "ice.core.fs"
import Validation from require "ice.core.validation"
import Setting from require "ice.settings"
import Log from require "ice.core.logger"
import WebAsm from require "ice.platform.webasm"

import INIConfig from require "ice.util.iniconfig"
import Json from require "ice.util.json"

class WebAsmCommand extends Command
    @settings {
        Setting 'webasm.projects', default:{}
        Setting 'webasm.emscripten.location', default:'build/emscripten'
        Setting 'webasm.emscripten.version', default:'0.0.1'
    }
    @arguments {
        group 'general', description: "Basic options"
        argument 'mode',
            group: 'general'
            description: 'Selects the mode in which the command operates.'
            name: 'mode'
            choices: { 'build', 'setup', 'sdk' }
            default: 'build'
        group 'build', description: "Build options"
        option 'target',
            group: 'build'
            description: 'The target task to be executed by the gradle wrapper.'
            name: '-t --target'
            default: 'assemble'
            argname: '<gradle_task>'
        flag 'rerunn_tasks',
            group: 'build'
            description: 'Re-runs all dependent tasks for the given target task.'
            name: '--rerun-tasks'
        group 'setup', description: "Setup options"
        flag 'reinstall',
            group: 'setup'
            description: 'Reinstalls the SDK from scratch.'
            name: '--reinstall'
        group 'sdk', description: "SDK management options"
        option 'list_sdks',
            group: 'sdk'
            name: '-l --list'
            description: 'Lists currently installed SDK packages.'
            choices: { 'all', 'outdated' }
            default: 'all'
            defmode: 'arg'
        option 'update_sdks',
            group: 'sdk'
            description: 'Updates the selected SDKs. Multiple entries can be provided. Use the SDK \'id\' for the value.'
            name: '-u --update'
            count: '*'
    }

    prepare: (args, project) =>

    execute: (args, project) =>
        @execute_setup args, project if args.mode == 'setup'

    execute_build: (args, project) =>

    execute_setup: (args, project) =>
        unless WebAsm\install_webasm_sdk 'build/webasm', force:args.reinstall
            @fail "Failed to install web-assembly SDK"

{ :WebAsmCommand }
