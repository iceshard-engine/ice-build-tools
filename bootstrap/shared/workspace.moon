import Project from require 'ice.workspace.project'
import ProjectApplication from require 'ice.workspace.application'

with Project "NewProject"
    \application ProjectApplication
    \load_settings "tools" --, "settings_{os}.json"

    -- Source settings
    \sources "source/code"
    \profiles "source/conan_profiles.json"
    \fastbuild_script "source/fbuild.bff"

    -- Output settings
    \working_dir "build"
    \output "build"

    \finish!
