# Functions to mimic some of the functionality of the Unix shell

# URL of the Wastebin (pastebin alternative) server used by ptw/Send-Wastebin.
# Point this at your own server if you run one.
$WastebinServerUrl = "https://bin.crazywolf.dev"

# Does the the rough equivalent of dir /s /b. For example, dirs *.png is dir /s /b *.png
function dirs {
    if ($args.Count -gt 0) {
        Get-ChildItem -Recurse -Include "$args" | Foreach-Object FullName
    } else {
        Get-ChildItem -Recurse | Foreach-Object FullName
    }
}

function sed {
    param(
        [Parameter(Mandatory, Position = 0)][string]$File,
        [Parameter(Mandatory, Position = 1)][string]$Find,
        [Parameter(Mandatory, Position = 2)][string]$Replace
    )
    (Get-Content -Path $File).Replace($Find, $Replace) | Set-Content -Path $File
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pgrep($name) {
    Get-Process $name
}

function grep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)][string]$Pattern,
        [Parameter(Position = 1)][string]$Path,
        [Parameter(ValueFromPipeline)][object]$InputObject
    )
    begin {
        $pipelineInput = [System.Collections.Generic.List[object]]::new()
    }
    process {
        if ($PSBoundParameters.ContainsKey('InputObject')) {
            $pipelineInput.Add($InputObject)
        }
    }
    end {
        if ($Path) {
            Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern $Pattern
        } elseif ($pipelineInput.Count -gt 0) {
            $pipelineInput | Select-String -Pattern $Pattern
        } else {
            Write-Error 'Usage: grep <pattern> [path] or pipe input to grep'
        }
    }
}

function pkill {
    param (
        [string]$Name
    )
    process {
        if ($Name) {
            Get-Process $Name -ErrorAction SilentlyContinue | Stop-Process -Force
        } else {
            $input | ForEach-Object { Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force }
        }
    }
}

function head {
    param (
        [string]$Path,
        [int]$n = 10
    )
    begin {
        $buffer = [System.Collections.Generic.List[object]]::new()
    }
    process {
        if (-not $Path -and $buffer.Count -lt $n) {
            $buffer.Add($_)
        }
    }
    end {
        if ($Path) {
            Get-Content $Path -Head $n
        } else {
            $buffer
        }
    }
}

function tail {
    param (
        [string]$Path,
        [int]$n = 10,
        [switch]$f
    )
    begin {
        $buffer = [System.Collections.Generic.Queue[object]]::new()
    }
    process {
        if (-not $Path) {
            $buffer.Enqueue($_)
            if ($buffer.Count -gt $n) {
                $null = $buffer.Dequeue()
            }
        }
    }
    end {
        if ($Path) {
            Get-Content $Path -Tail $n -Wait:$f
        } else {
            $buffer.ToArray()
        }
    }
}

# Unzip function
function unzip {
    param (
        [string]$file
    )
    process {
        if ($file) {
            $fullPath = Join-Path -Path $pwd -ChildPath $file
            if (Test-Path $fullPath) {
                Write-Output "Extracting $file to $pwd"
                Expand-Archive -Path $fullPath -DestinationPath $pwd -Force
            } else {
                Write-Output "File $file does not exist in the current directory"
            }
        } else {
            $input | ForEach-Object {
                $fullPath = Join-Path -Path $pwd -ChildPath $_
                if (Test-Path $fullPath) {
                    Write-Output "Extracting $_ to $pwd"
                    Expand-Archive -Path $fullPath -DestinationPath $pwd -Force
                } else {
                    Write-Output "File $_ does not exist in the current directory"
                }
            }
        }
    }
}

