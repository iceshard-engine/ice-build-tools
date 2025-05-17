import Validation from require "ice.core.validation"

class Version
    @from_str: (str) =>
        major, minor, patch = str\gmatch "%d+.%d+.%d+"
        return nil unless major
        Version major, minor, patch

    new: (@major, @minor, @patch) =>
    newer: (other) =>
        if (tonumber (@major or 0)) == (tonumber (other.major or 0))
            if (tonumber (@minor or 0)) == (tonumber (other.minor or 0))
                return (tonumber (@patch or 0)) > (tonumber (other.patch or 0))
            return (tonumber (@minor or 0)) > (tonumber (other.minor or 0))
        return (tonumber (@major or 0)) > (tonumber (other.major or 0))

{ :Version }
