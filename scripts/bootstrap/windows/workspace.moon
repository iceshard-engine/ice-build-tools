import Project from require 'ice.workspace.project'
import ProjectApplication from require 'ice.workspace.application'

with Project "NewProject"
    \application ProjectApplication
    \script "ibt.bat"

    -- Source settings
    \sources "source/code"
    \profiles "source/conan_profiles.json"
    \fastbuild_script "source/fbuild.bff"

    -- Output settings
    \working_dir "build"
    \output "build"

    \finish!
