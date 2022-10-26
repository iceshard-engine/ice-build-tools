argument = (name, tab) -> func:'argument', name:name, opts:tab or { }
option = (name, tab) -> func:'option', name:name, opts:tab or { }
flag = (name, tab) -> func:'flag', name:name, opts:tab or { }

class Command
    @arguments = (defined_args) =>
        @.args = { }
        for { :func, :name, :opts } in *defined_args
            opts.name = opts.name or "--#{name}"
            @.args[name] = { :func, :name, :opts }

    new: (@parser) =>
        @init! if @init

        if @@.args
            for _, { :func, :opts } in pairs @@.args
                @parser[func] @parser, opts

    prepare: => nil
    execute: => true

{ :Command, :argument, :option, :flag }
