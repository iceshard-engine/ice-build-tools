import Exec, Where from require "ice.tools.exec"

class Git extends Exec
    new: (path) => super path or Where\path "git"

    branch: (args = { }) =>
        cmd = "branch"
        cmd ..= " --show-current" if not args.target or not args.show_all
        @\run cmd

{ :Git }
