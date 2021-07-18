import Command, option, flag from require "ice.command"

class UpdateCommand extends Command
    @arguments { }

    execute: (args, project) =>
        project.action.install_conan_dependencies!
        project.action.generate_fastbuild_variables_script!
        project.action.generate_fastbuild_workspace_script!

{ :UpdateCommand }
