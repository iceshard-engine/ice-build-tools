import Exec, Where from require "ice.tools.exec"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"
import Json from require "ice.util.json"

class Conan extends Exec
    new: (path) => super path or (os.iswindows and Where\path "conan.exe") or Where\path "conan"

    remotes: =>
        cmd = "remote list"
        result = { }
        for line in *@\lines cmd
            if matched = line\match "([^:]+)"
                table.insert result, matched
        result

    search: (package, args = {}) =>
        local_next = next
        cmd = "search #{package} -f json"
        cmd ..= " -r #{args.remote}" if args.remote

        result_json = @\capture cmd
        result_json = Json\decode result_json if result_json

        result = {}
        for remote, packages in pairs (result_json or {})
            for reference, _ in pairs packages
                name, version, user, channel = reference\match "([^/]+)/([^@]+)@([^/]+)/(.+)"
                table.insert result, { :name, :version, :user, :channel, full:line, :remote } if name and channel
        result

    graph_info: (args) =>
        return unless Validation\ensure args.conanfile, "Missing 'conanfile.txt' location!"
        return unless Validation\ensure (args.format == 'json' or args.format == 'html' or args.format == 'dot'), "Invalid format value provided! Allowed values are: 'json', 'html', 'dot'"

        cmd = "graph info #{args.conanfile}"
        cmd ..= " --format #{args.format}" if args.format
        cmd ..= " --package-filter #{args.package}" if args.package
        @\capture cmd

    download: (args) =>
        return unless Validation\ensure args.reference or args.package, "Missing package reference to be downloaded!"
        return unless Validation\ensure args.remote, "Missing 'remote' source for the downloaded package!"

        cmd = "download"
        cmd ..= " -r #{args.remote} #{args.reference or args.package}"
        @\run cmd

    install: (args) =>
        cmd = "install"

        return unless Validation\ensure args.conanfile or args.reference, "Missing 'conanfile' path or 'reference'!"
        return unless Validation\ensure args.install_folder, "Missing 'install_folder' param!"

        cmd ..= " #{args.conanfile or args.reference}"
        cmd ..= " --output-folder #{args.install_folder}"
        cmd ..= " --build #{args.build_policy}" if args.build_policy
        cmd ..= " --profile:build default" if args.profile
        cmd ..= " --profile:host #{args.profile}" if args.profile
        cmd ..= " --update" if args.update
        @\run cmd

{ :Conan }
