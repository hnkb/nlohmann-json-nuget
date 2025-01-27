param(
	[Parameter(Mandatory=$true)]
	[string]$Version
)

$OutputDir = "$Version"
$TestsSourceDir = "tests"

$TestWorkingDir = Join-Path $OutputDir "tests"
$TestSolutionPath = Join-Path $TestWorkingDir "Tests.sln"
$NuGetConfigPath = Join-Path $OutputDir "NuGet.Config"
$BuildLogPath = Join-Path $OutputDir "msbuild.log"


try
{
	$SemanticVersion = $Version -replace '^v', ''

	Remove-Item -Path $TestWorkingDir -Recurse -ErrorAction SilentlyContinue
	New-Item -Path $TestWorkingDir -ItemType Directory -Force | Out-Null

	# 1. Copy test files
	Copy-Item -Path "$TestsSourceDir\*" -Destination $TestWorkingDir -Recurse

	# 2. Replace version placeholders in all files
	Get-ChildItem -Path $TestWorkingDir -Recurse -File | ForEach-Object {
		$content = Get-Content -Path $_.FullName -Raw
		$content = $content -replace '\$packageVersion\$', $SemanticVersion
		$content | Set-Content -Path $_.FullName -Encoding utf8
	}

	# 3. Create NuGet.config
@"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
	<clear />
	<add key="local" value="." />
  </packageSources>
</configuration>
"@ | Set-Content -Path $NuGetConfigPath

	# 4. Build the test project using the new packages
	Write-Host "Restoring NuGet packages..."
	nuget restore $TestSolutionPath -ConfigFile $NuGetConfigPath -Verbosity quiet -NonInteractive
	if ($LASTEXITCODE -ne 0) { throw "NuGet restore failed" }

	Write-Host "Building test projects..."
	msbuild $TestSolutionPath /p:Configuration=Debug /p:Platform=x64 /clp:Summary /v:minimal /nologo /flp:Summary`;Verbosity=normal`;LogFile=$BuildLogPath
	if ($LASTEXITCODE -ne 0) { throw "MSBuild failed" }

	# 5. Test executables
	$executables = @(
		(Join-Path $TestWorkingDir "x64\Debug\TestSingle.exe"),
		(Join-Path $TestWorkingDir "x64\Debug\TestDecomposed.exe")
	)

	foreach ($exe in $executables)
	{
		if (-not (Test-Path $exe)) {
			throw "Executable not found: $exe"
		}

		Write-Host "Testing $exe ..."
		$output = & $exe 2>&1
		$exitCode = $LASTEXITCODE

		if ($exitCode -ne 0) {
			Write-Host "   Test failed for $exe (exit code $exitCode)"
			Write-Host "   Output: $output"
			exit 1
		}

		Write-Host "   Test passed for $exe"
		Write-Host "   Output: $output"
	}

	Write-Host "✅ All tests completed successfully!" -ForegroundColor Green
}
catch
{
	Write-Host "Failed to build test projects with NuGet packages created for version $Version : $_" -ForegroundColor Red
	exit 1
}