function du {
    param (
        [string]$Path = (Get-Location)
    )
    try {
        # Get all items recursively at the specified path.
        $items = Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue
        # Separate files and directories
        $files = $items | Where-Object { -not $_.PSIsContainer }
        $directories = $items | Where-Object { $_.PSIsContainer }
        # Measure properties
        $fileCount = $files.Count
        $directoryCount = $directories.Count
        $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        # Convert bytes to a human-readable format
        if ($totalBytes -ge 1TB) {
            $size = "{0:N2} TB" -f ($totalBytes / 1TB)
        } elseif ($totalBytes -ge 1GB) {
            $size = "{0:N2} GB" -f ($totalBytes / 1GB)
        } elseif ($totalBytes -ge 1MB) {
            $size = "{0:N2} MB" -f ($totalBytes / 1MB)
        } elseif ($totalBytes -ge 1KB) {
            $size = "{0:N2} KB" -f ($totalBytes / 1KB)
        } else {
            $size = "{0:N2} bytes" -f $totalBytes
        }
        # Output results
        Write-Output "Directory Count : $directoryCount"
        Write-Output "File Count      : $fileCount"
        Write-Output "Total Size      : $size"
    } catch {
        Write-Output "An error occurred: $_"
    }
}

# Short ulities
function ll { Get-ChildItem -Path $pwd -File }
function df {get-volume}

# Aliases for reboot and poweroff
function Reboot-System {Restart-Computer -Force}
Set-Alias reboot Reboot-System
function Poweroff-System {Stop-Computer -Force}
Set-Alias poweroff Poweroff-System

# Useful file-management functions
function cd... { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

# Hash functions
function md5 {
    param (
        [string]$Path
    )
    process {
        if ($Path) {
            Get-FileHash -Algorithm MD5 $Path
        } else {
            $input | ForEach-Object { Get-FileHash -Algorithm MD5 $_ }
        }
    }
}

function sha1 {
    param (
        [string]$Path
    )
    process {
        if ($Path) {
            Get-FileHash -Algorithm SHA1 $Path
        } else {
            $input | ForEach-Object { Get-FileHash -Algorithm SHA1 $_ }
        }
    }
}

function sha256 {
    param (
        [string]$Path
    )
    process {
        if ($Path) {
            Get-FileHash -Algorithm SHA256 $Path
        } else {
            $input | ForEach-Object { Get-FileHash -Algorithm SHA256 $_ }
        }
    }
}

# Display system uptime
function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        $lastBootUpTime = Get-WmiObject win32_operatingsystem |
            Select-Object -ExpandProperty LastBootUpTime |
            ForEach-Object { $_.ConvertToDateTime($_) }
    } else {
        $lastBootUpTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    }

    $uptime = (Get-Date) - $lastBootUpTime
    "Online since $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
}



function ssh-copy-key {
    param(
        [parameter(Position=0)]
        [string]$user,

        [parameter(Position=1)]
        [string]$ip
    )
    $pubKeyPath = "~\.ssh\id_ed25519.pub"
    $sshCommand = "cat $pubKeyPath | ssh $user@$ip 'cat >> ~/.ssh/authorized_keys'"
    Invoke-Expression $sshCommand
}

