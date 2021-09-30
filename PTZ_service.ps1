param (
    [string]$preset = '',
    [bool]$reset = $false
)

Function Get-PSScriptRoot
{
    $ScriptRoot = ""

    Try
    {
        $ScriptRoot = Get-Variable -Name PSScriptRoot -ValueOnly -ErrorAction Stop
    }
    Catch
    {
        $ScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
    }

    Write-Output $ScriptRoot
}

function Convert-ByteArrayToHexString
{
################################################################
#.Synopsis
# Returns a hex representation of a System.Byte[] array as
# one or more strings. Hex format can be changed.
#.Parameter ByteArray
# System.Byte[] array of bytes to put into the file. If you
# pipe this array in, you must pipe the [Ref] to the array.
# Also accepts a single Byte object instead of Byte[].
#.Parameter Width
# Number of hex characters per line of output.
#.Parameter Delimiter
# How each pair of hex characters (each byte of input) will be
# delimited from the next pair in the output. The default
# looks like "0x41,0xFF,0xB9" but you could specify "\x" if
# you want the output like "\x41\xFF\xB9" instead. You do
# not have to worry about an extra comma, semicolon, colon
# or tab appearing before each line of output. The default
# value is ",0x".
#.Parameter Prepend
# An optional string you can prepend to each line of hex
# output, perhaps like '$x += ' to paste into another
# script, hence the single quotes.
#.Parameter AddQuotes
# A switch which will enclose each line in double-quotes.
#.Example
# [Byte[]] $x = 0x41,0x42,0x43,0x44
# Convert-ByteArrayToHexString $x
#
# 0x41,0x42,0x43,0x44
#.Example
# [Byte[]] $x = 0x41,0x42,0x43,0x44
# Convert-ByteArrayToHexString $x -width 2 -delimiter "\x" -addquotes
#
# "\x41\x42"
# "\x43\x44"
################################################################
[CmdletBinding()] Param (
[Parameter(Mandatory = $True, ValueFromPipeline = $True)] [System.Byte[]] $ByteArray,
[Parameter()] [Int] $Width = 70,
[Parameter()] [String] $Delimiter = ",0x",
[Parameter()] [String] $Prepend = "",
[Parameter()] [Switch] $AddQuotes )
 
if ($Width -lt 1) { $Width = 1 }
if ($ByteArray.Length -eq 0) { Return }
$FirstDelimiter = $Delimiter -Replace "^[\,\:\t]",""
$From = 0
$To = $Width - 1
Do
{
$String = [System.BitConverter]::ToString($ByteArray[$From..$To])
$String = $FirstDelimiter + ($String -replace "\-",$Delimiter)
if ($AddQuotes) { $String = '"' + $String + '"' }
if ($Prepend -ne "") { $String = $Prepend + $String }
$String
$From += $Width
$To += $Width
} While ($From -lt $ByteArray.Length)
}

$rundir = Get-PSScriptRoot
$config = Get-Content -Path $rundir\config.json | ConvertFrom-Json

$port = new-Object System.IO.Ports.SerialPort $config.port,9600,None,8,one
$port.ReadTimeout = 500

$port.open()

#[Byte[]] $hex = 0x81,0x01,0x04,0x07,0x2b,0xff #Slow zoom in
#[Byte[]] $hex = 0x81,0x01,0x04,0x07,0x3b,0xff #Fast zoom out
#[Byte[]] $hex = 0x81,0x01,0x33,0x01,0x02,0xff #Blink light
#[Byte[]] $hex = 0x81,0x01,0x33,0x01,0x01,0xff #Light on
#[Byte[]] $hex = 0x81,0x01,0x33,0x01,0x00,0xff #Light off
#[Byte[]] $hex = 0x81,0x01,0x04,0x38,0x02,0xff #Autofocus
#$port.Write($hex, 0, $hex.Count)


#[Byte[]] $hex = 0x81,0x09,0x04,0x38,0xff #Read focus status
#[Byte[]] $hex = 0x81,0x09,0x04,0x39,0xff #Read AE status

#[Byte[]] $hex = 0x81,0x01,0x06,0x05,0xff #Return camera to middle

#[Byte[]] $hex = 0x81,0x09,0x04,0x47,0xff #Read zoom status
#[Byte[]] $hex = 0x81,0x09,0x06,0x12,0xff #Read pt status

#[Byte[]] $hex = 0x81,0x01,0x06,0x20,0x00,0x01,0x04,0x00,0x00,0x00,0x07,0x00,0x00,0x0f,0x00,0x02,0x00,0x00,0x00,0x00,0xff

#[Byte[]] $hex = 0x81,0x01,0x06,0x01,0x01,0x01,0x01,0x03,0xff #move left
#[Byte[]] $hex = 0x81,0x01,0x06,0x01,0x0f,0x0f,0x02,0x03,0xff #move right


#[Byte[]] $hex = 0x81,0x01,0x00,0x01,0xff #cancel 

if ($reset -eq $true)
{
    [Byte[]] $hex = 0x81,0x01,0x06,0x05,0xff #Return camera to middle
    $port.Write($hex, 0, $hex.Count)
}

$prev = (Get-Content -Path $rundir\scene.lua).TrimEnd()
$prevlive = $prev 

Try {
    $presets = Get-Content -Path $rundir\presets.json | ConvertFrom-Json
    while ($true) {

        Try { $preset = (Get-Content -Path $rundir\scene.lua).TrimEnd() } Catch { Write-Host "get scene from file failed." }

        if ( $preset -ne $null) {
            if (($prevlive -ne $preset) -and ($presets.$preset -ne $null)) {
                [Byte[]] $hex = 0x81,0x01,0x04,0x38,0x03,0xff #set manual focus 
                $port.Write($hex, 0, $hex.Count)
                [Byte[]] $hex = $presets.$preset
                Write-host "Changing to preset $preset"
                $port.Write($hex, 0, $hex.Count)

                if (($hex[16] + $hex[17] + $hex[18] + $hex[19]) -eq 0 ) {
                    [Byte[]] $hex = 0x81,0x01,0x04,0x38,0x02,0xff #autofocus 
                    $port.Write($hex, 0, $hex.Count)
                    Write-Host -ForegroundColor Magenta "Setting autofocus"
                } 
                
                $prevlive = $preset
            } elseif (($prev -ne $preset) -and ($presets.$preset -eq $null)) {
                Write-host -ForegroundColor Yellow "Preset $preset is not defined"
            } elseif ($prev -ne $preset) {
                Write-host -ForegroundColor Gray "Preset $preset already active"
            } 
            $prev = $preset
        }
        Start-Sleep -Milliseconds 150
    }

    #Start-Sleep -Milliseconds 80
    #[Byte[]] $hex = 0x81,0x01,0x06,0x01,0x03,0x03,0x03,0x03,0xff #cancel 
    #$port.Write($hex, 0, $hex.Count)


    $x = $false
    $reply = @()
    while ($x -ne 255)
    {
        $x = $port.ReadByte()
        Write-Host $x
        $reply += $x
    }
    
    Convert-ByteArrayToHexString $reply

} Finally {
    [Byte[]] $hex = 0x81,0x01,0x04,0x38,0x02,0xff #autofocus 
    $port.Write($hex, 0, $hex.Count)
    $port.close()
}
