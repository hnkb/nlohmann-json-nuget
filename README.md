# nlohmann-json-nuget

[NuGet package](https://www.nuget.org/packages/nlohmann.json/) for Niels Lohmann's [JSON for Modern C++](https://github.com/nlohmann/json) single-header library.

## Usage
Add [`nlohmann.json` package](https://www.nuget.org/packages/nlohmann.json/) from official nuget.org source, or use package manager command-line:

```
PM> Install-Package nlohmann.json -Version x.x.x
```

## Packaging
1. Download the latest NuGet command-line interface (nuget.exe) from https://www.nuget.org/downloads and copy to this folder.
2. Copy the [latest single include header file (json.hpp)](https://github.com/nlohmann/json/releases) to `include\nlohmann\json.hpp`
3. Execute `pack.ps1`
