
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
        sorted_options = table.sort @options, (a, b) -> a.name < b.name
        sorted_envs = table.sort @env, (a, b) -> a.name < b.name

        if @file = io.open output, 'w+'
            line = (value) ->
                @file\write "#{value or ''}\n"

            line!
            line "[settings]"
            line "os=#{@settings.os}"
            line "arch=#{@settings.arch}"
            line "os_build=#{@settings.os}"
            line "arch_build=#{@settings.arch}"
            line "compiler=#{@settings.compiler.name}"
            line "compiler.version=#{@settings.compiler.version}"
            line "compiler.libcxx=#{@settings.compiler.libcxx}" if @settings.compiler.libcxx
            line "build_type=#{@settings.build_type}"
            line "[options]"
            line "#{name}=#{value}" for name, value in pairs sorted_options or { }
            line "[env]"
            line "#{name}=#{value}" for name, value in pairs sorted_envs or { }
            line!

            @file\close!

        else
            error "Counln't open file #{output} for generating a Conan profile"

{ :ConanProfileGenerator }
