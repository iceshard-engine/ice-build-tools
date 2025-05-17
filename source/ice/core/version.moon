import Validation from require "ice.core.validation"

class Version
    @from_str: (str) =>
        major, rem = (str\gmatch "%d+%.*")!
        minor, rem = (rem\gmatch "%d+%.*")! if rem
        patch, rem = (rem\gmatch "%d+%.*")! if rem

        return nil unless major
        Version major, minor, patch, rem

    new: (@major, @minor, @patch, @remaining) =>
    newer: (other) =>
        if (tonumber (@major or 0)) == (tonumber (other.major or 0))
            if (tonumber (@minor or 0)) == (tonumber (other.minor or 0))
                return (tonumber (@patch or 0)) > (tonumber (other.patch or 0))
            return (tonumber (@minor or 0)) > (tonumber (other.minor or 0))
        return (tonumber (@major or 0)) > (tonumber (other.major or 0))

    __tostring: => "#{@major}" .. (@minor and ".#{@minor}" or '') .. (@patch and ".#{@patch}" or '')

{ :Version }
