param (
    [bool]$reset = $false,
    [string]$serialport = $false
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

function Convert-HexStringToByteArray
{
    ################################################################
    #.Synopsis
    # Convert a string of hex data into a System.Byte[] array. An
    # array is always returned, even if it contains only one byte.
    #.Parameter String
    # A string containing hex data in any of a variety of formats,
    # including strings like the following, with or without extra
    # tabs, spaces, quotes or other non-hex characters:
    # 0x41,0x42,0x43,0x44
    # \x41\x42\x43\x44
    # 41-42-43-44
    # 41424344
    # The string can be piped into the function too.
    ################################################################
    [CmdletBinding()]
    Param ( [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [String] $String )
 
    #Clean out whitespaces and any other non-hex crud.
    $String = $String.ToLower() -replace '[^a-f0-9\\,x\-\:]',''
    #Try to put into canonical colon-delimited format.
    $String = $String -replace '0x|\\x|\-|,',':'
    #Remove beginning and ending colons, and other detritus.
    $String = $String -replace '^:+|:+$|x|\\',''
    #Maybe there's nothing left over to convert...
    if ($String.Length -eq 0) { ,@() ; return }
    #Split string with or without colon delimiters.
    if ($String.Length -eq 1)
    { ,@([System.Convert]::ToByte($String,16)) }
    elseif (($String.Length % 2 -eq 0) -and ($String.IndexOf(":") -eq -1))
    { ,@($String -split '([a-f0-9]{2})' | foreach-object { if ($_) {[System.Convert]::ToByte($_,16)}}) }
    elseif ($String.IndexOf(":") -ne -1)
    { ,@($String -split ':+' | foreach-object {[System.Convert]::ToByte($_,16)}) }
    else
    { ,@() }
    #The strange ",@(...)" syntax is needed to force the output into an
    #array even if there is only one element in the output (or none).
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
        $String = $FirstDelimiter + ($String -replace "\-","$Delimiter")
        if ($AddQuotes) { $String = '"' + $String + '"' }
        if ($Prepend -ne "") { $String = $Prepend + $String }
        $String
        $From += $Width
        $To += $Width
    } While ($From -lt $ByteArray.Length)
}

function Set-PTZPreset
{
    $x = $false
    $reply = @()
    $temp = @()
    Write-host $cam

    Try {
        while ($true)
        {
            $x = $port.ReadByte()
            Write-Host $x
        }
    } Catch { Write-Host "Buffer cleared" }
    
   
    $x = $false
    [Byte[]] $hex = $cam,0x09,0x06,0x12,0xff #Read PT pos
    Write-Host $hex
    $port.Write($hex, 0, $hex.Count)
    while ($x -ne 255)
    {
       $x = $port.ReadByte()
       Write-Host $x
       $temp += $x
    }

    for ($i = 2; $i -lt $temp.Length - 1 ; $i++) { $reply += $temp[$i] }

    $temp = @()
    $x = $false
    [Byte[]] $hex = $cam,0x09,0x04,0x47,0xff #Read zoom pos
    $port.Write($hex, 0, $hex.Count)
    while ($x -ne 255)
    {
        $x = $port.ReadByte()
        Write-Host $x
        $temp += $x
    }

    for ($i = 2; $i -lt $temp.Length - 1 ; $i++) { $reply += $temp[$i] }

    Write-Host -NoNewline "Save focus position? (y/N):"
    $savefocus = Read-Host

    if ($savefocus -eq 'y') {
        $temp = @()
        $x = $false
        [Byte[]] $hex = $cam,0x09,0x04,0x48,0xff #Read focus pos
        $port.Write($hex, 0, $hex.Count)
        while ($x -ne 255)
        {
            $x = $port.ReadByte()
            #Write-Host $x
            $temp += $x
        }

        for ($i = 2; $i -lt $temp.Length - 1 ; $i++) { $reply += $temp[$i] }
        $savedpos = Convert-HexStringToByteArray "0x$([System.BitConverter]::ToString($cam)),0x01,0x06,0x20,$(Convert-ByteArrayToHexString $reply),0xFF"
    } else {
        $savedpos = Convert-HexStringToByteArray "0x$([System.BitConverter]::ToString($cam)),0x01,0x06,0x20,$(Convert-ByteArrayToHexString $reply),0x00,0x00,0x00,0x00,0xFF"
    }

    Write-Host -NoNewline "Enter preset name:"
    $presetname = Read-Host
    $presets = Get-Content -Path $rundir\presets.json | ConvertFrom-Json
    $presets | Add-Member -MemberType NoteProperty -Name $presetname -Value $savedpos -Force
    $presets | ConvertTo-Json | Set-Content -Path $rundir\presets.json
    Write-Host "Preset saved!"

}

$rundir = Get-PSScriptRoot
$config = Get-Content -Path $rundir\config.json | ConvertFrom-Json
$cam = [Byte] 0x81


Try {
    
    Write-Host -ForegroundColor Green "WSAD Controls Pan and Tilt"
    Write-Host -ForegroundColor Green "EQ Controls Zoom"
    Write-Host -ForegroundColor Green "P to save preset"
    Write-Host -ForegroundColor Green "R to centre and recalibrate"
    Write-Host -ForegroundColor Green "F to toggle fine-tuning"
    Write-Host -ForegroundColor Green "Spacebar to cancel in-progress pan or tilt movement"
    Write-Host -ForegroundColor Green "X to quit"
    Write-Host -ForegroundColor Green "-----"

    if ($serialport -eq $false) {
        $serialport = $config.port
    }

    $port = new-Object System.IO.Ports.SerialPort $serialport,9600,None,8,one
    $port.ReadTimeout = 500
    $port.open()
    
    
    #[Byte[]] $hex = $cam,0x01,0x04,0x07,0x2b,0xff #Slow zoom in
    #[Byte[]] $hex = $cam,0x01,0x04,0x07,0x00,0xff #Zoom stop
    #[Byte[]] $hex = $cam,0x01,0x04,0x07,0x3b,0xff #Fast zoom out
    #[Byte[]] $hex = $cam,0x01,0x33,0x01,0x02,0xff #Blink light
    #[Byte[]] $hex = $cam,0x01,0x33,0x01,0x01,0xff #Light on
    #[Byte[]] $hex = $cam,0x01,0x33,0x01,0x00,0xff #Light off
    #[Byte[]] $hex = $cam,0x01,0x04,0x38,0x02,0xff #Autofocus
    #$port.Write($hex, 0, $hex.Count)


    #[Byte[]] $hex = 0x81,0x09,0x04,0x38,0xff #Read focus status
    #[Byte[]] $hex = 0x81,0x09,0x04,0x39,0xff #Read AE status

    #[Byte[]] $hex = $cam,0x01,0x06,0x05,0xff #Return camera to middle

    #[Byte[]] $hex = 0x81,0x09,0x04,0x47,0xff #Read zoom status
    #[Byte[]] $hex = 0x81,0x09,0x06,0x12,0xff #Read pt status

    #[Byte[]] $hex = $cam,0x01,0x06,0x20,0x00,0x01,0x04,0x00,0x00,0x00,0x07,0x00,0x00,0x0f,0x00,0x02,0x00,0x00,0x00,0x00,0xff

    #[Byte[]] $hex = $cam,0x01,0x06,0x01,0x01,0x01,0x01,0x03,0xff #move left
    #[Byte[]] $hex = $cam,0x01,0x06,0x01,0x0f,0x0f,0x02,0x03,0xff #move right


    #[Byte[]] $hex = $cam,0x01,0x00,0x01,0xff #cancel 

    if ($reset -eq $true)
    {
        [Byte[]] $hex = $cam,0x01,0x06,0x05,0xff #Return camera to middle
        $port.Write($hex, 0, $hex.Count)
    }

    [Byte[]] $hex = 0x88,0x30,0x01,0xff #Set camera addresses, starting with 1
    $port.Write($hex, 0, $hex.Count)
        
    $char = $false
    $ft = $false
    

    while ($char -ne 'x' ) {

        $KeyPress = [System.Console]::ReadKey($true)
        $char = $KeyPress.key
        Write-host "Key pressed: $char"
        
        Switch ($char)
        {
            a { [Byte[]] $hex = $cam,0x01,0x06,0x01,0x0b,0x02,0x01,0x03,0xff } #left
            d { [Byte[]] $hex = $cam,0x01,0x06,0x01,0x0b,0x02,0x02,0x03,0xff } #right
            e { [Byte[]] $hex = $cam,0x01,0x04,0x07,0x2a,0xff } #zoom in
            q { [Byte[]] $hex = $cam,0x01,0x04,0x07,0x3a,0xff } #zoom out
            v { [Byte[]] $hex = $cam,0x01,0x04,0x08,0x2b,0xff } #focus far
            c { [Byte[]] $hex = $cam,0x01,0x04,0x08,0x3b,0xff } #focus near
            b { [Byte[]] $hex = $cam,0x01,0x04,0x08,0x00,0xff } #focus stop
            m { [Byte[]] $hex = $cam,0x01,0x04,0x38,0x03,0xff } #focus manual
            n { [Byte[]] $hex = $cam,0x01,0x04,0x38,0x02,0xff } #focus auto
            w { [Byte[]] $hex = $cam,0x01,0x06,0x01,0x0b,0x01,0x03,0x01,0xff } #tilt up
            s { [Byte[]] $hex = $cam,0x01,0x06,0x01,0x0b,0x01,0x03,0x02,0xff } #tilt down
            r { [Byte[]] $hex = $cam,0x01,0x06,0x05,0xff } #Return camera to middle
            f { $ft = ! $ft ; [Byte[]] $hex = $cam,0x01,0x06,0x01,0x03,0x03,0x03,0x03,0xff }
            D1 { $cam = [Byte] 0x81 ; Write-host "Controlling camera 1" }
            D2 { $cam = [Byte] 0x82 ; Write-host "Controlling camera 2" }
            p { Set-PTZPreset ; [Byte[]] $hex = $cam,0x01,0x06,0x01,0x03,0x03,0x03,0x03,0xff } 
            default { 
                [Byte[]] $hex = $cam,0x01,0x04,0x07,0x00,0xff #Zoom stop
                $port.Write($hex, 0, $hex.Count)
                [Byte[]] $hex = $cam,0x01,0x06,0x01,0x03,0x03,0x03,0x03,0xff } #Cancel
        }
        Write-Host $hex

        $port.Write($hex, 0, $hex.Count)
    
        #Start-Sleep -Milliseconds 2

        if ($ft -eq $true) {
            [Byte[]] $hex = $cam,0x01,0x06,0x01,0x03,0x03,0x03,0x03,0xff
            $port.Write($hex, 0, $hex.Count)
            [Byte[]] $hex = $cam,0x01,0x04,0x08,0x00,0xff
            $port.Write($hex, 0, $hex.Count)
        }

        }
} Finally {
    $port.close()
}