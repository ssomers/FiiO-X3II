New-Variable -Option Constant ignore_symbol -Value ([char]"-")
New-Variable -Option Constant hdcd_symbol -Value ([char]"H")
New-Variable -Option Constant bass_symbol -Value ([char]"B")
New-Variable -Option Constant mix_symbol -Value @{
    [ChannelMix]"mix_xfeed" = [char]"X"
    [ChannelMix]"mix_mono"  = [char]"|"
    [ChannelMix]"mix_left"  = [char]"<"
    [ChannelMix]"mix_right" = [char]">"
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
    [Boolean]$bass
    [ChannelMix]$mix
    Covet([Treatment]$treatment) {
        $this.treatment = $treatment
        $this.hdcd = $false
        $this.bass = $false
        $this.mix = "mix_passthrough"
    }

    Covet([Covet]$source, [Treatment]$defaultTreatment) {
        if ($null -eq $source) {
            $this.treatment = $defaultTreatment
        }
        else {
            $this.treatment = $source.treatment
            $this.hdcd = $source.hdcd
            $this.bass = $source.bass
            $this.mix = $source.mix
        }
    }

    [char] GetConvChar() {
        if ($this.treatment -ne "convert") {
            throw
        }
        return [char]((1 -shl 5) -bor
            ([int]$this.hdcd -shl 4) -bor
            ([int]$this.bass -shl 3) -bor
            [int]$this.mix)
    }

    [string] GetSymbols() {
        $private:symbols = ""
        switch ($this.treatment) {
            "ignore" {
                $symbols += $script:ignore_symbol
            }
            "convert" {
                if ($this.hdcd) {
                    $symbols += $script:hdcd_symbol
                }
                if ($this.mix -ne "mix_passthrough") {
                    $symbols += $script:mix_symbol[$this.mix]
                }
                if ($this.bass) {
                    $symbols += $script:bass_symbol
                }
            }
        }
        return $symbols
    }
}

class Covets {
    [Covet]$default
    [Collections.Generic.Dictionary[string, Covet]] $per_name

    Covets() {
        $this.default = $null
        $this.per_name = [Collections.Generic.Dictionary[string, Covet]]::new()
    }

    [bool] IsUseful() {
        return $null -ne $this.default -Or $this.per_name.Count
    }

    [bool] DoesNotExclude([string]$name) {
        $private:covet = $this.per_name[$name]
        return $null -eq $covet -Or $covet.treatment -ne "ignore"
    }

    [Covet] GetCovet([string]$name) {
        $private:covet = $this.per_name[$name]
        if ($null -ne $covet) {
            return $covet
        }
        else {
            return $this.default
        }
    }

    static [Covets] Read([string] $InPath) {
        $private:covets = [Covets]::new()
        Get-Content -LiteralPath $InPath -Encoding UTF8 -ErrorAction Ignore |
            ForEach-Object {
                $private:symbols, $private:name = $_ -split " ", 2
                if (-not $symbols) {
                    Write-Warning "${InPath}: missing symbols for name ""$name"""
                    break
                }
                $private:covet = [Covet]::new($covets.default, [Treatment]"convert")
                foreach ($s in $symbols.GetEnumerator()) {
                    switch ($s) {
                        $script:ignore_symbol { $covet.treatment = "ignore" }
                        $script:hdcd_symbol { $covet.hdcd = $true }
                        $script:bass_symbol { $covet.bass = $true }
                        $script:mix_symbol[[ChannelMix]"mix_xfeed"] { $covet.mix = "mix_xfeed" }
                        $script:mix_symbol[[ChannelMix]"mix_mono"] { $covet.mix = "mix_mono" }
                        $script:mix_symbol[[ChannelMix]"mix_left"] { $covet.mix = "mix_left" }
                        $script:mix_symbol[[ChannelMix]"mix_right"] { $covet.mix = "mix_right" }
                        default {
                            Write-Warning "${InPath}: invalid symbol ""$s"" for name ""$name"""
                            break
                        }
                    }
                }
                if ($name) {
                    if ($covets.per_name.ContainsKey($name)) {
                        Write-Warning "${InPath}: multiply defined ""$name"""
                        return $null
                    }
                    $covets.per_name[$name] = $covet
                }
                else {
                    if ($null -ne $covets.default) {
                        Write-Warning "${InPath}: multiply defined default ""$_"""
                        return $null
                    }
                    $covets.default = $covet
                }
            }
        return $covets
    }

    [void] WriteTo([string] $OutPath) {
        Invoke-Command -NoNewScope {
            if ($null -ne $this.default) {
                [Collections.Generic.KeyValuePair[string, Covet]]::new("", $this.Default)
            }
            $this.per_name.GetEnumerator() | Sort-Object -Property Key
        } | ForEach-Object {
            $private:name, $private:covet = $_.Key, $_.Value
            $private:symbols = $covet.GetSymbols()
            if ($symbols -eq "") {
                throw "Unknown symbols for registered covet"
            }
            Write-Output "$symbols $name"
        } | Set-Content -LiteralPath $OutPath -Encoding UTF8
    }
}

function Get-DefaultTreatment {
    param (
        [string] $Filename
    )

    [Treatment]$private:treatment = switch -Wildcard ($Filename) {
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
