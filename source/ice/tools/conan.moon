import Exec, Where from require "ice.tools.exec"

class Conan extends Exec
    new: (path) => super path or Where\path "conan.exe"

    install: (args) =>
        cmd = "install"

        error "ERROR: Missing 'conanfile' path or 'reference'!" unless args.conanfile or args.reference

        cmd ..= " #{args.conanfile or args.reference}"
        cmd ..= " --install-folder #{args.install_folder}"
        cmd ..= " --build #{args.build_policy}" if args.build_policy
        cmd ..= " --profile #{args.profile}" if args.profile
        cmd ..= " --update" if args.update

        @\run cmd

{ :Conan }