function top {
    if ($host -and $host.UI.SupportsVirtualTerminal) {
        Clear-Host
        $lines = $Host.UI.RawUI.WindowSize.Height
        $cols = $Host.UI.RawUI.WindowSize.Width
        [int]$min = 10
        $topCount = ($lines - $min)
        if ($lines -le $min) {
            $topCount = $lines 
        }
        $sortDesc = 'CPU'
        $pp = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        try {
            while (1) {
                $info = get-computerinfo
                $pInuse = $info.OsTotalVisibleMemorySize - $info.OsFreePhysicalMemory
                $phys = [math]::round(($info.OsTotalVisibleMemorySize/1MB),2)
                $physuse = ($pInuse/$info.OsTotalVisibleMemorySize).toString("P")
                $cpuAv = (Get-CimInstance -ClassName win32_processor | Measure-Object -Property LoadPercentage -Average).Average
                write-host "system: $($info.CsCaption) uptime: $($info.OsUptime) OS version $($info.OsVersion) $($info.OSDisplayVersion)"
                write-host "process: $($info.OsNumberOfProcesses) users: $($info.OsNumberOfUsers) Sort: $($sortDesc.PadRight(7))"
                write-host "cpus: $($info.CsNumberOfLogicalProcessors) load: $($cpuAv)% Physical memory: $phys usage: $physUse"
                Get-Process | Sort-Object -desc $sortDesc | Select-Object -first $topCount | format-table 
                # if ($host.UI.RawUI.KeyAvailable) # doesn't work?
                if ([Console]::KeyAvailable)
                {
                    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    switch ($key.character) {
                        'c'{
                            $sortDesc = 'CPU'
                        }
                        'h' {
                            $sortDesc = 'Handles'
                        }
                        'n'{
                            $sortDesc = 'NPM'
                        }
                        'p' {
                            $sortDesc = 'PM'
                        }
                        'q'{
                            Clear-Host
                            return
                        }
                        'w'{
                            $sortDesc = 'WS'
                        }
                    }
                }
                else {                    
                    Start-Sleep 0.5
                }
                if (($Host.UI.RawUI.WindowSize.Height -ne $lines) -or 
                ($Host.UI.RawUI.WindowSize.Width -ne $cols)) {
                    Clear-Host
                    $lines = $Host.UI.RawUI.WindowSize.Height
                    $cols = $Host.UI.RawUI.WindowSize.Width
                    $topCount = ($lines - $min)
                    if ($lines -le $min) {
                        $topCount = $lines 
                    }
                }
                $host.UI.RawUI.CursorPosition = @{x = 0; y = 0}
            }
        }
        finally {
            $ProgressPreference = $pp 
        }
    }
}

function touch {
    param (
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$files
    )

    foreach ($file in $files) {
        if (Test-Path $file) {
            (Get-Item $file).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $file | Out-Null
        }
    }
}

# -----------------------------------------------------------------------------
# Restored functions documented in the README
# -----------------------------------------------------------------------------

# Restart Windows Explorer
function explrestart { taskkill /F /IM explorer.exe; Start-Process explorer.exe }

# Open File Explorer at the current location
function expl { explorer . }

# Retrieve the public IP address
function Get-PubIP { (Invoke-RestMethod -Uri 'https://ifconfig.me/ip').Trim() }
Set-Alias -Name pubip -Value Get-PubIP -Force

# Retrieve the private IPv4 addresses
function Get-PrivIP { (Get-NetIPAddress | Where-Object -Property AddressFamily -EQ -Value 'IPv4').IPAddress }

# Lazy git: pull, stage everything, commit the given message and push
function gitpush {
    git pull
    git add .
    git commit -m ($args -join ' ')
    git push
}

# Send any file, pipe output or text to a Wastebin (pastebin alternative) server.
# Point $WastebinServerUrl (top of this file) at your own server if you run one.
function Send-Wastebin {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [string[]]$Content,

        [Parameter(Position = 1)]
        [int]$ExpirationTime = 3600,

        [Parameter(Position = 2)]
        [bool]$BurnAfterReading = $false,

        [Parameter(Position = 3)]
        [switch]$Help
    )
    begin {
        if ($Help) {
            Write-Host 'Use this to send a message to the Wastebin server.'
            Write-Host 'Set $WastebinServerUrl in functions.ps1 to your own server URL.'
            Write-Host 'example: ptw This is a test message'
            Write-Host "example: ptw 'C:\path\to\file.txt' -ExpirationTime 3600 -BurnAfterReading `$true"
            Write-Host "example: 'Hello World!' | ptw"
            return
        }
        $Payload = @{
            text               = ''
            extension          = $null
            expires            = $ExpirationTime
            burn_after_reading = $BurnAfterReading
        }
    }
    process {
        if (-not $Help) {
            foreach ($line in $Content) {
                if (Test-Path $line -PathType Leaf) {
                    $Payload.text += (Get-Content $line -Raw) + "`n"
                } else {
                    $Payload.text += $line + "`n"
                }
            }
        }
    }
    end {
        if (-not $Help) {
            $Payload.text = $Payload.text.TrimEnd("`n")
            $jsonPayload = $Payload | ConvertTo-Json
            try {
                $Response = Invoke-RestMethod -Uri $WastebinServerUrl -Method Post -Body $jsonPayload -ContentType 'application/json'
                $Path = $Response.path -replace '\.\w+$', ''
                Write-Host ''
                Write-Host "$WastebinServerUrl$Path"
            } catch {
                Write-Host "Error occurred: $_"
            }
        }
    }
}
Set-Alias -Name ptw -Value Send-Wastebin

