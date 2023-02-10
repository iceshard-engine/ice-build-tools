import Project from require "ice.workspace.project"
import ProjectApplication from require "ice.workspace.application"

with Project "NewProject"
    \application ProjectApplication

    -- Set settings after they have been loaded from 'settings.json' file
    \set "project.source_dir", "source/code"
    \set "project.fbuild.vstudio_solution_file", "NewProject.sln"

    -- If not set it will take the default value or the value stored in 'settings.json'
    -- \set "project.output_dir", "build"

    \finish!
