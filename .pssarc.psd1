@{
  Rules = @{
    PSUseCompatibleCommands = @{
      Enable = $true
      TargetProfiles = @(
        # Desktop 5.1
        "win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework"
      )
    }
    PSUseCompatibleSyntax = @{
      Enable = $true
      TargetVersions = @(
        # Desktop 5.1
        "5.1"
      )
    }
    PSUseCompatibleTypes = @{
      Enable = $true
      TargetProfiles = @(
        # Desktop 5.1
        "win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework"
      )
    }
    PSUseCompatibleCmdlets = @{
      Compatibility = @(
        # Desktop 5.1
        "desktop-5.1.14393.206-windows"
      )
    }
  }
}
