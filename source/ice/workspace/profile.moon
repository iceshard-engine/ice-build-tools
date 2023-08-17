import Json from require "ice.util.json"
import ConanProfileGenerator from require "ice.generators.conan_profile"

import Path, File, Dir from require "ice.core.fs"
import Validation from require "ice.core.validation"
import INIConfig from require "ice.util.iniconfig"

class Profile
    new: (@location, info) =>
        @id = info.id
        @compiler = info.compiler
        @os = info.os
        @arch = info.arch
        @build_type = info.build_type
        @profile = ConanProfileGenerator!
        @profile\set_compiler info.compiler.name, (info.compiler.conan_version or info.compiler.version), info.compiler.libcxx
        @profile\set_system info.os
        @profile\set_architecture info.arch
        @profile\set_build_type info.build_type
        @profile\set_envvar name, value for name, value in pairs info.envs or { }

    get_file: => Path\join @get_location!, "conan_profile.txt"
    get_location: => Path\join @location, "conan_#{@id}"
    get_build_type: => @profile.build_type

    generate: =>
        profile_path = @get_location!
        Dir\create profile_path

        @profile\generate @get_file!

class ProfileList
    @from_file: (path) =>
        @from_string File\load path, mode:'r'

    @from_string = (string) =>
        @from_json Json\decode string if string ~= ""

    @from_json: (config) =>
        return unless Validation\ensure config ~= nil, "Cannot't parse profile from 'nil', Json object expected!"

        profiles = { }
        for entry in *config
            Validation\assert entry.os ~= nil, "#{entry.name} is missing 'os' value."
            Validation\assert entry.arch ~= nil, "#{entry.name} is missing 'arch' value."
            Validation\assert entry.compiler ~= nil, "#{entry.name} is missing 'compiler' value."
            Validation\assert entry.build_type ~= nil, "#{entry.name} is missing 'build_type' value."
            Validation\assert entry.id ~= nil, "#{entry.name} is missing 'id' value."

            if os.iswindows
                table.insert profiles, entry if entry.os\lower! == "windows"
            else if os.isunix
                table.insert profiles, entry if entry.os\lower! == "linux"
            else
                Log\error "System '#{entry.os}' in profile '#{entry.name}' is not supported."

        profile_map = { }
        for profile in *profiles
            Validation\assert profile_map[profile.id] == nil
            profile_map[profile.id] = profile_map

        return ProfileList profiles

    new: (@profiles_list) =>

    has_profiles: => @profiles_list ~= nil and #@profiles_list > 0
    prepare_profiles: (location) =>
        profiles = { }
        for profile_info in *@profiles_list
            table.insert profiles, Profile location, profile_info
        profiles

class ConanProfiles
    new: (@file, output_dir) =>
        if @config = INIConfig\open @file
            @rawlist = @config\section 'conan-profiles', 'list'
            @list = { }
            for name in *@rawlist
                profile, config = name\match "([a-zA-Z0-9_%-]+)%-([a-zA-Z0-9_]+)$"
                table.insert @list, {
                    name:name
                    location:Path\join output_dir, 'conan', (name\lower!\gsub '%-', '_')
                    profile:profile,
                    config:config
                    variables:(@config\section name, 'map') or { }
                }

{ :ProfileList, :Profile, :ConanProfiles }
