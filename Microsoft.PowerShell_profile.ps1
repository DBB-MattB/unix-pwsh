$githubUser = "DBB-MattB" # Change this here if you forked the repository.
$name= "Matt" # Change this to your name.
$githubRepo = "unix-pwsh" # Change this here if you forked the repository and changed the name.
$githubBaseURL= "https://raw.githubusercontent.com/$githubUser/$githubRepo/main"
$OhMyPoshConfigFileName = "montys.omp.json" # Filename of the OhMyPosh config file
$OhMyPoshConfig = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$OhMyPoshConfigFileName" # URL of the OhMyPosh config file, make sure to use the last part of the raw lik, (stands for the filename) in the variable on the line below

# -----------------------------------------------------------------------------

# Check internet access
# Use WMI as there is no timeout in PowerShell 5.0 and it is generally slow.
$timeout = 1000 
$pingResult = Get-CimInstance -ClassName Win32_PingStatus -Filter "Address = 'github.com' AND Timeout = $timeout" -Property StatusCode 2>$null
if ($pingResult.StatusCode -eq 0) {
    $canConnectToGitHub = $true
} else {
    $canConnectToGitHub = $false
}

# Define vars.
$baseDir = "$HOME\unix-pwsh"
$configPath = "$baseDir\pwsh_custom_config.yml"
$xConfigPath = "$baseDir\pwsh_full_custom_config.yml" # This file exists if the prompt is fully installed with all dependencies.
$promptColor = "DarkCyan" # Choose a colour in which the hello text is colored; All Colours: Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, DarkRed, DarkYellow, Grey, Green, Magenta, Red, White, Yellow.
$font="Hack" # Font-Display and variable Name, name the same as font_folder
$font_url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/Hack.zip" # Put here the URL of the font file that should be installed
$fontFileName = "HackNerdFont-Regular.ttf" # Put here the font file that should be installed
$font_folder = "Hack" # Put here the name of the zip folder of the downloaded font, but without the .zip extension.

$modules = @( 
    # This is a list of modules that need to be imported/installed
    @{ Name = "Powershell-Yaml"; ConfigKey = "Powershell-Yaml_installed" },
    @{ Name = "Terminal-Icons"; ConfigKey = "Terminal-Icons_installed" },
    @{ Name = "PoshFunctions"; ConfigKey = "PoshFunctions_installed" }
)
$files = @("Microsoft.PowerShell_profile.ps1", "installer.ps1", "pwsh_helper.ps1", "functions.ps1", $OhMyPoshConfigFileName)

# Message to tell the user what to do after installation
$infoMessage = @"
To fully utilise the custom Unix-pwsh profile, please follow these steps:
1. Set Windows Terminal as the default terminal.
2. Choose PowerShell Core as the preferred startup profile in Windows Terminal.
3. Go to Settings > Defaults > Appearance > Font and select the Nerd Font.

These steps are necessary to ensure the pwsh profile works as intended.
If you have further questions on how to set the above, don't hesitate to ask me by filing an issue on my repository after you have tried searching the web for yourself.
"@

