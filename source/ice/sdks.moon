import Validation from require "ice.core.validation"
import Locator from require "ice.locator"
import Setting from require "ice.settings"

sdks_list = { }
sdks_map = { }

Setting 'sdks.local_install_path', default:'build/sdks'

class SDKList
    @root = => Setting\get 'sdks.local_install_path'

    @add = (locator) =>
        if Validation\ensure (locator.type == Locator.Type.PlatformSDK or locator.type == Locator.Type.CommonSDK), "Locator '#{locator.name}' is not a valid SDK locator. (type: #{locator.type})"
            table.insert sdks_list, locator
            sdks_map[locator.id] = locator

    @find = (id) => sdks_map[id]

    @each = (fn) =>
        table.sort sdks_list, (a, b) -> a < b
        fn sdk for sdk in *sdks_list

{ :SDKList }
