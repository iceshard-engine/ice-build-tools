
option = (name, tab) -> func:'option', name:name, opts:tab
flag = (name, tab) -> func:'flag', name:name, opts:tab

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


{ :Command, :option, :flag }
