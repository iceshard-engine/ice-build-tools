class Linux
    @detect: =>
        sdk_list = { }

        if os.isunix
            sdk_info = {
                name: 'SDK-Linux'
                struct_name: 'SDK_Linux'
                includedirs: { }
                libdirs: { }
                libs: { }
            }
            table.insert sdk_list, sdk_info

        sdk_list

{ :Linux }
