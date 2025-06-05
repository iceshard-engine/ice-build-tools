import Command, argument, option, flag, group from require "ice.command"
import Path, Dir, File from require "ice.core.fs"
import Setting from require "ice.settings"
import SDKList from require "ice.sdks"

class SDKCommand extends Command
    @settings {
    }

    @arguments {
        group 'base', description: 'General SDK options and flags'
        argument 'mode',
            description: 'The mode this command should run in.'
            group: 'base'
            name: 'mode'
            choices: { 'check', 'install' }
            default: 'check'
        argument 'sdk_id',
            description: 'Selected SDK to be checked or installed explicitly.'
            group: 'base'
            target: 'sdkid'
            name: 'sdk-id'
            args: '?'

        group 'check', description: 'Locating and checking for installed SDKs and the versions.'


        group 'install', description: 'Installing various SDKs and tools.'
        option 'version',
            description: 'The version of the SDK to be installed.'
            group: 'install'
            name: '-V --version'
    }

    prepare: (args, project) =>
        @sdks_root = Path\join Dir\current!, (Setting\get 'sdks.local_install_path')
        @log\verbose "SDK installation path is set to: #{@sdks_root}"

        if args.mode == 'install'
            unless Dir\exists @sdks_root
                Dir\create @sdks_root

    execute: (args, project) =>
        @_execute_install args, project if args.mode == 'install'
        @_execute_check args, project

    _execute_install: (args, project) =>
        sdk = SDKList\find args.sdkid
        @fail "Selected unknown SDK with id '#{args.sdkid}'" unless sdk
        if Path\exists sdk\installed_location!
            @log\info "The #{sdk.name} is already installed under '#{sdk\installed_location!}'"
            @success!

        path, version = sdk\install_location!, sdk\install_version!
        @log\info "Installing #{sdk.name} (version: #{version}) to '#{path}'... (id: #{sdk.id})"
        sdk\install version

        @success!

    _execute_check: (args, project) =>
        @log\info "Located SDK's"
        SDKList\each (sdk) ->
            sdk_parts = toolchains:{}, platform_sdks:{}, additional_sdks:{}
            sdk\locate_internal sdk_parts

            -- for part in *sdk_parts.platform_sdks
            --     @log\info "- #{part.name}"
            if #sdk_parts.additional_sdks == 0
                @log\info "  #{sdk.name} (id: #{sdk.id}, unavailable)"
            else
                for part in *sdk_parts.additional_sdks
                    @log\info "  #{part.name} (id: #{sdk.id}, installed)\n  - version: #{part.version}\n  - location: #{part.location}"

{ :SDKCommand }
