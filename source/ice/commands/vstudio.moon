import DevenvCommand from require "ice.commands.devenv"

class VStudioCommand extends DevenvCommand
    new: (...) ->
        print "WARNING: Using deprecated command 'VStudioCommand', please replace it in your workspace with the 'DevenvCommand'"
        super ...

{ :VStudioCommand }
