New-Variable -Option Constant ignore_symbol -Value ([char]"-")
New-Variable -Option Constant conversion_by_symbol -Value @{
    [char]"B" = [Conversion] "cnv_bass"
    [char]"H" = [Conversion] "cnv_hdcd"
    [char]"X" = [Conversion] "cnv_xfeed"
    [char]"|" = [Conversion] "cnv_mono"
    [char]"<" = [Conversion] "cnv_left"
    [char]">" = [Conversion] "cnv_right"
}

enum Treatment {
    unknown
    ignore
    cover
    copy
    convert
}

enum Conversion {
    cnv_hdcd
    cnv_bass
    cnv_xfeed
    cnv_mono
    cnv_left
    cnv_right
}

class Covet {
    [Treatment]$treatment
    [Collections.Generic.List[Conversion]]$conversions
    Covet([Treatment]$treatment) {
        $this.treatment = $treatment
        $this.conversions = [Collections.Generic.List[Conversion]]::new()
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
                $conversion = $conversion_by_symbol[$s]
                if ($null -eq $conversion) {
                    Write-Error "${InPath}: invalid symbol ""$s"" for name ""$name"""
                    return $null
                }
                $covet.conversions.Add($conversion)
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
                foreach ($p in $conversion_by_symbol.GetEnumerator()) {
                    ([string] $symbol, [Conversion] $c) = ($p.Key, $p.Value)
                    if ($covet.conversions -contains $c) {
                        $symbols += $symbol
                    }
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
