# IceShard build tools

This repository holds the source files which are used to build the command line tools for other projects.

## Conan info

This repository defines a conan package script and is uploaded on the `conan.iceshard.net` remote.

### Installation

Just add the below conan repositories

```bash
conan remote add conan-iceshard https://conan.iceshard.net/
conan remote add conan-bincrafters https://api.bintray.com/conan/bincrafters/public-conan
```

And add `ice-build-tools/0.0.4@iceshard/stable` to your conanfile.txt

```ini
[requires]
ice-build-tools/0.0.4@iceshard/stable
```
