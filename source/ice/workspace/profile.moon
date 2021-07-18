import Json from require "ice.util.json"
import ConanProfileGenerator from require "ice.generators.conan_profile"

class Profile
    new: (@location, @system, @arch, @compiler, @build_types) =>
        @profile = ConanProfileGenerator!
        @profile\set_compiler @compiler.name, @compiler.version, @compiler.libcxx
        @profile\set_system @system
        @profile\set_architecture @arch

    get_profile_paths: =>
        profile_paths = { }
        for build_type in *@build_types
            profile_path = "conan_#{build_type\lower!}"
            table.insert profile_paths, profile_path
        profile_paths

    get_profile_pairs: =>
        profile_pair = { }
        for build_type in *@build_types
            profile_path = "conan_#{build_type\lower!}"
            table.insert profile_pair, { build_type, profile_path }
        profile_pair

    generate_conan_profiles: =>
        profile_paths = { }
        for build_type in *@build_types
            profile_path = "#{@location}/conan_#{build_type\lower!}"
            table.insert profile_paths, profile_path

            os.mkdirs profile_path unless os.isdir profile_path

            @profile\set_build_type build_type
            @profile\generate "#{profile_path}/conan_profile.txt"

        profile_paths

class ProfileList
    @from_file: (path) =>
        result = nil
        if file = io.open path, "rb"
            result = @from_json file\read "*all"
            file\close!
        result

    @from_json: (json_config) =>
        config = Json\decode json_config

        system = nil
        arch = "x86_64"
        if os.iswindows
            config = config.windows
            system = "Windows"
        elseif os.isunix
            config = config.linux
            system = "Linux"
        else
            error "This platform is not supported!"

        return ProfileList config, system, arch

    new: (@config_list, @system, @arch) =>

    prepare_profile: (location, profile_name) =>
        profile_name = @config_list.default if profile_name == nil
        config = @config_list[profile_name]

        Profile location, config.os or @system, config.architecture or @arch, config.compiler, config.build_types

{ :ProfileList, :Profile }
