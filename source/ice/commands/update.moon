import Command, option, flag from require "ice.command"
import Conan from require "ice.tools.conan"
import IBT from require "ibt.ibt"

import File from require "ice.core.fs"

class UpdateCommand extends Command
    @arguments {
        option "upgrade_ibt",
            name: '--upgrade-ibt'
            description: 'Upgrade the IBT package to the latest version.'
            default: 'latest'
            defmode: 'arg'
    }

    execute: (args, project) =>

        if args.upgrade_ibt
            current_package = "ice-build-tools/#{IBT.conan.version}@#{IBT.conan.user}/#{IBT.conan.channel}"
            current_version = IBT.conan.version
            newest_package = current_package
            newest_version = current_version
            conan = Conan!

            @log\info "Checking remotes for newer IBT version..."
            for package in *conan\search "ice-build-tools/*@#{IBT.conan.user}/#{IBT.conan.channel}", remote:'all'
                if newest_version < package.version
                    newest_version = package.version
                    newest_package = package.full

            if newest_version == current_version
                @log\info "IBT is up-to-date."

            else
                @log\info "Found newer version '#{newest_version}', upgrading..."

                conanfile_update_success = false
                if contents = File\load 'tools/conanfile.txt', mode:'r+'
                    updated_conanfile = contents\gsub (current_package\gsub '([%-%.])', (v) -> '%'..v), newest_package
                    conanfile_update_success = File\save 'tools/conanfile.txt', updated_conanfile

                if conanfile_update_success
                    conan\install conanfile:'tools/conanfile.txt', install_folder:'build/tools', build_policy:'missing'
                else
                    @log\error "Failed to update IBT package ID in 'tools/conanfile.txt'"

        else
            project.action.install_conan_dependencies!
            project.action.generate_build_system_files!

{ :UpdateCommand }