$scriptBlock = {
    param($githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL)
    Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/pwsh_helper.ps1" -UseBasicParsing).Content
    BackgroundTasks
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

# Function for calling the update PowerShell Script
function Run-UpdatePowershell {
    . Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/pwsh_helper.ps1" -UseBasicParsing).Content
    Update-Powershell
}

# ----------------------------------------------------------------------------

Write-Host ""
Write-Host "Welcome $name ⚡" -ForegroundColor $promptColor
Write-Host ""

# Function to check if all the $files exist or not.
$allFilesExist = $files | ForEach-Object { Join-Path -Path $baseDir -ChildPath $_ } | Test-Path -PathType Leaf -ErrorAction SilentlyContinue | ForEach-Object { $_ -eq $true }
if ($allFilesExist -contains $false) {
    $injectionMethod = "remote"
} else {
    $injectionMethod = "local"
    $OhMyPoshConfig = Join-Path -Path $baseDir -ChildPath $OhMyPoshConfigFileName
}

# Check for dependencies and if not, chainload the installer.
if (Test-Path -Path $xConfigPath) {
    # Check if the Master config file exists; if so, skip every other check.
    Write-Host "✅ Successfully initialized Pwsh`n" -ForegroundColor Green
    Import-Module Terminal-Icons
    # foreach ($module in $modules) {
    #     # As the master config exists, we assume that all modules are installed.
    #     Import-Module $module.Name
    # }
} else {
    # If there is no internet connection, we cannot install anything.
    if (-not $global:canConnectToGitHub) {
        Write-Host "❌ Skipping initialisation due to GitHub not responding within 4 seconds." -ForegroundColor Red
        exit
    }
    . Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/installer.ps1" -UseBasicParsing).Content
    Install-NuGet
    Test-Pwsh 
    Test-CreateProfile
    Install-Config
}

# Try to import MS PowerToys WinGetCommandNotFound
Import-Module -Name Microsoft.WinGet.CommandNotFound > $null 2>&1
if (-not $?) {Install-Module -Name Microsoft.WinGet.CommandNotFound}

# Inject OhMyPosh
oh-my-posh init pwsh --config $OhMyPoshConfig | Invoke-Expression

# ----------------------------------------------------------
# Shell UX: PSReadLine, completions and window title
# (interactive sessions only)
# ----------------------------------------------------------

function Test-InteractiveShell {
    try {
        return $Host.Name -eq 'ConsoleHost' -and
            -not [Console]::IsInputRedirected -and
            -not [Console]::IsOutputRedirected
    } catch {
        return $false
    }
}

$isInteractiveShell = Test-InteractiveShell

function Initialize-PSReadLine {
    if (-not $isInteractiveShell -or -not (Get-Module -ListAvailable -Name PSReadLine)) {
        return
    }

    $options = @{
        EditMode                      = 'Windows'
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        PredictionSource              = 'HistoryAndPlugin'
        PredictionViewStyle           = 'ListView'
        BellStyle                     = 'None'
        MaximumHistoryCount           = 10000
        Colors                        = @{
            Command   = '#87CEEB'
            Parameter = '#98FB98'
            Operator  = '#FFB6C1'
            Variable  = '#DDA0DD'
            String    = '#FFDAB9'
            Number    = '#B0E0E6'
            Type      = '#F0E68C'
            Comment   = '#D3D3D3'
            Keyword   = '#8367c7'
            Error     = '#FF6347'
        }
    }

    if ($PSVersionTable.PSEdition -ne 'Core') {
        # Older PSReadLine on Windows PowerShell 5.1 has no prediction support.
        $options.Remove('PredictionSource')
        $options.Remove('PredictionViewStyle')
    }

    try {
        Set-PSReadLineOption @options
    } catch {
        Write-Warning "Unable to apply PSReadLine options: $_"
    }

    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

    # Keep secrets out of the PSReadLine history file
    Set-PSReadLineOption -AddToHistoryHandler {
        param([string]$line)
        $line -notmatch '(?i)(password|secret|token|apikey|connectionstring)'
    }
}

function Register-CustomCompletion {
    if (-not $isInteractiveShell -or $PSVersionTable.PSEdition -ne 'Core') {
        return
    }

    $completionMap = @{
        git  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        npm  = @('install', 'start', 'run', 'test', 'build')
        deno = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $null = $cursorPosition
        $completionWord = $wordToComplete
        $map = $completionMap
        $command = $commandAst.CommandElements[0].Value
        if ($map.ContainsKey($command)) {
            $map[$command] |
                Where-Object { $_ -like "$completionWord*" } |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }.GetNewClosure()

    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $null = $wordToComplete
            dotnet complete --position $cursorPosition $commandAst.ToString() |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }
}

Initialize-PSReadLine
Register-CustomCompletion

if ($isInteractiveShell) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    try {
        $adminSuffix = if ($isAdmin) { ' [ADMIN]' } else { '' }
        $Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$adminSuffix"
    } catch {
        Write-Verbose "Unable to set console title: $_"
    }

    # Start zoxide only when it is already installed; skip silently if not.
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Invoke-Expression (& { (zoxide init --cmd z powershell | Out-String) })
    }
}

# ----------------------------------------------------------
# Deferred loading
# Source: https://fsackur.github.io/2023/11/20/Deferred-profile-loading-for-better-performance/
# ----------------------------------------------------------

