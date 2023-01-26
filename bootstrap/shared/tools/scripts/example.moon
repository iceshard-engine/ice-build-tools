print "This is an example script (no arguments)" if #arg == 0
if #arg > 0
    args_concat = table.concat arg, ' '
    print "This is an example script (#{args_concat})"
