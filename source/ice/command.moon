argument = (name, tab) -> func:'argument', name:name, opts:tab or { }
option = (name, tab) -> func:'option', name:name, opts:tab or { }
flag = (name, tab) -> func:'flag', name:name, opts:tab or { }

class Command
    @arguments = (defined_args) =>
        @.args = { }
        @.ordered_args = { }
        for { :func, :name, :opts } in *defined_args
            opts.name = opts.name or (func == 'argument' and name) or "--#{name}"

            @.args[name] = { :func, :name, :opts }
            table.insert @.ordered_args, @.args[name]

    @argument_options = (name) =>
        @.args[name].opts

    new: (@parser) =>
        @init! if @init

        if @@.ordered_args
            for { :func, :opts } in *@@.ordered_args
                @parser[func] @parser, opts

    prepare: => nil
    execute: => true

{ :Command, :argument, :option, :flag }
