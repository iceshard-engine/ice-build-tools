import Json from require "ice.util.json"
import ConanProfileGenerator from require "ice.generators.conan_profile"

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

    get_file: => "#{@get_location!}/conan_profile.txt"
    get_location: => "#{@location}/conan_#{@id}"
    get_build_type: => @profile.build_type

    generate: =>
        profile_path = @get_location!
        os.mkdirs profile_path unless os.isdir profile_path

        @profile\generate @get_file!

class ProfileList
    @from_file: (path) =>
        result = nil
        if file = io.open path, "rb"
            result = @from_json file\read "*all"
            file\close!
        result

    @from_json: (json_config) =>
        config = Json\decode json_config

        profiles = { }
        for entry in *config
            assert entry.os ~= nil, "#{entry.name} is missing 'os' value."
            assert entry.arch ~= nil, "#{entry.name} is missing 'arch' value."
            assert entry.compiler ~= nil, "#{entry.name} is missing 'compiler' value."
            assert entry.build_type ~= nil, "#{entry.name} is missing 'build_type' value."
            assert entry.id ~= nil, "#{entry.name} is missing 'id' value."

            if os.iswindows
                table.insert profiles, entry if entry.os\lower! == "windows"
            else if os.isunix
                table.insert profiles, entry if entry.os\lower! == "linux"
            else
                print "System '#{entry.os}' in profile #{entry.name} is not supported."

        profile_map = { }
        for profile in *profiles
            assert profile_map[profile.id] == nil
            profile_map[profile.id] = profile_map

        return ProfileList profiles

    new: (@profiles_list) =>

    has_profiles: => @profiles_list ~= nil and #@profiles_list > 0
    prepare_profiles: (location) =>
        profiles = { }
        for profile_info in *@profiles_list
            table.insert profiles, Profile location, profile_info
        profiles

{ :ProfileList, :Profile }
