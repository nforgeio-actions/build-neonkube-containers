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

    $prune   = Get-ActionInputBool "prune"   $true
    $publish = Get-ActionInputBool "publish" $true
    $options = Get-ActionInput     "options" $true

    if ([System.String]::IsNullOrWhitespace($options))
    {
        throw "The [options] input is required."
    }

    # Scan the [options] input to determine which containers we're building

    $all     = $options.Contains("all")
    $base    = $options.Contains("base")
    $other   = $options.Contains("other")
    $service = $options.Contains("service")
    $test    = $options.Contains("test")

    # Configure the [$/neonKUBE/Images/publish.ps1] script options

    $allOption     = ""
    $baseOption    = ""
    $otherOption   = ""
    $serviceOption = ""
    $testOptions   = ""
    $noPrune       = ""
    $noPush        = ""

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
        $noPrune = "-noprune"
    }

    if (!$push)
    {
        $noPush = "-nopush"
    }

    # Execute the build/publish script

    $scriptPath = [System.IO.Path]::Combine($env:NF_ROOT, "Images", "publish.ps1")

    pwsh -f $scriptPath $allOption $baseOption $otherOption $serviceOption $testOptions $noPrune $noPush
    ThrowOnExitCode
}
catch
{
    Write-ActionException $_
    exit 1
}