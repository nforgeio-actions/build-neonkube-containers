#Requires -Version 7.0 -RunAsAdministrator
#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

# Verify that we're running on a properly configured neonFORGE jobrunner 
# and import the deployment and action scripts from neonCLOUD.

# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.

$ncRoot = $env:NC_ROOT

if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Push-Location $ncPowershell
. ./includes.ps1
Pop-Location

try
{
    # Read the inputs

    # $images   = Get-ActionInput     "images"    $true
    # $options  = Get-ActionInput     "options"   $false
    # $buildLog = Get-ActionInput     "build-log" $true

 $prune    = $false
 $publish  = $false
 $images   = "all"
 $options  = ""
 $buildLog = "C:\Temp\build.log"

    if ([System.String]::IsNullOrWhitespace($images))
    {
        throw "The [options] input is required."
    }

    # Scan the [options] input

    $prune   = $options.Contains("prune")
    $publish = $options.Contains("publish")

    # Scan the [images] input to determine which containers we're building

    $all     = $images.Contains("all")
    $base    = $images.Contains("base")
    $other   = $images.Contains("other")
    $service = $images.Contains("service")
    $test    = $images.Contains("test")

    # Configure the [$/neonKUBE/Images/publish.ps1] script options

    $allOption     = ""
    $baseOption    = ""
    $otherOption   = ""
    $serviceOption = ""
    $testOption    = ""
    $noPruneOption = ""
    $noPushOption  = ""

    if ($all)
    {
        $allOption = "-all"
    }

    if ($base)
    {
        $allOption = "-base"
    }

    if ($other)
    {
        $allOption = "-other"
    }

    if ($service)
    {
        $allOption = "-service"
    }

    if ($test)
    {
        $allOption = "-test"
    }

    if (!$prune)
    {
        $noPruneOption = "-noprune"
    }

    if (!$publish)
    {
        $noPushOption = "-nopush"
    }

    # Set default outputs

    Set-ActionOutput "success" "true"
    Set-ActionOutput "build-log" $buildLog

    # Fetch the current branch and commit from git

    Push-Location $env:NF_ROOT

        $branch = $(& git branch --show-current).Trim()
        ThrowOnExitCode

        $commit = $(& git rev-parse HEAD).Trim()
        ThrowOnExitCode

    Pop-Location

    Set-ActionOutput "build-branch" $branch
    Set-ActionOutput "build-commit" $commit

    # Execute the build/publish script

    $scriptPath = [System.IO.Path]::Combine($env:NF_ROOT, "Images", "publish.ps1")

    Write-ActionOutput "Building container images"
    pwsh -f $scriptPath $allOption $baseOption $otherOption $serviceOption $testOption $noPruneOption $noPushOption > $buildLog
    ThrowOnExitCode

    # Make all of the images public if we published

    if ($publish)
    {
        Write-ActionOutput "Making container images public"
        Set-GitHub-Container-Visibility registryOrg "*"
    }
}
catch
{
    Write-ActionException $_
    Set-ActionOutput "success" "false"
}
