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

                -- Load the old settings file and override only the keys that got serialized.
                -- This way we don't remove custom keys or deprecated keys that the user might want to keep
                current_settings = File\load project.settings_file, mode:'r', parser:Json\decode
                for key, value in pairs Settings\serialize!
                    current_settings[key] = value

                -- Builds the final Json structure with a pre-defined order of keys (special) + (... alphabetic order)
                selector = (t) ->
                    special = { 'windows', 'linux', 'macos', 'project' }
                    special_map = { key, true for key in *special }

                    keys = [k for k in pairs t when not special_map[k]]
                    table.sort keys, (a, b) -> a < b

                    final_keys = [key for key in *special when t[key]]
                    table.insert final_keys, key for key in *keys

                    i = 0
                    (...) ->
                        i = i + 1
                        final_keys[i], t[final_keys[i]] if t[final_keys[i]]

                File\save project.settings_file, (Json\encode current_settings, selector), mode:'w+'

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
