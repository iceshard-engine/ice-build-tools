import Command, argument, option, flag from require "ice.command"
import Settings from require "ice.settings"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

import File from require "ice.core.fs"
import Json from require "ice.util.json"

class SettingsCommand extends Command
    @arguments {
        argument "action",
            description: [[
The operation to be peformed.
- 'list' displays all matching settings and their values.
- 'set' changes the setting and updates the settings files.
- 'get' displays the value for the specific setting.
            ]]
            choices: { 'list', 'set', 'get' }
            default: 'list'
        argument "setting"
            description: 'The setting(s) to list, get or set. If used with the \'list\' command simple matching will be performed.'
            args: '?'
        argument "new_value"
            description: 'The value that satisfies the requirements and predicate of a given setting.'
            args: '?'
    }

    execute: (args, project) =>
        if args.action == 'get'
            value, success = Settings\get args.setting
            @log\info "#{args.setting} = #{value}" if success

        elseif args.action == 'set'
            return unless Validation\ensure args.new_value ~= nil, "Missing a value to be set"

            success = Settings\set args.setting, args.new_value
            if success
                @log\info "#{args.setting} = #{Settings\get args.setting}"
                serialized_settings = Settings\serialize!
                File\save project.settings_file, (Json\encode serialized_settings), mode:'w+'

        elseif args.action == 'list'
            @log\info "Settings list:"
            for setting in *Settings\list!
                continue unless setting.key\match (args.setting or "") .. ".*"

                value = setting.value or setting.default or (setting.required and '<MISSING_VALUE>' or '<NO_VALUE>')

                if (type value) == 'table'
                    Log.raw\info "#{setting.key}:"
                    Log.raw\info "- %s", "[#{key}] = #{entry}" for key, entry in pairs value
                else
                    Log.raw\info "#{setting.key}: #{value}"

{ :SettingsCommand }