# -----------------------------------------------------------------------------
# File and directory helpers
# -----------------------------------------------------------------------------

# Create a directory and enter it
function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    Set-Location -Path $Path
}

# Find files recursively by name
function ff {
    param([Parameter(Mandatory)][string]$Name)
    Get-ChildItem -Recurse -File -Filter "*$Name*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
}

# Create a new empty file in the current directory
function nf {
    param([Parameter(Mandatory)][string]$Name)
    New-Item -ItemType File -Path . -Name $Name -Force | Out-Null
}

# Move a file or folder to the Recycle Bin instead of deleting it permanently
function trash {
    param([Parameter(Mandatory)][string]$Path)

    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Item not found: $Path"
        return
    }

    $fullPath = $resolvedPath.ProviderPath
    $item = Get-Item -LiteralPath $fullPath
    $parentPath = if ($item.PSIsContainer) {
        if ($item.Parent) { $item.Parent.FullName } else { Split-Path -Path $item.FullName -Parent }
    } else {
        $item.DirectoryName
    }

    if ([string]::IsNullOrWhiteSpace($parentPath)) {
        Write-Error "Cannot move root path to Recycle Bin: $fullPath"
        return
    }

    $shell = New-Object -ComObject 'Shell.Application'
    $shellFolder = $shell.NameSpace($parentPath)
    $shellItem = if ($shellFolder) { $shellFolder.ParseName($item.Name) } else { $null }

    if ($shellItem) {
        $shellItem.InvokeVerb('delete')
    } else {
        Write-Error "Could not move item to Recycle Bin: $fullPath"
    }
}

# -----------------------------------------------------------------------------
# Git shortcuts
# Note: 'gc' is intentionally not used, as it collides with the built-in
# Get-Content alias (aliases take precedence over functions). Use gcom instead.
# -----------------------------------------------------------------------------

function gs { git status }
function ga { git add . }
function gcl { git clone @args }
function gpush { git push @args }
function gpull { git pull @args }
function gcom {
    git add .
    git commit -m ($args -join ' ')
}
function lazyg {
    git add .
    git commit -m ($args -join ' ')
    git push
}
# Note: no 'gp' alias — gp is a built-in AllScope alias (Get-ItemProperty) and cannot be overridden.

# -----------------------------------------------------------------------------
# Navigation
# -----------------------------------------------------------------------------

# Go to the GitHub directory (via zoxide when available)
function g {
    $fallbackPath = "$HOME\github"
    if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) {
        $startPath = (Get-Location).ProviderPath
        __zoxide_z github
        $endPath = (Get-Location).ProviderPath
        if ($startPath -eq $endPath -and (Test-Path -Path $fallbackPath)) {
            Set-Location $fallbackPath
        }
    } elseif (Test-Path -Path $fallbackPath) {
        Set-Location $fallbackPath
    }
}

# Go to Documents / Desktop
function docs { Set-Location -Path ([Environment]::GetFolderPath('MyDocuments')) }
function dtop { Set-Location -Path ([Environment]::GetFolderPath('Desktop')) }

# -----------------------------------------------------------------------------
# Clipboard
# -----------------------------------------------------------------------------

function cpy { Set-Clipboard ($args -join ' ') }
function pst { Get-Clipboard }

# -----------------------------------------------------------------------------
# System
# -----------------------------------------------------------------------------

function sysinfo { Get-ComputerInfo }

function flushdns {
    Clear-DnsClientCache
    Write-Host 'DNS has been flushed'
}

# Shorthand for pkill
function k9 { param([Parameter(Mandatory)][string]$Name) pkill $Name }

# List all visible items (ll lists files only)
function la { Get-ChildItem | Format-Table -AutoSize }

