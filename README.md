# IceShard Build Tools

This project aims to fill a quite weird gap of "glue-like" utility. Using various tools, it builds a simplified interface for them allowing to maintain projects easier.

At the core it uses 'Conan' for managing packages, including this tool itself. This is also the only dependency to get started.

> There are so many great tools, and yet instead of sticking them together we create new ones.

### Dependencies
- Conan Package Manager

## Installation
To install this utility for your project just follow the instructions on the wiki [page](/iceshard-engine/ice-build-tools/wiki/Project-Setup).

> It's recommended to always install the latest stable version of this tool, since it's still undergoing lots of development and features are added frequently.

## Basic information

Currently IBT supports building with FastBuild out of the box by hiding lots of boilerplate scripts behind the sceene.

This involves locating and generating files consumed by FastBuild scripts.
- Supported Compilers: **MSVC**, **GCC**, **Clang**
- Supported Platforms: **Windows**, **Linux**, ~~Mac~~ *(Not yet available)*
- Supported SDK's: **Windows 10**, **Vulkan**
- Supported C++ package managers: **Conan**
- Supported Build Tools: **FastBuild**

## Extensibility

The project uses **Moonscript** and by extension **Lua** to glue everything together. Because of this, it's very easy to customize at any point, however it's recommended to use prepared extension points.

Currently you can define your own application, commands, settings, locators and much more.

In addition you can change the layout, conan profiles, configurations, platform, pipelines for your C++ setup.

> TODO: Currently there is lots of work put into the wiki pages, which should address each specific feature by itself, but for now questions are apprciated.


## Licenses

This tool uses a slightly modified version of [rix/json.lua](https://github.com/rxi/json.lua/) for json encoding and decoding.
License file: `LICENSES/RXI_JSON_LUA_LICENSE`
Source code: `source/rxi/json.lua`
