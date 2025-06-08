import ConanProfileGenerator from require "ice.generators.conan_profile"
import FastBuild from require "ice.tools.fastbuild"
import Conan from require "ice.tools.conan"
import Setting from require "ice.settings"

import Path, File, Dir from require "ice.core.fs"
import Validation from require "ice.core.validation"
import INIConfig from require "ice.util.iniconfig"

-- Conan related settings
Setting 'project.conan.profiles', default:'source/conanprofiles.txt', predicate:File\exists
Setting 'project.conan.dependencies', default:'source/conanfile.txt', predicate:File\exists

_ini_template_files = ->
    file_conan_profiles = Setting\get 'project.conan.profiles'
    file_conan_dependencies = Setting\get 'project.conan.dependencies'
    unless (File\exists file_conan_profiles) and (File\exists file_conan_dependencies)
        Log\info "No description for source dependencies found, skipping..." unless file_conan_py
        return
    file_conan_profiles, file_conan_dependencies

-- Checks for multiple section targets and collapses them (in-order) into the final base section
_ini_template_resolver = (base_sections) ->
    (template, profile, config) ->
        sections = { }
        for section in *base_sections
            table.insert sections, { base:section, template:section }
            table.insert sections, { base:section, template:"#{section}-#{config}" }
            table.insert sections, { base:section, template:"#{section}-#{profile}" }
            table.insert sections, { base:section, template:"#{section}-#{profile}-#{config}" }

        result = { }
        for section in *sections
            values, meta = template\section section.template
            if values and meta
                result[section.base] = { } unless result[section.base]

                if meta.type == 'array'
                    table.insert result[section.base], val for val in *values
                if meta.type == 'map'
                    result[section.base][key] = value for key, value in pairs values
            elseif not result[section.base]
                result[section.base] = { }
        result

class ConanProfile
    @conanfile_resolver = _ini_template_resolver {
        'requires'
        'tool_requires'
        'options'
        'generators'
    }

    @conanprofile_resolver = _ini_template_resolver {
        'settings'
        'options'
        'buildenv'
        'conf'
        'buildenv'
        'runenv'
        'tool_requires'
    }

    new: (@name, @location, @variables = {}) =>
        @profile, @config = @name\match "([a-zA-Z0-9_%-]+)%-([a-zA-Z0-9_]+)$"

        @hostprofile = Path\join @location, 'host_profile.txt'
        @conanfile = Path\join @location, 'conanfile.txt'


    install: (opts={force:false}) =>
        profile_template_file, conanfile_template_file = _ini_template_files!
        unless Dir\exists @location then Dir\create @location

        -- Execute conan for the generated profile
        if opts.force or not ((File\exists @hostprofile) and (File\exists @conanfile))
            INIConfig\save @hostprofile, @_build_profile_object profile_template_file
            INIConfig\save @conanfile, @_build_conanfile_object conanfile_template_file

            Conan!\install
                conanfile:@location
                update:false
                profile:@hostprofile
                install_folder:@location
                build_policy:'missing'

    _build_profile_object: (profile_template_file) =>
        profile_template = INIConfig\open profile_template_file
        profile_info = @@.conanprofile_resolver profile_template, @profile, @config
        Validation\check profile_info, "Missing profile definition for profile: #{@name} (#{@profile})"
        profile_info.settings.build_type = @config

        for section, values in pairs profile_info
            updated_values = {}
            for key, value in pairs values
                updated_values[key] = value\gsub '$%(([a-zA-Z0-9_]+)%)', (val) ->
                    @variables[val] or ''
            profile_info[section] = updated_values
        profile_info

    _build_conanfile_object: (conanfile_template_file) =>
        conanfile_template = INIConfig\open conanfile_template_file
        conanfile_info = @@.conanfile_resolver conanfile_template, @profile, @config

        for section, values in pairs conanfile_info
            updated_values = {}
            for key, value in pairs values
                updated_values[key] = value\gsub '$%(([a-zA-Z0-9_]+)%)', (val) ->
                    @variables[val] or ''
            conanfile_info[section] = updated_values
        conanfile_info

class ConanProfiles
    @find_required_profiles = (outdir, opts = {force:false}) =>
        conan_dir = Path\join outdir, 'conan'
        conan_profiles_file = Path\join conan_dir, 'required_profiles.txt'
        unless Dir\exists conan_dir then Dir\create conan_dir

        fbuild_config = Path\join outdir, 'fbuild.bff'
        Validation\assert (File\exists fbuild_config), "Can't generate '#{conan_profiles_file}' file, missing fastbuild config expected at '#{fbuild_config}'"

        -- Execute FBuild to generate conan_profiles.txt
        if (not File\exists conan_profiles_file) or opts.force
            FastBuild!\build
                config:fbuild_config
                target:'conan-profiles'

        Validation\assert (File\exists conan_profiles_file), "The `profiles` file is not valid! No valid profile lists where loaded! => '#{profiles_file}'"
        ConanProfiles conan_profiles_file, conan_dir

    new: (@file, conan_dir) =>
        @list = { }
        if @config = INIConfig\open @file
            @rawlist = @config\section 'conan-profiles', 'list'
            for name in *@rawlist
                location = Path\join conan_dir, (name\lower!\gsub '%-', '_')
                table.insert @list, ConanProfile name, location, @config\section name, 'map'

    install_all: (opts = {force:false}) =>
        profile\install opts for profile in *@list


{ :ConanProfiles }