# Check if psVersion is lower than 7.x, then load the functions **without** deferred loading
if ($PSVersionTable.PSVersion.Major -lt 7) {
    if ($injectionMethod -eq "local") {
        . "$baseDir\functions.ps1"
        # Execute the background tasks
        Start-Job -ScriptBlock $scriptBlock -ArgumentList $githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL
        } else {
        if ($global:canConnectToGitHub) {
            #Load Functions
            . Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/functions.ps1" -UseBasicParsing).Content
            # Update PowerShell in the background
            Start-Job -ScriptBlock $scriptBlock -ArgumentList $githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL
                } else {
            Write-Host "❌ Skipping initialisation due to GitHub not responding within 1 second." -ForegroundColor Red
        }
    }
}

# ---------------------------------------------------------

$Deferred = {
    if ($injectionMethod -eq "local") {
        . "$baseDir\functions.ps1"
        # Execute the background tasks
        Start-Job -ScriptBlock $scriptBlock -ArgumentList $githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL
        } else {
        if ($global:canConnectToGitHub) {
            #Load Functions
            . Invoke-Expression (Invoke-WebRequest -Uri "$githubBaseURL/functions.ps1" -UseBasicParsing).Content
            # Update PowerShell in the background
            Start-Job -ScriptBlock $scriptBlock -ArgumentList $githubUser, $files, $baseDir, $canConnectToGitHub, $githubBaseURL
            } else {
            Write-Host "❌ Skipping initialisation due to GitHub not responding within 1 second." -ForegroundColor Red
        }
    }
}


$GlobalState = [psmoduleinfo]::new($false)
$GlobalState.SessionState = $ExecutionContext.SessionState
# to run our code asynchronously
$Runspace = [runspacefactory]::CreateRunspace($Host)
$Powershell = [powershell]::Create($Runspace)
$Runspace.Open()
$Runspace.SessionStateProxy.PSVariable.Set('GlobalState', $GlobalState)
# ArgumentCompleters are set on the ExecutionContext, not the SessionState
# Note that $ExecutionContext is not an ExecutionContext, it's an EngineIntrinsics 😡
$Private = [Reflection.BindingFlags]'Instance, NonPublic'
$ContextField = [Management.Automation.EngineIntrinsics].GetField('_context', $Private)
$Context = $ContextField.GetValue($ExecutionContext)
# Get the ArgumentCompleters. If null, initialise them.
$ContextCACProperty = $Context.GetType().GetProperty('CustomArgumentCompleters', $Private)
$ContextNACProperty = $Context.GetType().GetProperty('NativeArgumentCompleters', $Private)
$CAC = $ContextCACProperty.GetValue($Context)
$NAC = $ContextNACProperty.GetValue($Context)
if ($null -eq $CAC)
{
    $CAC = [Collections.Generic.Dictionary[string, scriptblock]]::new()
    $ContextCACProperty.SetValue($Context, $CAC)
}
if ($null -eq $NAC)
{
    $NAC = [Collections.Generic.Dictionary[string, scriptblock]]::new()
    $ContextNACProperty.SetValue($Context, $NAC)
}
# Get the AutomationEngine and ExecutionContext of the runspace
$RSEngineField = $Runspace.GetType().GetField('_engine', $Private)
$RSEngine = $RSEngineField.GetValue($Runspace)
$EngineContextField = $RSEngine.GetType().GetFields($Private) | Where-Object {$_.FieldType.Name -eq 'ExecutionContext'}
$RSContext = $EngineContextField.GetValue($RSEngine)
# Set the runspace to use the global ArgumentCompleters
$ContextCACProperty.SetValue($RSContext, $CAC)
$ContextNACProperty.SetValue($RSContext, $NAC)
$Wrapper = {
    # Without a sleep, you get issues:
    #   - occasional crashes
    #   - prompt not rendered
    #   - no highlighting
    # Assumption: this is related to PSReadLine.
    # 20ms seems to be enough on my machine, but let's be generous - this is non-blocking
    Start-Sleep -Milliseconds 100
    . $GlobalState {. $Deferred; Remove-Variable Deferred}
}
$null = $Powershell.AddScript($Wrapper.ToString()).BeginInvoke()
