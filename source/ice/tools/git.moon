import Exec, Where from require "ice.tools.exec"

class Git extends Exec
    new: (path) => super path or Where\path "git"

    status: (args = { }) =>
        cmd = "status"
        cmd ..= " --short" -- make it optional
        cmd ..= " #{args.path}" if args.path

        results = { }
        for line in *@\lines cmd
            status, filename = line\match "^([AMR]+)%s+([^\n\r]+)"
            table.insert results, { :filename, :status }
        results

    branch: (args = { }) =>
        cmd = "branch"
        cmd ..= " --show-current" if not args.target or not args.show_all
        @\run cmd

{ :Git }
