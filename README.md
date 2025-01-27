# nlohmann-json-nuget

[NuGet package](https://www.nuget.org/packages/nlohmann.json/) for Niels Lohmann's [JSON for Modern C++](https://github.com/nlohmann/json).

There are two separate packages to choose from. You only need one of them:

 - [`nlohmann.json`](https://www.nuget.org/packages/nlohmann.json/) contans the single-header version **(recommended)**
 - [`nlohmann.json.decomposed`](https://www.nuget.org/packages/nlohmann.json.decomposed/) contans the version with decomposed headers. Use it when you need finer control over what to include.

## Usage
Add [`nlohmann.json` package](https://www.nuget.org/packages/nlohmann.json/) from official nuget.org source. You can do this via Visual Studio (by right-clicking on your C++ project and choosing *Manage NuGet Packages*, or you can use package manager command-line (accessible from menu bar *TOOLS > NuGet Package Manager > Package Manager Console*):

```
PM> Install-Package nlohmann.json -Version x.x.x
```

## Packaging
1. Download the latest NuGet command-line interface (nuget.exe) from https://www.nuget.org/downloads and copy to this folder.
2. In a Visual Studio command-line, run the `pack.ps1` script passing the version you want to create a package for:

```
.\pack.ps1 -Version "v3.11.3"
```
