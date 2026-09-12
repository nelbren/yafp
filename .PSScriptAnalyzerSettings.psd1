@{
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        # YAFP exposes user configuration through global variables.
        'PSAvoidGlobalVars'

        # Prompt rendering requires host-aware, colored output.
        'PSAvoidUsingWriteHost'

        # Repository text uses UTF-8 without BOM across all platforms.
        'PSUseBOMForUnicodeEncodedFile'

        # These are internal helpers, not interactive public cmdlets.
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseSingularNouns'

        # Start-Job receives these values through its param and ArgumentList.
        'PSUseUsingScopeModifierInNewRunspaces'
    )
}
