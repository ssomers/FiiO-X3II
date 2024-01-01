New-Variable -Option Constant ignore_symbol -Value ([char]"-")
New-Variable -Option Constant hdcd_symbol -Value ([char]"H")
New-Variable -Option Constant bass_symbol -Value ([char]"B")
New-Variable -Option Constant mix_by_symbol -Value @{
    [char]"X" = [ChannelMix] "mix_xfeed"
    [char]"|" = [ChannelMix] "mix_mono"
    [char]"<" = [ChannelMix] "mix_left"
    [char]">" = [ChannelMix] "mix_right"
}

enum Treatment {
    unknown
    ignore
    cover
    copy
    convert
}

enum ChannelMix {
    mix_passthrough
    mix_xfeed
    mix_mono
    mix_left
    mix_right
}

class Covet {
    [Treatment]$treatment
    [Boolean]$hdcd
    [ChannelMix]$mix
    [Boolean]$bass
    Covet([Treatment]$treatment) {
        $this.treatment = $treatment
        $this.hdcd = $false
        $this.bass = $false
        $this.mix = "mix_passthrough"
    }
}

function Get-Covets {
    param (
        [string] $InPath
    )
    $covets = [Collections.Generic.Dictionary[string, Covet]]::new()
    Get-Content -LiteralPath $InPath -Encoding UTF8 -ErrorAction Ignore |
    ForEach-Object {
        $symbols, $name = $_ -split " ", 2
        if (-Not $name) {
            Write-Warning "${InPath}: invalid line ""$_"""
            return $null
        }
        if ($covets.ContainsKey($name)) {
            Write-Warning "${InPath}: multiply defined ""$name"""
            return $null
        }
        if ($symbols -eq $ignore_symbol) {
            $covet = [Covet]::new("ignore")
        }
        else {
            $covet = [Covet]::new("convert")
            foreach ($s in $symbols.GetEnumerator()) {
                $covet.hdcd = ($s -eq $hdcd_symbol)
                $covet.bass = ($s -eq $bass_symbol)
                $mix = $mix_by_symbol[$s]
                if ($null -eq $mix) {
                    if (-not $covet.hdcd -and -not $covet.bass) {
                        Write-Error "${InPath}: invalid symbol ""$s"" for name ""$name"""
                        return $null
                    }
                    $mix = "mix_passthrough"
                }
                $covet.mix = $mix
            }
        }
        $covets[$name] = $covet
    }
    return $covets
}

function Set-Covets {
    param (
        [Collections.Generic.Dictionary[string, Covet]] $covets,
        [string] $OutPath
    )
    $covets.GetEnumerator() | Sort-Object -Property Key | ForEach-Object {
        $name, $covet = $_.Key, $_.Value
        $symbols = ""
        switch ($covet.treatment) {
            "ignore" {
                $symbols += $ignore_symbol
            }
            "convert" {
                if ($covet.hdcd) {
                    $symbols += $hdcd_symbol
                }
                foreach ($p in $mix_by_symbol.GetEnumerator()) {
                    ([string] $symbol, [ChannelMix] $c) = ($p.Key, $p.Value)
                    if ($covet.mix -eq $c) {
                        $symbols += $symbol
                    }
                }
                if ($covet.bass) {
                    $symbols += $bass_symbol
                }
            }
        }
        if ($symbols -eq "") {
            Write-Error "${InPath}: unknown treatment for name ""$name"""
        }
        Write-Output "$symbols $name"
    } | Set-Content -LiteralPath $OutPath -Encoding UTF8
}

function Get-DefaultTreatment {
    param (
        [string] $Filename
    )

    [Treatment]$treatment = switch -Wildcard ($Filename) {
        "*.old.*" { "ignore"; break }
        "*.raw.*" { "ignore"; break }
        "*.iso" { "ignore" }
        "*.llc" { "ignore" }
        "*.mp4" { "ignore" }
        "*.pdf" { "ignore" }
        "*.txt" { "ignore" }
        "cover.*" { "cover" }
        "*.m4a" { "copy" }
        "*.mp2" { "copy" }
        "*.mp3" { "copy" }
        "*.ogg" { "copy" }
        "*.wma" { "copy" }
        "*.ac3" { "convert" }
        "*.flac" { "convert" }
        "*.webm" { "convert" }
        default { "unknown" }
    }
    $treatment
}
