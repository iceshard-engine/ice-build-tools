
class ConanProfileGenerator
    new: (@output) =>
        @settings = { }
        @options = { }
        @env = { }

    set_system: (os) =>
        @settings.os = os

    set_architecture: (arch) =>
        @settings.arch = arch

    set_compiler: (name, version, libcxx) =>
        @settings.compiler = { :name, :version, :libcxx }

    set_build_type: (build_type) =>
        @settings.build_type = build_type

    set_option: (name, value) =>
        table.insert @options, { :name, :value }

    set_envvar: (name, value) =>
        table.insert @env, { :name, :value }

    generate: (output) =>
        sorted_options = @options
        sorted_envs = @env
        table.sort sorted_options, (a, b) -> a.name < b.name
        table.sort sorted_envs, (a, b) -> a.name < b.name

        if @file = io.open output, 'w+'
            line = (value) ->
                @file\write "#{value or ''}\n"

            -- Conan decided to use even a weirder msvc versioning number....
            conan_msvc_versions = {
                'msvc17': 193
                'msvc16': 192
                'msvc14': 191
            }

            line!
            line "[settings]"
            line "os=#{@settings.os}"
            line "arch=#{@settings.arch}"
            line "compiler=#{@settings.compiler.name}"
            line "compiler.version=#{conan_msvc_versions[@settings.compiler.name..@settings.compiler.version] or @settings.compiler.version}"
            line "compiler.libcxx=#{@settings.compiler.libcxx}" if @settings.compiler.libcxx
            line "compiler.runtime=dynamic"
            line "build_type=#{@settings.build_type}"
            line "[options]"
            line "#{name}=#{value}" for { :name, :value } in *sorted_options or { }
            line "[buildenv]"
            line "#{name}=#{value}" for { :name, :value } in *sorted_envs or { }
            line!

            @file\close!

        else
            error "Couldn't open file #{output} for generating a Conan profile"

{ :ConanProfileGenerator }
