import Exec, Where from require "ice.tools.exec"
import Log from require "ice.core.logger"
import Validation from require "ice.core.validation"

class Conan extends Exec
    new: (path) => super path or (os.iswindows and Where\path "conan.exe") or Where\path "conan"

    install: (args) =>
        cmd = "install"

        return unless Validation\ensure args.conanfile or args.reference, "Missing 'conanfile' path or 'reference'!"

        cmd ..= " #{args.conanfile or args.reference}"
        cmd ..= " --install-folder #{args.install_folder}"
        cmd ..= " --build #{args.build_policy}" if args.build_policy
        cmd ..= " --profile #{args.profile}" if args.profile
        cmd ..= " --update" if args.update

        @\run cmd

{ :Conan }
