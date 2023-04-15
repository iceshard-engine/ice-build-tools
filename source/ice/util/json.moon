import encode, decode from require "rxi.json"

class Json
    @encode = (...) => encode ...
    @decode = (...) => decode ...

{ :Json }
