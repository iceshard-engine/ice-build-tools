import Command, argument, option, flag, group from require "ice.command"
import Setting from require "ice.settings"
import SDKList from require "ice.sdks"

class SDKCommand extends Command
    @settings {
    }

    @arguments {
        group 'base', description: 'General SDK options and flags'
        argument 'mode',
            description: 'The mode this command should run in.'
            -- group: 'base'
            name: 'mode'
            choices: { 'check', 'install' }
            default: 'check'

        group 'check', description: 'Locating and checking for installed SDKs and the versions.'


        group 'install', description: 'Installing various SDKs and tools.'
    }

    prepare: (args, project) =>
        true

    execute: (args, project) =>

        @log\info "Located SDK's"
        SDKList\each (sdk) ->
            sdk_parts = toolchains:{}, platform_sdks:{}, additional_sdks:{}
            sdk\install!
            sdk\locate_internal sdk_parts

            -- for part in *sdk_parts.platform_sdks
            --     @log\info "- #{part.name}"
            if #sdk_parts.additional_sdks == 0
                @log\info "  #{part.name} (unavailable)"
            else
                for part in *sdk_parts.additional_sdks
                    @log\info "  #{part.name} (installed)\n  - version: #{part.version})\n  - location: #{part.location}"

{ :SDKCommand}
