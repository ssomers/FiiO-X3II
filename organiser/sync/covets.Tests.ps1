using module './covets.psm1'

Describe "Covet" {
    It "handles mix_passthrough" {
        $covet = [Covet]::new("convert")
        $covet.mix | Should -Be "mix_passthrough"
        $covet.GetConvChar() | Should -Be ' '
        $covet.GetSymbols() | Should -Be ""
        $covet.bass = $true; $covet.hdcd = $false
        $covet.GetConvChar() | Should -Be '('
        $covet.GetSymbols() | Should -Be "B"
        $covet.bass = $false; $covet.hdcd = $true
        $covet.GetConvChar() | Should -Be '0'
        $covet.GetSymbols() | Should -Be 'H'
        $covet.bass = $true; $covet.hdcd = $true
        $covet.GetConvChar() | Should -Be '8'
        $covet.GetSymbols() | Should -Be 'HB'
    }

    It "handles mix_xfeed" {
        $covet = [Covet]::new("convert")
        $covet.mix = "mix_xfeed"
        $covet.GetConvChar() | Should -Be '!'
        $covet.GetSymbols() | Should -Be "X"
        $covet.bass = $true; $covet.hdcd = $false
        $covet.GetConvChar() | Should -Be ')'
        $covet.GetSymbols() | Should -Be "XB"
        $covet.bass = $false; $covet.hdcd = $true
        $covet.GetConvChar() | Should -Be '1'
        $covet.GetSymbols() | Should -Be 'HX'
        $covet.bass = $true; $covet.hdcd = $true
        $covet.GetConvChar() | Should -Be '9'
        $covet.GetSymbols() | Should -Be 'HXB'
    }

    It "handles mono" {
        $covet = [Covet]::new("convert")
        $covet.mix = "mix_mono"
        $covet.GetConvChar() | Should -Be '"'
        $covet.GetSymbols() | Should -Be "|"
        $covet.mix = "mix_left"
        $covet.GetConvChar() | Should -Be '#'
        $covet.GetSymbols() | Should -Be "<"
        $covet.mix = "mix_right"
        $covet.GetConvChar() | Should -Be '$'
        $covet.GetSymbols() | Should -Be ">"
    }
}
