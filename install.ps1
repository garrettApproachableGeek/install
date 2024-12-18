$ErrorActionPreference = "Stop"

$installDirectory = [IO.Path]::Combine($home, ".shorebird")

function Test-GitInstalled {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Debug "Git is installed."
    }
    else {
        Write-Output "No git installation detected. Git is required to use shorebird."
        exit 1
    }
}

function Compare-GitVersions {
    param (
        [string]$version1,
        [string]$version2
    )

    $version1Components = $version1 -split '\.'
    $version2Components = $version2 -split '\.'

    for ($i = 0; $i -lt 3; $i++) {
        $version1Number = [int]$version1Components[$i]
        $version2Number = [int]$version2Components[$i]

        if ($version1Number -lt $version2Number) {
            return -1
        }
        elseif ($version1Number -gt $version2Number) {
            return 1
        }
    }

    return 0
}

function Test-GitVersion {
    $minGitVersion = "2.25.1"
    $gitVersion = (Get-Item (Get-Command git).Source).VersionInfo.ProductVersionRaw
    $comparisonResult = Compare-GitVersions -version1 $gitVersion -version2 $minGitVersion
    if ($comparisonResult -eq -1) {
        Write-Output "Installed git version $gitVersion is older than required git version $minGitVersion."
        exit 1
    }
}

function Update-Path {
    $path = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($path.contains($installDirectory)) {
        return $false
    }
    $binPath = [IO.Path]::Combine($installDirectory, "bin")
    [Environment]::SetEnvironmentVariable(
        "Path", $path + [IO.Path]::PathSeparator + $binPath, "User"
    )

    return $true
}

Test-GitInstalled
Test-GitVersion

$force = $args -contains "--force"

# Check if there is enough free space
$requiredSpace = 1100MB # 1100 MiB
$installDrive = (Split-Path -Qualifier $installDirectory).TrimEnd(':')
$freeSpace = (Get-PSDrive -Name $installDrive).Free
if ($freeSpace -lt $requiredSpace) {
    if ($force) {
        Write-Output "Attempting Shorebird install with less than 1100 MiB of free space."
    }
    else {
        Write-Output "Error: Not enough free space. At least 1100 MiB is required. Use --force to install anyway."
        exit 1
    }
}

if (Test-Path $installDirectory) {
    if ($force) {
        Write-Output "Existing Shorebird installation detected. Overwriting..."
        Remove-Item -Recurse -Force $installDirectory
    }
    else {
        Write-Output "Error: Existing Shorebird installation detected. Use --force to overwrite."
        return
    }
}

Write-Output "Installing Shorebird to $installDirectory..."

& git clone https://github.com/shorebirdtech/shorebird.git -b stable $installDirectory

Push-Location $installDirectory\bin
& .\shorebird.ps1 --version
Pop-Location

$wasPathUpdated = Update-Path
# 1F426 is the code for 🐦. See https://unicode.org/emoji/charts/full-emoji-list.html#1f426.
$birdEmoji = [System.Char]::ConvertFromUtf32([System.Convert]::toInt32("1F426", 16))

Write-Output @"

$birdEmoji Shorebird has been installed!

"@

if ($wasPathUpdated) {
    Write-Output @"
Please restart your terminal to start using Shorebird.
"@
}

Write-Output @"
To create an account, visit: https://console.shorebird.dev
Then login using:

  shorebird login

For more information, visit:
https://docs.shorebird.dev
"@
