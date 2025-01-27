param(
	[Parameter(Mandatory=$true)]
	[string]$Version
)

$IncludeFullNotes = $false

$ReleaseUrl = "https://api.github.com/repos/nlohmann/json/releases/tags/$Version"
$ZipUrl = "https://github.com/nlohmann/json/releases/download/$Version/include.zip"

$OutputDir = "$Version"
$TestsSourceDir = "tests"



try
{
	################################################################
	#
	# Step 1: download and validate release assets
	#
	################################################################

	$ZipPath = Join-Path $OutputDir "include.zip"
	$NotesPath = Join-Path $OutputDir "release-notes.txt"
	$ReportPath = Join-Path $OutputDir "report.txt"

	New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null

	# Get release metadata
	$Release = Invoke-RestMethod -Uri $ReleaseUrl -Headers @{
		"Accept" = "application/vnd.github+json"
	}
	$Release | ConvertTo-Json -Depth 100 | Out-File -FilePath (Join-Path $OutputDir "release-metadata.json") -Encoding utf8

	# Download include.zip
	Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath

	# Extract SHA-256 from release notes body and ensure file integrity
	$Sha256Pattern = @'
(?misx)
	^\s*SHA-256:\s*  # Start of SHA-256 line
	(?:              # Non-capturing group for multiple entries
		.*?          # Any characters (including newlines)
		(\b[a-fA-F0-9]{64}\b)  # Capture 64-char hash
		\s*\(include\.zip\)    # Look for include.zip marker
	)
'@
	if ($Release.body -match $Sha256Pattern)
	{
		$OfficialChecksum = $matches[1].ToLower()
		$LocalChecksum = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
		if ($LocalChecksum -ne $OfficialChecksum)
		{
			throw @"
Critical checksum mismatch!
- Expected: $OfficialChecksum
- Actual:   $LocalChecksum
Download may be corrupted or tampered with.
"@
		}
		else {
			Write-Host "✅ Checksum validation passed"
		}
	}
	else
	{
		throw "No SHA-256 found in release notes"
	}

	# Extract zip contents (preserves directory structure)
	Expand-Archive -Path $ZipPath -DestinationPath $OutputDir -Force
	Remove-Item $ZipPath

	# Process release notes
	$NotesContent = if ($IncludeFullNotes) {
		$Release.body
	} else {
		# Extract Summary section (case-insensitive, multi-line match)
		if ($Release.body -match '(?si)## Summary(.*?)(?=##|$)') {
			$matches[1].Trim()
		} else {
			$Release.body
		}
	}
	$ReleaseNotesContent = @"
$NotesContent

https://github.com/nlohmann/json/releases/tag/$Version
"@
	$ReleaseNotesContent | Out-File -FilePath $NotesPath -Encoding utf8

	 # Save download report
	@"
Version: $TagName
Processed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
ZipChecksum: $LocalChecksum
"@ | Out-File -FilePath $ReportPath -Encoding utf8



	################################################################
	#
	# Step 2: create NuGet packages
	#
	################################################################

	$HeaderPath = Join-Path $OutputDir "single_include\nlohmann\json.hpp"
	$NuspecTemplates = @("nlohmann.json.nuspec", "nlohmann.json.decomposed.nuspec")

	# Extract semantic version from header file
	if (-not(Test-Path $HeaderPath -PathType Leaf)) {
		throw "Extracted header file does not exist in $HeaderPath"
	} else {
		$HeaderContent = Get-Content $HeaderPath
		$major = ($HeaderContent | Select-String -Pattern "#define NLOHMANN_JSON_VERSION_MAJOR (\d+)").Matches[0].Groups[1].Value
		$minor = ($HeaderContent | Select-String -Pattern "#define NLOHMANN_JSON_VERSION_MINOR (\d+)").Matches[0].Groups[1].Value
		$patch = ($HeaderContent | Select-String -Pattern "#define NLOHMANN_JSON_VERSION_PATCH (\d+)").Matches[0].Groups[1].Value
		$SemanticVersion = "$major.$minor.$patch"

		if ("v$SemanticVersion" -ne $Version) {
			throw "Version mismatch: $SemanticVersion $Version"
		}

		$copyrightLine = $HeaderContent | Select-String -Pattern '^\s*// SPDX-FileCopyrightText:\s*(.*?)\s*$' -List | Select-Object -First 1
		if (-not $copyrightLine) {
			throw "Could not find SPDX copyright line in header file"
		}
		$copyrightText = $copyrightLine.Matches.Groups[1].Value.Trim()
		$copyrightText = $copyrightText -replace '<', '(' -replace '>', ')'
		$copyrightText = [System.Security.SecurityElement]::Escape($copyrightText)
	}

	# Prepare .nuspec files and create packages
	$EscapedReleaseNotes = [System.Security.SecurityElement]::Escape($ReleaseNotesContent)

	foreach ($Template in $NuspecTemplates)
	{
		$TemplatePath = Join-Path $PSScriptRoot $Template
		$NuspecContent = Get-Content -Path $TemplatePath -Raw
		$NuspecContent = $NuspecContent -replace '\$releaseNotes\$', $EscapedReleaseNotes
	    $NuspecContent = $NuspecContent -replace '\$copyrightText\$', $copyrightText

		# Save processed file
		$OutputNuspec = Join-Path $OutputDir $Template
		$NuspecContent | Set-Content -Path $OutputNuspec -Encoding utf8

		# Create the NuGet package 
		& ".\nuget.exe" pack $OutputNuspec -Version $SemanticVersion -OutputDirectory $OutputDir
	}



	################################################################
	#
	# Step 3: test the new NuGet packages
	#
	################################################################

	$TestWorkingDir = Join-Path $OutputDir "tests"
	$TestSolutionPath = Join-Path $TestWorkingDir "Tests.sln"
	$NuGetConfigPath = Join-Path $OutputDir "NuGet.Config"
	$BuildLogPath = Join-Path $OutputDir "msbuild.log"

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
	& ".\nuget.exe" restore $TestSolutionPath -ConfigFile $NuGetConfigPath -Verbosity quiet -NonInteractive
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

	Write-Host "All tests completed successfully!" -ForegroundColor Green



	Write-Host @"
Done. NuGet packages for version $Version successfully created.
"@
}
catch
{
	Write-Host "Error processing version $Version : $_"
	exit 1
}
