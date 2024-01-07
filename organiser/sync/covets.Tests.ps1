using module './covets.psm1'

Describe "GetConvChar" {
    It "yields unique characters" {
        $covet = [Covet]::new("convert")
        $covet.GetConvChar() | Should -Be ' ' 
        $covet.mix = "mix_xfeed"
        $covet.GetConvChar() | Should -Be '!' 
        $covet.mix = "mix_mono"
        $covet.GetConvChar() | Should -Be '"' 
        $covet.mix = "mix_left"
        $covet.GetConvChar() | Should -Be '#' 
        $covet.mix = "mix_right"
        $covet.GetConvChar() | Should -Be '$' 

        $covet.mix = "mix_passthrough"
        $covet.bass = $true; $covet.hdcd = $false
        $covet.GetConvChar() | Should -Be '(' 
        $covet.bass = $false; $covet.hdcd = $true
        $covet.GetConvChar() | Should -Be '0' 
        $covet.bass = $true; $covet.hdcd = $true
        $covet.GetConvChar() | Should -Be '8' 
    }
}