# Start an elevated shell in the current directory
function admin {
    $cwd = (Get-Location).ProviderPath
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
    $shellArgs = if ($args.Count -gt 0) { @('-NoExit', '-Command', ($args -join ' ')) } else { @('-NoExit') }

    if (Get-Command wt -ErrorAction SilentlyContinue) {
        Start-Process wt -Verb RunAs -ArgumentList (@('-d', "`"$cwd`"", $shell) + $shellArgs)
    } else {
        Start-Process $shell -Verb RunAs -WorkingDirectory $cwd -ArgumentList $shellArgs
    }
}
Set-Alias -Name su -Value admin -Force

# Remove common Windows cache/temp files
function Clear-Cache {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $paths = @(
        "$env:SystemRoot\Prefetch\*",
        "$env:SystemRoot\Temp\*",
        "$env:TEMP\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"
    )

    foreach ($path in $paths) {
        if ($PSCmdlet.ShouldProcess($path, 'Remove cached files')) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# -----------------------------------------------------------------------------
# Profile management
# -----------------------------------------------------------------------------

# Pick the first available editor
function Resolve-Editor {
    foreach ($candidate in 'nvim', 'pvim', 'vim', 'vi', 'code', 'codium', 'notepad++', 'sublime_text') {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }
    return 'notepad'
}

$EDITOR = Resolve-Editor
if ($EDITOR -ne 'vim') {
    Set-Alias -Name vim -Value $EDITOR -Force
}

# Open the PowerShell profile for editing
function Edit-Profile {
    & $EDITOR $PROFILE.CurrentUserCurrentHost
}
Set-Alias -Name ep -Value Edit-Profile -Force

# Reload the PowerShell profile in the current session
function Invoke-Profile {
    . $PROFILE.CurrentUserCurrentHost
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

function Show-Help {
    @'
unix-pwsh Profile Help
======================

Profile:
  Edit-Profile (ep)  Open the PowerShell profile for editing.
  Invoke-Profile     Reload the PowerShell profile in this session.
  Show-Help          Show this help text.

Git:
  g                  Go to the GitHub directory (zoxide when available).
  gs                 git status
  ga                 git add .
  gcom <message>     git add . and commit with <message>
  gcl <repo>         git clone <repo>
  gpush              git push
  gpull              git pull
  lazyg <message>    git add ., commit <message> and push
  gitpush <message>  git pull, add ., commit <message> and push

Files and directories:
  touch <file>       Create a file or update its timestamp.
  nf <file>          Create a new empty file.
  mkcd <dir>         Create a directory and enter it.
  ff <name>          Find files recursively by name.
  trash <path>       Move a file or folder to the Recycle Bin.
  dirs [pattern]     List all files recursively (dir /s /b).
  du [path]          Show file count and total size.
  la / ll            List all visible items / files only.
  docs / dtop        Go to Documents / Desktop.
  cd... / cd....     Go up two / three directory levels.
  unzip <file>       Extract a zip archive here.

Text:
  grep <pattern> [p] Search files or piped input for a pattern.
  sed <f> <a> <b>    Replace text <a> with <b> in file <f>.
  head / tail [-f]   Show the first / last lines of a file (tail -f follows).
  cpy <text>         Copy text to the clipboard.
  pst                Paste text from the clipboard.
  ptw <text|file>    Send text/files/pipe output to the Wastebin server.

System:
  uptime             Show system uptime.
  sysinfo            Show detailed system information.
  flushdns           Clear the DNS client cache.
  df                 Show volume information.
  top                Live process monitor (c/h/n/p/w sort, q quits).
  pgrep <name>       Find processes by name.
  pkill / k9 <name>  Kill processes by name.
  which <name>       Show the path of a command.
  export <n> <v>     Set an environment variable.
  md5/sha1/sha256    Compute file hashes.
  admin / su         Start an elevated shell in this directory.
  Clear-Cache        Remove common Windows temp/cache files.
  reboot / poweroff  Restart / shut down the system.
  expl               Open File Explorer here.
  explrestart        Restart Windows Explorer.
  Get-PubIP / pubip  Show the public IP address.
  Get-PrivIP         Show the private IPv4 addresses.
  ssh-copy-key       Copy the SSH public key to a remote server.
'@
}
