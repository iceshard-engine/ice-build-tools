import Validation from require "ice.core.validation"

class Version
    @from_str: (str) =>
        major, rem = str\match "(%d+)%.(.*)"
        minor, rem = rem\match "(%d+)%.(.*)" if rem
        patch, rem = rem\match "(%d+)(.*)" if rem

        return nil unless major
        Version major, minor, patch, rem

    new: (@major, @minor, @patch, @remaining) =>
    newer: (other) =>
        if (tonumber (@major or 0)) == (tonumber (other.major or 0))
            if (tonumber (@minor or 0)) == (tonumber (other.minor or 0))
                return (tonumber (@patch or 0)) > (tonumber (other.patch or 0))
            return (tonumber (@minor or 0)) > (tonumber (other.minor or 0))
        return (tonumber (@major or 0)) > (tonumber (other.major or 0))

    __tostring: => "#{@major}" .. (@minor and ".#{@minor}" or '') .. (@patch and ".#{@patch}" or '') .. (@remaining or '')

    __eq: (o) =>
        oc = major:o.major or 0, minor:o.minor or 0, patch:o.patch or 0

        return false if @major ~= oc.major
        return false if @minor ~= oc.minor
        return @patch == oc.patch

    __le: (o) =>
        oc = major:o.major or 0, minor:o.minor or 0, patch:o.patch or 0

        return false if @major >= oc.major
        return false if @minor >= oc.minor
        return @patch <= oc.patch

    __lt: (o) =>
        oc = major:o.major or 0, minor:o.minor or 0, patch:o.patch or 0

        return false if @major > oc.major
        return false if @minor > oc.minor
        return @patch < oc.patch

{ :Version }
