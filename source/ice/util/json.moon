import encode, decode from require "json"

class Json
    @encode = (...) => encode ...
    @decode = (...) => decode ...

{ :Json }
