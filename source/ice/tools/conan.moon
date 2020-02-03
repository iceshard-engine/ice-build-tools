import Exec, Where from require "ice.tools.exec"

class Conan extends Exec
    new: => super Where\path "conan.exe"

    install: (options) =>
        @\run "install"


{ :Conan }
