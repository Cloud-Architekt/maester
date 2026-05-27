Describe "Maester/Entra" -Tag "Maester", "Entra", "XSPM", "Preview" {
    It "MT.1172: UTCM monitors should not report active configuration drifts. See https://maester.dev/docs/tests/MT.1172" -Tag "MT.1172" {
        $result = Test-MtConfigurationDrifts

        if ($null -ne $result) {
            $result | Should -Be $true -Because "UTCM monitors should not have active drifts so the tenant remains aligned to the approved security baseline."
        }
    }
}
