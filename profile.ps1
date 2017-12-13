﻿trap { Write-Warning ($_.ScriptStackTrace | Out-String) }
# This timer is used by Trace-Message, I want to start it immediately
$TraceVerboseTimer = New-Object System.Diagnostics.Stopwatch
$TraceVerboseTimer.Start()

## Set the profile directory first, so we can refer to it from now on.
Set-Variable ProfileDir (Split-Path $MyInvocation.MyCommand.Path -Parent) -Scope Global -Option AllScope, Constant -ErrorAction SilentlyContinue

# Ensure that PSHome\Modules is there so we can load the default modules
$Env:PSModulePath += ";$PSHome\Modules"

# These will get loaded automatically, but it's faster to load them explicitly all at once
Import-Module Microsoft.PowerShell.Management,
              Microsoft.PowerShell.Security,
              Microsoft.PowerShell.Utility,
              ZLocation,
              Environment,
              Configuration,
              posh-git,
              posh-docker,
              Profile,
              DefaultParameter -Verbose:$false

# Load scripts from Scriptdir
@() | % { . $_ }

# For now, CORE edition is always verbose, because I can't test for KeyState
if("Core" -eq $PSVersionTable.PSEdition) {
    $VerbosePreference = "Continue"
} else {
    # Check SHIFT state ASAP at startup so I can use that to control verbosity :)
    Add-Type -Assembly PresentationCore, WindowsBase
    try {
        if([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -OR
           [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)) {
            $VerbosePreference = "Continue"
        }
    } catch {}
}

# First call to Trace-Message, pass in our TraceTimer that I created at the top to make sure we time EVERYTHING.
# This has to happen after the verbose check, obviously
Trace-Message "Modules Imported" -Stopwatch $TraceVerboseTimer

# I prefer that my sessions start in my profile directory
if($ProfileDir -ne (Get-Location)) { Set-Location $ProfileDir }

## Add my Projects folder to the module path
$Env:PSModulePath = Select-UniquePath "$ProfileDir\Modules" (Get-SpecialFolder *Modules -Value) ${Env:PSModulePath} "${Home}\Projects\Modules"
Trace-Message "Env:PSModulePath Updated"

## This function cannot be in a module (else it will import the module to a nested scope)
function Reset-Module {
    <#
    .Synopsis
        Remove and re-import a module to force a full reload
    #>
    param($ModuleName)
    Microsoft.PowerShell.Core\Remove-Module $ModuleName
    Microsoft.PowerShell.Core\Import-Module $ModuleName -force -pass | Format-Table Name, Version, Path -Auto
}

Trace-Message "Profile Finished!" -KillTimer
Remove-Variable TraceVerboseTimer

# Custom Aliases
Set-Alias l ls
Set-Alias which Get-Command
Set-Alias grep Find-Matches

function rmrf($path) {
  rm -Recurse -Force $path
}

function mkcd($path) {
  mkdir $path
  cd $path
}

function ltr() {
    ls | Sort-Object { $_.LastWriteTime }
}

## Relax the code signing restriction so we can actually get work done
try { Set-ExecutionPolicy RemoteSigned Process } catch [PlatformNotSupportedException] {}

$VerbosePreference = "SilentlyContinue"

function Test-IsAdmin
{
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function prompt {
    $time = (Get-Date).ToString("hh:mm:ss")
    $username = (gc env:\USERNAME).ToLower()
    $computername = (gc env:\COMPUTERNAME).ToLower()
    $currentPath = (pwd).Path.Replace((gc env:\USERPROFILE), '~')

    $userForeground = 'Yellow'
    if(Test-IsAdmin) {
        $userForeground = 'DarkRed'
    }

    Write-Host -NoNewline "$time "
    Write-Host -NoNewline $username -ForegroundColor $userForeground
    Write-Host -NoNewline '@'
    Write-Host -NoNewline $computername
    Write-Host -NoNewline ':'
    Write-Host -NoNewline '[' -ForegroundColor Cyan
    Write-Host -NoNewline $currentPath -ForegroundColor Cyan
    Write-Host -NoNewline ']' -ForegroundColor Cyan
    Write-VcsStatus
    Write-Host -NoNewline ' $'
    return ' '
}
