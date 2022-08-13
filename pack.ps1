
$headerPath = "include\single_include\nlohmann\json.hpp";

if (-not(Test-Path $headerPath -PathType Leaf)) {
	echo "Please download release files and extract to '$headerPath'";
} else {
	$headerContent = Get-Content $headerPath;
	$major = ($headerContent | Select-String -Pattern "#define NLOHMANN_JSON_VERSION_MAJOR (\d+)").Matches[0].Groups[1].Value;
	$minor = ($headerContent | Select-String -Pattern "#define NLOHMANN_JSON_VERSION_MINOR (\d+)").Matches[0].Groups[1].Value;
	$patch = ($headerContent | Select-String -Pattern "#define NLOHMANN_JSON_VERSION_PATCH (\d+)").Matches[0].Groups[1].Value;
	$version = "$major.$minor.$patch";
	
	& ".\nuget.exe" pack ".\nlohmann.json.nuspec" -Version $version;
	& ".\nuget.exe" pack ".\nlohmann.json.decomposed.nuspec" -Version $version;
}
