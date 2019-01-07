# nlohmann-json-nuget

[NuGet](https://www.nuget.org/) package for Niels Lohmann's [JSON for Modern C++](https://github.com/nlohmann/json) single-header library.

## Usage
Add `nlohmann.json.x.y.z` package from official nuget.org source.

## Packaging
1. Download the latest NuGet command-line interface (nuget.exe) from https://www.nuget.org/downloads and copy to this folder.
2. Copy the latest library header file to `include\nlohmann\json.hpp`
3. Edit `pack.cmd` and update version number
4. Execute `pack.cmd`
