<# :
: $optifigura

@ECHO OFF
GOTO :PS1Loader
: #>
# ^ ^ ^ ^ ^ Ignore me ^ ^ ^ ^ ^

# <GrandpaScout>
# READ THE README FOR INSTRUCTIONS!
# RELEVANT LICENSES ARE PLACED AT THE BOTTOM OF THIS FILE!
#
# If you are looking for a list of command line options and what they do, use the `/?` option.
# If you want to generate a default config, use the `/GENCONFIG` option.
#
# This file should not be edited by the end user (most likely you.)
#
#
# (This next part is for PowerShell to read.)
#
# .SYNOPSIS
#   Use /? to view help instead!
#
# .DESCRIPTION
#   This script does not behave like a standard PowerShell script and does not
#   support PowerShell-like parameter syntax.

using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Globalization
using namespace System.Management.Automation

[SemanticVersion] $SCRIPT_VERSION = "1.0.0"


#===================================================|| PS1 LOADER ||===================================================#

<# :
:PS1Loader
SETLOCAL EnableDelayedExpansion
SET "PWSH=powershell"
WHERE /Q pwsh
IF ERRORLEVEL 1 (
  WHERE /Q powershell
  IF ERRORLEVEL 1 (
    >&2 ECHO This script requires PowerShell to run, however it was not found on your system!
    EXIT /B 2
  )
) ELSE (
  SET "PWSH=pwsh"
)

SET "HLNK=false"
IF NOT EXIST "%~dpn0.hlnk.ps1" (
  MKLINK /H "%~dpn0.hlnk.ps1" "%~f0" >nul
  IF ERRORLEVEL 1 EXIT /B 1
  SET "HLNK=true"
)

%PWSH% -executionpolicy remotesigned -File "%~dpn0.hlnk.ps1" %*
SET "EXITCODE=%ERRORLEVEL%"

IF "%HLNK%"=="true" (
  DEL /F "%~dpn0.hlnk.ps1"
)

EXIT /B %EXITCODE%
: #>


#================================================|| OPTION HANDLING ||=================================================#

class OptHandlerOption {
  [string] $name = ""
  [byte] $mode = 0
  [object] $extra1 = $null
  [object] $extra2 = $null
  [ScriptBlock] $callback = $null
  [ushort] $handled = 0
}

class OptHandlerHandledOption {
  [OptHandlerOption] $option = $null
  [object] $value = $null
}

class OptHandler {
  static [bool] $SILENT = $false
  static [string] $SCRIPT_NAME = ($MyInvocation.ScriptName -replace @(".*[/\\]", "") -replace @(".hlnk.ps1$", ".bat"))

  static [Dictionary[string, OptHandlerOption]] $DEFINED_OPTIONS =
    [Dictionary[string, OptHandlerOption]]::new([StringComparer]::InvariantCultureIgnoreCase)
  static [List[OptHandlerHandledOption]] $HANDLED_OPTIONS = [List[OptHandlerHandledOption]]::new()
  static [List[string]] $POSITIONAL = [List[string]]::new()

  static [void] write([string] $string) {
    if ([OptHandler]::SILENT) {return}
    [Console]::Out.Write($string)
  }

  static [void] writeLine([string] $string) {
    if ([OptHandler]::SILENT) {return}
    [Console]::Out.WriteLine($string)
  }

  static [void] error([string] $string) {
    if ([OptHandler]::SILENT) {return}
    [Console]::Error.Write($string)
  }

  static [void] errorLine([string] $string) {
    if ([OptHandler]::SILENT) {return}
    [Console]::Error.WriteLine($string)
  }

  # Checks the name of an option to see if it is valid.
  #
  # ===== PARAMETERS =====
  # [string] $option_name:
  #   The name of the option to check.
  #
  # ====== RETURNS =======
  # Value:
  #   $true = Success
  #   $false = Failure
  #
  # Stderr:
  #   The reason the name is not valid.
  static [bool] checkName([string] $option_name) {
    if ("$option_name" -eq "") {
      [OptHandler]::errorLine("[OptHandler] Option name cannot be empty - `"`"")
      return $false
    }

    if ("$option_name" -eq "/") {
      [OptHandler]::errorLine("[OptHandler] Option name cannot be `"/`" - `"/`"")
      return $false
    }

    # Special handler for `/?` as the help command
    if ($option_name -eq "?") {
      return $true
    }

    if ($option_name -match "[^A-Za-z0-9_-]") {
      [OptHandler]::errorLine("[OptHandler] Option name can only contain A-Z, 0-9, -, and _ - `"$option_name`"")
      return $false
    }

    return $true
  }

  # Creates a new option for use in the command line.
  #
  # ===== PARAMETERS =====
  # [string] $option_name:
  #   The name of the option.
  #   If this is more than one character long, a short alias can be defined in the next parameter.
  #
  # [byte] $option_mode:
  #   Can be provided as a standard decimal number or a prefixed hexadecimal number with two digits. (`29` or `0x1D`.)
  #   ---- -000: Switch      (Does not accept a value, its existance is enough to trigger it.)
  #   ---- -001: Flag        (AKA: Boolean. Accepts either boolean value. Shortcuts: `/X` = "/X:true", `/-X` = "/X:false")
  #   ---- -010: Integer     (Accepts any integer value.)
  #   ---- -011: Float       (Accepts any number value.)
  #   ---- -100: String      (Accepts any value.)
  #   ---- -101: Enum        (Accepts only certain string values.)
  #   ---- 0---: Optional    (Does not need to be provided for the script to work.)
  #   ---- 1---: Required    (Must be provided for the script to work.)
  #   0000 ----: Singular    (Cannot be provided more than once.)
  #   ???? ----: Repeatable  (Can be provided up to [???? + 1] times.)
  #   1111 ----: Infinite    (Can be provided infinitely.)
  #
  # [object] $extra1:
  #   An extra value if an Option Mode needs it.
  #     Integer: The minimum allowed value. If this is `$null` then there is no minimum.
  #     Float: The minimum allowed value. If this is `$null` then there is no minimum.
  #     Enum: An array containing the list of enums.
  #
  # [object] $extra2:
  #   Another extra value if an Option Mode needs it.
  #     Integer: The maximum allowed value. If this is `$null` then there is no maximum.
  #     Float: The maximum allowed value. If this is `$null` then there is no maximum.
  #     Enum: This is `$true` if enum comparison is case-insensitive.
  #
  # [ScriptBlock] $callback:
  #   The name of the function to call every time this option is provided.
  #   The callback is executed as:
  #     ```
  #     callback -value $VALUE -name $OPTION_NAME -mode $OPTION_MODE -extra1 $EXTRA_1 -extra2 $EXTRA_2
  #     ```
  #     `[object] $VALUE` is the value provided to the option.
  #     `[string] $OPTION_NAME` is the name used to trigger the option.
  #     `[byte] $OPTION_MODE` is the Option Mode defined for this option.
  #     `[object] $EXTRA_1` is the Extra 1 defined for this option.
  #     `[object] $EXTRA_2` is the Extra 2 defined for this option.
  #     The callback is expected to return an unsigned 8-bit integer value, similar to an exit code.
  #     0 is a success, anything else is a failure.
  #
  #     The following param block can be used:
  #     `param([object] $value, [string] $name, [byte] $mode, [object] $extra1, [object] $extra2)`
  #
  # ====== RETURNS =======
  # Value:
  #   $true = Success
  #   $false = Failure
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [bool] newOption(
    [string] $option_name, [byte] $option_mode,
    [object] $extra1, [object] $extra2, [ScriptBlock] $callback
  ) {
    if (-not [OptHandler]::checkName($option_name)) {return $false}

    if ([OptHandler]::DEFINED_OPTIONS.ContainsKey($option_name)) {
      [OptHandler]::errorLine("[OptHandler] Option is already defined - `"$option_name`"")
      return $false
    }

    [OptHandler]::DEFINED_OPTIONS.Add($option_name, @{
      name = $option_name
      mode = $option_mode
      extra1 = $extra1
      extra2 = $extra2
      callback = $callback
      handled = 0
    })

    return $true
  }

  # When provided with a list of arguments, this will read through all of them to determine which are actual options and
  # which are standard arguments.
  #
  # The positional arguments are stored in `[OptHandler]::POSITIONAL`.
  #
  # ===== PARAMETERS =====
  # [List[string]] $arguments:
  #   The arguments to read.
  #
  # ====== RETURNS =======
  # Value:
  #   0 = Success
  #   1 = Failure
  #   * = Returned from option callback
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [byte] readArgs([List[string]] $arguments) {
    while ($arguments.Count -gt 0) {
      [string] $arg = $arguments[0]

      if ($arg -eq "--") { # Keep supporting -- even though this is Windows.
        $arguments.RemoveAt(0)
        break
      } elseif ($arg -eq "/") {
        [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Invalid switch - `"`"")
      } elseif ($arg.StartsWith("/")) { # Option
        if ($arg -eq "//") { # This is used as a -- equivalent.
          $arguments.RemoveAt(0)
          break
        } elseif ($arg.StartsWith("/-")) {
          if (-not [OptHandler]::handleNegativeOption($arg)) {return 1}
        } else {
          switch ([OptHandler]::handleStandardOption($arg, $arguments[1])) {
            $false {return 1}
            "shift" {
              $arguments.RemoveAt(0)
              break
            }
          }
        }
      } else {
        [OptHandler]::POSITIONAL.Add($arg)
      }

      $arguments.RemoveAt(0)
    }

    [OptHandler]::POSITIONAL.addRange($arguments)

    foreach ($option in [OptHandler]::DEFINED_OPTIONS.Values) {
      if (($option.mode -band 0x08) -and ($option.handled -le 0)) {
        [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch is required - `"$($option.name)`"")
        return 1
      }
    }

    foreach ($handled in [OptHandler]::HANDLED_OPTIONS) {
      [OptHandlerOption] $option = $handled.option
      if ($null -eq $option.callback) {continue}

      [byte] $callback_status = &$option.callback -value $handled.value $option.name $option.mode $option.extra1 $option.extra2
      if ($callback_status -ne 0) {return $callback_status}
    }

    return 0
  }

  # Checks if an option requires a value to function.
  #
  # ===== PARAMETERS =====
  # [string] $option_name:
  #   The name of the option to check.
  #
  # ====== RETURNS =======
  # Value:
  #   $true = Requires a value.
  #   $false = Does not require a value.
  static [bool] needsValue([string] $option_name) {
    $option = [OptHandler]::DEFINED_OPTIONS[$option_name]
    return (($option.mode -band 0x07 ) -ge 2)
  }

  # Attempts to coerce a string into a boolean value.
  #
  # ===== PARAMETERS =====
  # [string] $option_name:
  #   The name of the option for error messages.
  #
  # [string] $string:
  #   The string to coerce.
  #
  # ====== RETURNS =======
  # Status:
  #   $true = Success, true value.
  #   $false = Success, false value.
  #   $null = Failure.
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [Nullable[bool]] checkBoolean([string] $option_name, [string] $string) {
    switch ($string.ToLowerInvariant()) {
      {$_ -in @("t", "true", "y", "yes", "on")} {return $true}
      {$_ -in @("f", "false", "n", "no", "off")} {return $false}
    }

    [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch expects a boolean value - `"$option_name`"")
    return $null
  }

  # Attempts to coerce a string into an integer value.
  #
  # ===== PARAMETERS =====
  # [string] $option_name:
  #   The name of the option for error messages.
  #
  # [string] $string:
  #   The string to coerce.
  #
  # [long?] $min:
  #   The minimum allowed value.
  #   This is $null if no minimum is specified.
  #
  # [long?] $max:
  #   The maximum allowed value.
  #   This is $null if no maximum is specified.
  #
  # ====== RETURNS =======
  # Status:
  #   [long] = Success, integer value.
  #   $null = Failure.
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [Nullable[long]] checkInteger(
    [string] $option_name, [string] $string, [Nullable[long]] $min, [Nullable[long]] $max
  ) {
    [bool] $success = $false
    [long] $value = 0

    # Why not just use $string -as [long]?
    # Because it allows floating point values.

    switch -Regex ($string.ToLowerInvariant()) {
      "^[-+]?0[Xx]" {
        [string] $parsestr = $string
        if ($parsestr -match "^[-+]") {
          $parsestr = $parsestr.Substring(3)
        } else {
          $parsestr = $parsestr.Substring(2)
        }
        $success = [Long]::TryParse($parsestr, [NumberStyles]::HexNumber, $null, [ref]$value)
        break
      }

      "^[-+]?0[Oo]" {
        [string] $parsestr = $string
        if ($parsestr -match "^[-+]") {
          $parsestr = $parsestr.Substring(3)
        } else {
          $parsestr = $parsestr.Substring(2)
        }
        try {
          $value = [Convert]::ToInt64($parsestr, 8)
          $success = $true
        } catch {
          $success = $false
        }
        break
      }

      "^[-+]?0[Bb]" {
        [string] $parsestr = $string
        if ($parsestr -match "^[-+]") {
          $parsestr = $parsestr.Substring(3)
        } else {
          $parsestr = $parsestr.Substring(2)
        }
        $success = [long]::TryParse($parsestr, [NumberStyles]::BinaryNumber, $null, [ref]$value)
        break
      }

      default {
        [string] $parsestr = $string
        if ($parsestr -match "^[-+]") {$parsestr = $parsestr.Substring(1)}
        $success = [long]::TryParse($parsestr, [ref]$value)
        break
      }
    }

    if ($string.StartsWith("-")) {
      if ($value -eq [Long]::MinValue) {
        # -[Long]::MinValue would create an out-of-bounds number
        $success = $false
      } else {
        $value = -$value
      }
    }

    if (-not $success) {
      [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch expects an integer value - `"$option_name`"")
      return $null
    }

    if (($null -ne $min) -and ($value -lt $min)) {
      [OptHandler]::errorLine(
        "$([OptHandler]::SCRIPT_NAME): Switch received integer value below the minimum of $min - `"$option_name`""
      )
      return $null
    } elseif (($null -ne $max) -and ($value -gt $max)) {
      [OptHandler]::errorLine(
        "$([OptHandler]::SCRIPT_NAME): Switch received integer value above the maximum of $max - `"$option_name`""
      )
      return $null
    }

    return $value
  }

  # Attempts to coerce a string into a number value.
  #
  # ===== PARAMETERS =====
  # [string] $option_name:
  #   The name of the option for error messages.
  #
  # [string] $string:
  #   The string to coerce.
  #
  # [double?] $min:
  #   The minimum allowed value.
  #   This is $null if no minimum is specified.
  #
  # [double?] $max:
  #   The maximum allowed value.
  #   This is $null if no maximum is specified.
  #
  # ====== RETURNS =======
  # Status:
  #   [double] = Success, number value.
  #   $null = Failure.
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [Nullable[double]] checkNumber(
    [string] $option_name, [string] $string, [nullable[double]] $min, [nullable[double]] $max
  ) {
    [bool] $success = $false
    [double] $value = 0.0

    switch ($string.ToLowerInvariant()) {
      {$_ -in @("nan", "notanumber", "not a number", "ind", "indeterminate", "qnan", "snan")} {
        $value = [Double]::NaN
        break
      }
      {$_ -in @("inf", "infinity", "infinite", "∞")} {
        $value = [Double]::PositiveInfinity
        break
      }
      {$_ -in @("-inf", "-infinity", "-infinite", "-∞")} {
        $value = [Double]::NegativeInfinity
        break
      }
      default {
        $value = $string -as [double]
        break
      }
    }

    if (-not $success) {
      [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch expects a number value - `"$option_name`"")
      return $null
    }

    if (($null -ne $min) -and ($value -lt $min)) {
      [OptHandler]::errorLine(
        "$([OptHandler]::SCRIPT_NAME): Switch received number value below the minimum of $min - `"$option_name`""
      )
      return $null
    } elseif (($null -ne $max) -and ($value -gt $max)) {
      [OptHandler]::errorLine(
        "$([OptHandler]::SCRIPT_NAME): Switch received number value above the maximum of $max - `"$option_name`""
      )
      return $null
    }

    return $value
  }

  # Attempts to select a valid value from an enum list.
  #
  # ===== PARAMETERS =====
  # [string] $option_name:
  #   The name of the option for error messages.
  #
  # [string] $string:
  #   The string to search for in the enum list.
  #
  # [string[]] $enum:
  #   The enum list to search.
  #
  # [bool] $icase:
  #   The case sensitivity of the enum check.
  #   This is $true if case-insensitive.
  #
  # ====== RETURNS =======
  # Status:
  #   [uint32] = Success, the index of the first matching enum value.
  #   $null = Failure.
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [nullable[uint32]] checkEnum([string] $option_name, [string] $string, [string[]] $values, [bool] $icase) {
    if ($icase) {
      for ([uint] $i = 0; $i -lt $values.Count; $i++) {
        if ($string -ieq $values[$i]) {return $i}
      }
    } else {
      for ([uint] $i = 0; $i -lt $values.Count; $i++) {
        if ($string -ceq $values[$i]) {return $i}
      }
    }

    [OptHandler]::errorLine(
      "$([OptHandler]::SCRIPT_NAME): Switch expects a valid enum value - `"$option_name`""
    )
    return $null
  }

  # Prepares an option to be run later.
  #
  # ===== PARAMETERS =====
  # [string] $option_name:
  #   The name of the option to prepare.
  #
  # [string?] $option_value:
  #   The value being passed into the option, if any.
  #   THIS SHOULD BE `$null` IF IT DOES NOT EXIST.
  #
  # ====== RETURNS =======
  # Value:
  #   $true = Success
  #   $false = Failure
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [bool] handleOption([string] $option_name, [object] $option_value) {
    [OptHandlerOption] $option = [OptHandler]::DEFINED_OPTIONS[$option_name]
    [int] $option_mrep = $option.mode -shr 4

    if (($option_mrep -lt 15) -and ($option.handled -gt $option_mrep)) {
      if ($option_mrep -eq 0) {
        [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch cannot be repeated - `"$option_name`"")
      } else {
        [OptHandler]::errorLine(
          "$([OptHandler]::SCRIPT_NAME): Switch cannot be repeated more than $($option_mrep - 1) times - `"$option_name`""
        )
      }
      return $false
    }

    [object] $value = $null
    switch ($option.mode -band 0x07) {
      "0" {
        if ($null -ne $option_value) {
          [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch cannot take a value - `"$option_name`"")
          return $false
        }
        break
      }

      "1" {
        if ($null -eq $option_value) {
          $value = $true
        } else {
          $value = [OptHandler]::checkBoolean($option_name, $option_value)
          if ($null -eq $value) {return $false}
        }
        break
      }

      "2" {
        if ($null -eq $option_value) {
          [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch requires an argument - `"$option_name`"")
          return $false
        }
        $value = [OptHandler]::checkInteger($option_name, $option_value, $option.extra1, $option.extra2)
        if ($null -eq $value) {return $false}
        break
      }

      "3" {
        if ($null -eq $option_value) {
          [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch requires an argument - `"$option_name`"")
          return $false
        }
        $value = [OptHandler]::checkNumber($option_name, $option_value, $option.extra1, $option.extra2)
        if ($null -eq $value) {return $false}
        break
      }

      "4" {
        if ($null -eq $option_value) {
          [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch requires an argument - `"$option_name`"")
          return $false
        }
        $value = $option_value
        break
      }

      "5" {
        if ($null -eq $option_value) {
          [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch requires an argument - `"$option_name`"")
          return $false
        }
        $value = [OptHandler]::checkEnum($option_name, $option_value, $option.extra1, $option.extra2)
        if ($null -eq $value) {return $false}
        $value = $option.extra1[$value]
        break
      }

      default {
        [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Switch has unknown argument type - `"$option_name`"")
        return $false
      }
    }

    [OptHandler]::HANDLED_OPTIONS.Add(@{
      option = $option
      value = $value
    })
    $option.handled++
    return $true
  }

  # Handles a single standard option.
  #
  # ===== PARAMETERS =====
  # [string] $option_arg:
  #   The argument containing the option to handle.
  #
  # [string?] $extra_arg:
  #   An extra argument just in case the option needs it.
  #   THIS SHOULD BE `$null` IF IT DOES NOT EXIST.
  #
  # ====== RETURNS =======
  # Value:
  #   $true = Success
  #   $false = Failure
  #   "shift" = Success, shift argument list.
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [string] handleStandardOption([string] $option_arg, [object] $extra_arg) {
    [string] $option_name = $option_arg.Substring(1)
    if ($option_name -match "[=:]") {$option_name = $option_name.Substring(0, $option_name.IndexOfAny(@('=', ':')))}

    # Does /OPTION exist?
    if (-not [OptHandler]::DEFINED_OPTIONS.ContainsKey($option_name)) {
      if ($option_name.Length -gt 1) {
        # Does /O exist?
        if (-not [OptHandler]::DEFINED_OPTIONS.ContainsKey($option_name.Substring(0, 1))) {
          [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Invalid switch - `"$option_name`"")
          return $false
        }

        # /O PTION
        if (-not [OptHandler]::handleOption($option_name.Substring(0, 1), $option_arg.Substring(2))) {return $false}
        return $true
      }

      [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Invalid switch - `"$option_name`"")
      return $false
    }

    if ($option_arg -match "[=:]") {
      # /OPTION:VALUE
      if (-not [OptHandler]::handleOption($option_name, $option_arg.Substring($option_arg.IndexOfAny(@('=', ':'))))) {
        return $false
      }
    } elseif (($null -eq $extra_arg) -and [OptHandler]::needsValue($option_name)) {
      # /OPTION VALUE
      if (-not [OptHandler]::handleOption($option_name, [string]$extra_arg)) {return $false}
      return "shift"
    } else {
      # /OPTION
      if (-not [OptHandler]::handleOption($option_name, $null)) {return $false}
    }

    return $true
  }

  # Handles a single negative option.
  #
  # ===== PARAMETERS =====
  # [string] $option_arg:
  #   The argument containing the option to handle.
  #
  # ====== RETURNS =======
  # Value:
  #   $true = Success
  #   $false = Failure
  #
  # Stderr:
  #   The error message if a failure occurred.
  static [bool] handleNegativeOption([string] $option_arg) {
    [string] $option_name = $option_arg.Substring(2)
    if ($option_name -match "[=:]") {$option_name = $option_name.Substring(0, $option_name.IndexOfAny(@('=', ':')))}

    # Does /-OPTION exist?
    if (-not [OptHandler]::DEFINED_OPTIONS.ContainsKey($option_name)) {
      if ($option_name.Length -gt 1) {
        # Does /-O exist?
        if (-not [OptHandler]::DEFINED_OPTIONS.ContainsKey($option_name.Substring(0, 1))) {
          [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Invalid switch - `"$option_name`"")
          return $false
        }

        # /-O PTION
        $option_name = $option_name.Substring(0, 1)
        [OptHandler]::errorLine(
          "$([OptHandler]::SCRIPT_NAME): Switch cannot accept value while being unset - `"$option_name`""
        )
        return $false
      }

      [OptHandler]::errorLine("$([OptHandler]::SCRIPT_NAME): Invalid switch - `"$option_name`"")
      return $false
    }

    if (([OptHandler]::DEFINED_OPTIONS[$option_name].mode -band 0x07) -ne 1) {
      [OptHandler]::errorLine(
        "$([OptHandler]::SCRIPT_NAME): Switch cannot be unset as it is not a flag - `"$option_name`""
      )
      return $false
    } elseif ($option_arg -match "[=:]") {
      # /-OPTION:VALUE
      [OptHandler]::errorLine(
        "$([OptHandler]::SCRIPT_NAME): Switch cannot accept value while being unset - `"$option_name`""
      )
      return $false
    } else {
      # /-OPTION
      if (-not [OptHandler]::handleOption($option_name, "false")) {return $false}
    }

    return $true
  }
}

#===================================================|| VARIABLES ||====================================================#

$CONFIG = @{
  textures = $null
  level = $null
  sounds = $null
  backup = $null
  nogit = $null
  verbose = $null
  dry = $null

  config = "./.opticonfig"
  yes = ([Console]::IsInputRedirected -or $MyInvocation.ExpectingInput)
}

[List[string]] $FILE_selected = [List[string]]::new()
[List[string]] $FILE_cfgrules = [List[string]]::new()


#===================================================|| FUNCTIONS ||====================================================#

# Prints a debug message if $CONFIG.verbose is $true.
function debug([string] $message) {
  if ($CONFIG.verbose) {
    [Console]::Out.WriteLine("[debug]> $message")
    return $true
  }
  return $false
}

# Quick repr-like function for dry printing.
function repr([object] $object) {
  if ($null -eq $object) {return '$null'}
  switch ($object.GetType()) {
    "bool" {
      if ($object) {
        return '$true'
      } else {
        return '$false'
      }
    }
    "SwitchParameter" {
      if ($object.IsPresent) {
        return '$true'
      } else {
        return '$false'
      }
    }
    "byte" {return "${object}uy"}
    "sbyte" {return "${object}y"}
    {$_ -in @("int16", "short")} {return "${object}s"}
    {$_ -in @("uint16", "ushort")} {return "${object}us"}
    "int" {return "$object"}
    {$_ -in @("uint32", "uint")} {return "${object}"}
    "long" {return "${object}l"}
    {$_ -in @("uint64", "ulong")} {return "${object}ul"}
    "bigint" {return "$($object.ToString("R", [NumberFormatInfo]::InvariantInfo))n"}
    "System.Half" {
      if ($object -eq [half]::PositiveInfinity) {
        return "[half]::PositiveInfinity"
      } elseif ($object -eq [half]::NegativeInfinity) {
        return "[half]::NegativeInfinity"
      } elseif ($object -ne $object) {
        return "[half]::NaN"
      }

      return "[half]$($object.ToString("G5", [NumberFormatInfo]::InvariantInfo))"
    }
    "float" {
      if ($object -eq [float]::PositiveInfinity) {
        return "[float]::PositiveInfinity"
      } elseif ($object -eq [float]::NegativeInfinity) {
        return "[float]::NegativeInfinity"
      } elseif ($object -ne $object) {
        return "[float]::NaN"
      }

      return "[float]$($object.ToString("G9", [NumberFormatInfo]::InvariantInfo))"
    }
    "double" {
      if ($object -eq [double]::PositiveInfinity) {
        return "[double]::PositiveInfinity"
      } elseif ($object -eq [double]::NegativeInfinity) {
        return "[double]::NegativeInfinity"
      } elseif ($object -ne $object) {
        return "[double]::NaN"
      }

      return $object.ToString("G17", [NumberFormatInfo]::InvariantInfo)
    }
    "decimal" {return "${object}d"}
    "string" {
      [string] $string = $object `
        -replace @('([`"$])', '`$1') -replace @("`0", '`0') `
        -replace @("`a", '`a') -replace @("`b", '`b') -replace @("`e", '`e') -replace @("`f", '`f') `
        -replace @("`n", '`n') -replace @("`r", '`r') -replace @("`t", '`t') -replace @("`v", '`v')
      return "`"$string`""
    }
    "hashtable" {
      [List[string]] $pairs = [List[string]]::new()
      foreach ($k in $object.Keys) {$pairs.Add("$(repr $object[$k]) = $(repr $object[$k])")}
      return "@{$($pairs -join "; ")}"
    }
    {$_ -match "[a-z0-9.]+(?:\[[a-z0-9.]+\])*(?:\[\])+$"} { #name[], name[name][], name[][], etc.
      [List[string]] $values = [List[string]]::new()
      foreach ($v in $object) {$values.Add("$(repr $v)")}
      return "@($($values -join ", "))"
    }
    default {return "<$_>"}
  }
}

# Sets up a command for dry running
# THIS FUNCTION SETS $LASTEXITCODE
function dry([string] $command, [IEnumerable] $arguments, [Parameter()][switch] $q) {
  if ($arguments -is [string]) {$arguments = [string[]]@($arguments)}

  if ($CONFIG.dry) {
    [List[string]] $argstrs = [List[string]]::new()

    # If you aren't an idiot this should never cause an issue.
    if ($arguments -is [IDictionary]) {
      foreach ($key in $arguments.Keys) {
        if ($arguments[$key] -is [switch]) {
          if ($arguments[$key].IsPresent) {
            $argstrs.Add("-$key")
          } else {
            $argstrs.Add("-${key}:`$false")
          }
        } else {
          $argstrs.Add("-$key")
          $argstrs.Add((repr $arguments[$key]))
        }
      }
    } elseif ($arguments -is [IEnumerable]) {
      foreach ($item in $arguments) {
        $argstrs.Add((repr $item))
      }
    } else {
      $argstrs.Add((repr $arguments))
    }

    if ($CONFIG.verbose) {
      [Console]::Out.WriteLine("[dry]>   $command $($argstrs -join " ")")
    } else {
      [Console]::Out.WriteLine("[dry]> $command $($argstrs -join " ")")
    }

    $script:LASTEXITCODE = 0
    return
  }

  [bool] $success = $false
  [byte] $code = 0

  if ($q) {
    &$command @arguments >$null 2>$null
    $success = $?
    $code = $LASTEXITCODE
  } else {
    &$command @arguments
    $success = $?
    $code = $LASTEXITCODE
  }

  # Powershell command failed
  if ((-not $success) -and (0 -eq $code)) {
    $script:LASTEXITCODE = 1
  } else {
    $script:LASTEXITCODE = $code
  }
}

# Gives the user a yes/no choice.
function choiceYN([string] $msg = "Confirm?") {
  if ($CONFIG.yes) {return $true}

  [Console]::Out.Write("$msg [Y/N]> ")
  while ($true) {
    [ConsoleKeyInfo] $keyinfo = [Console]::ReadKey($true)
    switch ($keyinfo.Key) {
      "Y" {
        [Console]::Out.WriteLine("Y")
        return $true
      }

      "N" {
        [Console]::Out.WriteLine("N")
        return $false
      }

      default {
        [Console]::Out.Write("`a")
        break
      }
    }
  }

  return $null
}

#
function readConfig() {
  if ("./.opticonfig" -eq $CONFIG.config) {
    if (-not (Test-Path $CONFIG.config -PathType Leaf)) {
      [byte] $result = &([OptHandler]::DEFINED_OPTIONS["GENCONFIG"].callback)
      if ($result -ne 3) {return $false}
    }
  } elseif (-not (Test-Path $CONFIG.config -PathType Leaf)) {
    [Console]::Error.WriteLine("config with path [$($CONFIG.config)] does not exist")
    return $false
  }

  if (-not (Get-Content $CONFIG.config -TotalCount 1 -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("config with path [$($CONFIG.config)] is not readable")
    return $false
  }

  [OptHandler]::SILENT = $true

  [bool] $fail = $false
  [uint32] $lineno = 0
  foreach ($line in Get-Content $CONFIG.config) {
    $lineno++
    $line = $line.TrimStart()
    if (($line -eq "") -or ($line.StartsWith("#"))) {
      # "" or "# comment"
      continue
    } elseif ($line.StartsWith("+")) {
      $line = $line -replace @("^\+ ?", "") -replace @("\\", "/")
      debug "Read config inclusion +$line" >$null
      foreach ($path in Resolve-Path $line -ErrorAction SilentlyContinue) {
        if ($path.EndsWith("/") -or (Test-Path $path -PathType Container)) {
          [Console]::Error.WriteLine(
            "$($CONFIG.config):${lineno}: unable to include '$path', cannot include directories"
          )
        } elseif (-not (Test-Path $path -PathType Leaf)) {
          [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: unable to include '$path', file does not exist")
        } elseif ((-not $path.EndsWith(".png")) -and (-not $path.EndsWith(".ogg"))) {
          [Console]::Error.WriteLine(
            "$($CONFIG.config):${lineno}: unable to include '$path', file type is not supported"
          )
        } else {
          $FILE_cfgrules.Add("+$path")
        }
      }
    } elseif ($line.StartsWith("-")) {
      $line = $line -replace @("^- ?", "") -replace @("\\", "/")
      debug "Read config exclusion -$line" >$null
      foreach ($path in Resolve-Path $line -ErrorAction SilentlyContinue) {
        if (-not (Test-Path $path -PathType Any)) {
          [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: unable to exclude '$path', it does not exist")
        } elseif (Test-Path $path -PathType Container) {
          $FILE_cfgrules.Add("!$path")
        } elseif ((-not $path.EndsWith(".png")) -and (-not $path.EndsWith(".ogg"))) {
          [Console]::Error.WriteLine(
            "$($CONFIG.config):${lineno}: unable to exclude '$path', file type is not supported"
          )
        } else {
          $FILE_cfgrules.Add("-$path")
        }
      }
    } elseif ($line.Contains("=")) {
      [string] $key = $line.Substring(0, $line.IndexOf("="))
      [string] $value = $line.Substring($line.IndexOf("=") + 1)
      [object] $result = $null

      if ($key.EndsWith(" ")) {
        $key = $key.TrimEnd()
        if ($value.StartsWith(" ")) {$value = $value.Substring(1)}
      }

      debug "Read config option $key=$value" >$null
      switch -CaseSensitive ($key) {
        "textures" {
          $result = [OptHandler]::checkBoolean("", $value)
          if ($null -eq $result) {
            [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: invalid value given to config option 'textures'")
            $fail = $true
          } elseif ($null -eq $CONFIG.textures) {
            $CONFIG.textures = $result
          }
        }

        "level" {
          $result = [OptHandler]::checkInteger("", $value, 1, 4)
          if ($null -eq $result) {
            [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: invalid value given to config option 'level'")
            $fail = $true
          } elseif ($null -eq $CONFIG.level) {
            $CONFIG.level = $result
          }
        }

        "sounds" {
          $result = [OptHandler]::checkBoolean("", $value)
          if ($null -eq $result) {
            [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: invalid value given to config option 'sounds'")
            $fail = $true
          } elseif ($null -eq $CONFIG.sounds) {
            $CONFIG.sounds = $result
          }
        }

        "backup" {
          $result = [OptHandler]::checkBoolean("", $value)
          if ($null -eq $result) {
            [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: invalid value given to config option 'backup'")
            $fail = $true
          } elseif ($null -eq $CONFIG.backup) {
            $CONFIG.backup = $result
          }
        }

        "nogit" {
          $result = [OptHandler]::checkBoolean("", $value)
          if ($null -eq $result) {
            [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: invalid value given to config option 'nogit'")
            $fail = $true
          } elseif ($null -eq $CONFIG.nogit) {
            $CONFIG.nogit = $result
          }
        }

        "verbose" {
          $result = [OptHandler]::checkBoolean("", $value)
          if ($null -eq $result) {
            [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: invalid value given to config option 'verbose'")
            $fail = $true
          } elseif ($null -eq $CONFIG.verbose) {
            $CONFIG.verbose = $result
          }
        }

        "dry" {
          $result = [OptHandler]::checkBoolean("", $value)
          if ($null -eq $result) {
            [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: invalid value given to config option 'dry'")
            $fail = $true
          } elseif ($null -eq $CONFIG.dry) {
            $CONFIG.dry = $result
          }
        }

        default {
          [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: unknown config option '$key'")
          $fail = $true
        }
      }
    } else {
      [Console]::Error.WriteLine("$($CONFIG.config):${lineno}: failed to parse line")
      $fail = $true
    }
  }

  [OptHandler]::SILENT = $false
  return (-not $fail)
}

#
function findProgram([string] $name, [string] $getitfrom) {
  $pathsplitter = ":"
  if ($IsWindows) {
    $name = "$name.exe"
    $pathsplitter = ";"
  }

  foreach ($path in ($env:PATH -split $pathsplitter)) {
    if (Test-Path "$path/$name") {return "$name"}
  }

  if (Test-Path "./$name") {
    return "./$name"
  } elseif (Test-Path "../$name") {
    return "../$name"
  } elseif (Test-Path "./.git/hooks/$name") {
    return "./.git/hooks/$name"
  }

  [Console]::Error.WriteLine("Could not find program ``$name``.`n$getitfrom")

  return $null
}

#
function verifyPrograms() {
  $status = $true

  if (-not $CONFIG.nogit) {
    if (Test-Path "./.git/" -PathType Container) {
      if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Could nto find command ``git``")
        $status = $false
      }
    } else {
      debug "Not in a git repository. Git features are disabled!" >$null
      $CONFIG.nogit = $false
    }
  }

  if ($CONFIG.textures) {
    # Find Oxipng.
    $script:OXIPNG = findProgram "oxipng" (
      "  Get it from https://github.com/oxipng/oxipng/releases" +
      "  If using Windows, you might want [oxipng-#.#.#-x86_64-pc-windows-msvc.zip]." +
      "  Otherwise, you'll be smart enough to figure out which one you need."
    )
    if (-not $script:OXIPNG) {$status = $false}

    # Find PNGOUT
    if ($CONFIG.level -ge 4) {
      $script:PNGOUT = findProgram "pngout" (
        "  Optimization level 4 requires PNGOUT to function." +
        "  If using Windows, get it from https://advsys.net/ken/util/pngout.exe" +
        "  Otherwise, get it from https://www.jonof.id.au/kenutils.html"
      )
      if (-not $script:PNGOUT) {$status = $false}
    }
  }

  if ($CONFIG.sounds) {
    # Find Optivorbis
    $script:OPTIVORBIS = findProgram "optivorbis" (
      "  Get it from https://github.com/OptiVorbis/OptiVorbis/releases" +
      "  If using Windows, you might want [OptiVorbis.CLI.x86_64-pc-windows-gnu.zip]." +
      "  Otherwise, you'll be smart enough to figure out which one you need."
    )
    if (-not $script:OPTIVORBIS) {$status = $false}
  }

  return $status
}

#
function gitFiles() {
  # Did you know that if your output encoding is not UTF8, `command` and `(command)` will return two different values?
  # I know now.

  $PREV_ENCODING = [Console]::OutputEncoding
  [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8
  [string[]] $lines = (git status -z -uno) -split "`0"
  [Console]::OutputEncoding = $PREV_ENCODING

  foreach ($line in $lines) {
    if ($line -eq "") {continue}
    [string] $type = $line.Substring(0, 1)
    [string] $file = $line.Substring(3)

    debug "Checking file ($type) [$file]." >$null
    if ($file.EndsWith(".png") -or $file.EndsWith(".ogg")) {
      switch -CaseSensitive ($type) {
        # Yes
        "M" {
          [Console]::Out.WriteLine("File [$file] has been modified. Optimizing...")
          $FILE_selected.Add($file)
          break
        }

        "A" {
          [Console]::Out.WriteLine("File [$file] has been modified. Optimizing...")
          $FILE_selected.Add($file)
          break
        }

        # No
        {$_ -in @(" ", "?", "!")} {
          debug "File [$file] has not been staged. Doing nothing." >$null
          break
        }

        "T" {
          debug "File [$file] had its type changed. Doing nothing." >$null
          break
        }

        "D" {
          debug "File [$file] had its type changed. Doing nothing." >$null
          break
        }

        "R" {
          debug "File [$file] had its type changed. Doing nothing." >$null
          break
        }

        "C" {
          debug "File [$file] had its type changed. Doing nothing." >$null
          break
        }

        default {
          debug "Unknown status ($type) for file [$file]. Doing nothing..." >$null
          break
        }
      }
    } else {
      debug "File [$file] is not supported. Doing nothing..." >$null
      break
    }
  }

  return $true
}

#
function dirFiles() {
  foreach ($fileinfo in Get-ChildItem "." -Recurse -Include @("*.png", "*.ogg")) {
    [string] $path = Resolve-Path (Get-ChildItem "." -Recurse -Include @("*.png", "*.ogg"))[0] -Relative
    debug "Checking file [$path]." >$null
    if (Test-Path $path -PathType Leaf) {
      [Console]::Out.WriteLine("File [$path] was found in the current directory. Optimizing...")
      $FILE_selected.Add($path)
    }
  }

  return $true
}

#
function argFiles([Parameter(ValueFromRemainingArguments = $true)] [string[]] $arguments) {
  foreach ($arg in $arguments) {
    [string[]] $files = Resolve-Path $arg -ErrorAction SilentlyContinue
    if ($files.Count -le 0) {
      [Console]::Error.WriteLine("File [$arg] does not exist!")
      continue
    }

    foreach ($file in $files) {
      debug "Checking file [$file]." >$null
      if (Test-Path $file -PathType Leaf) {
        if ($file.EndsWith(".png") -or $file.EndsWith(".ogg")) {
          [Console]::Error.WriteLine("File [$file] is not supported by this script!")
        } else {
          [Console]::Out.WriteLine("File [$file] was found. Optimizing...")
          $FILE_selected.Add($file)
        }
      }
    }
  }

  return $true
}

#
function applyCfgFileRules() {
  foreach ($rule in $FILE_cfgrules) {
    [string] $path = $rule.Substring(1)
    [string] $mode = $rule.Substring(0, 1)

    # The validity of files in the CFG rule set is handled as they are read in `readConfig()`.

    if ($mode -eq "+") {
      # Adds the given path to the list of selected files. Included files are verified before being added to this list.
      # Unless you are intentionally trying to mess up the script or are playing with files that are not guaranteed to
      # exist at a later time, nothing should go wrong here.
      $FILE_selected.Add($path)
      debug "Applying config inclusion [+ $path]" >$null
      debug "  File [$path] was included" >$null
    } elseif ($mode -eq "-") {
      # Compares the real path of the excluded file to the real path of the file to exclude.
      # If they match, then the file is the one to exclude.
      # The search does not stop on the first match so that duplicate entries can be handled properly.
      debug "Applying config inclusion [- $path]" >$null
      [string] $realpath = Resolve-Path $path
      for ([int] $i = $FILE_selected.Count; $i -ge 0; $i--) {
        [string] $file = $FILE_selected[$i]
        [string] $realfile = Resolve-Path $file
        if ($realpath -eq $realfile) {
          $FILE_selected.RemoveAt($i)
          debug "  File [$file] was excluded." >$null
        }
      }
    } elseif ($mode -eq "!") {
      # Compares the real path of the excluded directory to the real path of the file to exclude.
      # If the "real path is a prefix of the "real file" then the file exists in the excluded directory.
      debug "Applying config exclusion [! $path]" >$null
      [string] $realpath = Resolve-Path $path
      for ([int] $i = $FILE_selected.Count; $i -ge 0; $i--) {
        [string] $file = $FILE_selected[$i]
        [string] $realfile = Resolve-Path $file
        if ($realfile.StartsWith($realpath)) {
          $FILE_selected.RemoveAt($i)
          debug "  File [$file] was excluded." >$null
        }
      }
    } else {
      [Console]::Error.WriteLine("Unknown rule [$mode $path].")
      return $false
    }
  }

  return $true
}


#====================================================|| OPTIONS ||=====================================================#

# /?
[OptHandler]::newOption("?", 0x00, $null, $null, {
  param()

  [Console]::Out.WriteLine(@"
Optimizes Figura avatar files, reducing the impact they have on the limited
space available to an avatar.

Options are read in the order they are provided to the script!
(``/Y /GENCONFIG`` will skip confirmation to overwrite a config file,
``/GENCONFIG /Y`` will not.)

$([OptHandler]::SCRIPT_NAME) [/B | /-B] [/CONFIG path] [/D | /-D] [/GENCONFIG]
  [/N | /-N] [/O[:]level] [/S | /-S] [/T | /-T] [/V | /-V] [/Y | /-Y]
  [[drive:][path]filename[ ...]]

  /B          Creates backups of optimized files.
  /CONFIG     Changes the file used as the config. This also changes the path
              that /GENCONFIG writes to.
  path        The path of the config file to use.
  /D          Prints the commands that would be executed if this script was run.
              No actual changes will be made to files.
  /GENCONFIG  Generates the base config used by this script and exits. If the
              config already exists, it will be backed up and a clean one will
              be written.
  /N          Disables Git features even if this script is run in the root of a
              Git repository.
  /O          Sets the level of optimization applied to texture files.
  level        0  Fast optimization          2 Standard optimization
               1  Low optimization           3 Full optimization
  /S          Optimizes sound files.
  /T          Optimizes texture files.
  /V          Prints debug information while the script is running.
  /Y          Automatically responds with 'y' to confirmation dialogs.
  [drive:][path]filename
              Specifies files to optimize.

Prefixing the B, D, N, S, T, V, or Y switches with /- instead of / turns them
off.
If the current session is not interactive, ``/Y`` is implied.

If this script is given file arguments, it will optimize only those files.
If not given any file arguments, it will do one of two things:
- Optimize all files in the current Git repository if the current directory is
  the root of said repo.
- Optimize all files in the current directory and any subdirectories if the
  current directory is not the root of a Git repo.

The ``.opticonfig`` file further controls what settings the script uses and the
list of files it optimizes. If the config does not exist, it will be created
when the script next runs. Use the ``/GENCONFIG`` switch to only generate the
config and do nothing else.

OptiFigura (c) 2025 Grandpa Scout
Oxipng (c) 2016 Joshua Holmer
PNGOUT (c) 2015 Ken Silverman
OptiVorbis (c) 2022 Alejandro González
Check bottom of the script file for full licenses.
"@)
  return 3
}) >$null

# /VERSION
[OptHandler]::newOption("VERSION", 0x00, $null, $null, {
  param()

  [Console]::Out.WriteLine($SCRIPT_VERSION)
  return 3
}) >$null

# /B
[OptHandler]::newOption("B", 0x01, $null, $null, {
  param([bool] $value)

  $CONFIG.backup = $value
  return 0
}) >$null

# /CONFIG=PATH
[OptHandler]::newOption("CONFIG", 0x04, $null, $null, {
  param([string] $value)

  $CONFIG.config = $value
  return 0
}) >$null

# /D
[OptHandler]::newOption("D", 0x01, $null, $null, {
  param([bool] $value)

  $CONFIG.dry = $value
  return 0
}) >$null

# /GENCONFIG
[OptHandler]::newOption("GENCONFIG", 0x00, $null, $null, {
  if (Test-Path $CONFIG.config -PathType Leaf) {
    if (-not (choiceYN "Do you wish to overwrite ``$($CONFIG.config)``")) {
      return 1
    }
    Copy-Item $CONFIG.config "$($CONFIG.config).bak"
  }

  try {
    @"
# Auto-generated default config
#
# This file both serves as a template for custom options and as the default
# options for \`optimze.sh\` and \`optimize.bat\`.
#
# WARNING: This file will be overwritten if the \`/GENCONFIG\` \`--gen-config\`
#          option is supplied to the script.
#          No more than a single backup will be kept when this happens.


#=============================== OPTION CONFIGS ===============================#
# These control the default options the script uses when it is executed.
# The options set in this config file are always overwritten by any command-line
# options provided to the script.
# Not all options are editable from this config either because it would not make
# sense for them to be editable or because they do not accept a value in the
# first place.

# Should png textures be optimized?
# BOOLEAN [Default: true]
textures=true

# What level of optimization should be performed on textures?
#   1: Quick optimization    2: Standard optimization
#   3: High optimization     4: Best optimization
# INTEGER (1-4) [Default: 2]
level=2

# Should ogg sounds be optimized?
# BOOLEAN [Default: true]
sounds=true

# Should files be backed up before optimization?
# BOOLEAN [Default: true]
backup=true

# Should Git features be disabled?
# BOOLEAN [Default: false]
nogit=false

# Should debug information be printed?
# BOOLEAN [Default: false]
verbose=false

# Should files be left untouched, only printing what would have happened?
# BOOLEAN [Default: false]
dry=false


#================================= FILE RULES =================================#
# These control what files are always included or always excluded when the
# script is searching for files to optimize.
#
# Including or excluding a file the script cannot optimize is pointless.
#
# Lines starting with a + are inclusions, these files are always optimized.
# If Git features are enabled, these files will also be restaged if it makes
# sense to do so.
# Directories can *NOT* be included.
# Here are some examples:
# + ./resource/bar.png
# + ./important_sounds/noise.ogg
#
# Lines starting with a - are exclusions, these files are always ignored.
# Directories can be excluded as well.
# Here are some examples:
# - ./refs/character_sheet.png
# - ./template.png
# - ./unused_sound.ogg
# - ./useless_directory/

"@ >$CONFIG.config
  } catch {
    [Console]::Error.WriteLine("Could not write config to '$($CONFIG.config)'!")
    return 1
  }

  [Console]::Out.WriteLine("Generated new config file!")
  return 3
}) >$null

# /N
[OptHandler]::newOption("N", 0x01, $null, $null, {
  param([bool] $value)

  $CONFIG.nogit = $value
  return 0
}) >$null

# /O=LEVEL
[OptHandler]::newOption("O", 0x02, 1, 4, {
  param([bool] $value)

  $CONFIG.level = $value
  return 0
}) >$null

# /S
[OptHandler]::newOption("S", 0x01, $null, $null, {
  param([bool] $value)

  $CONFIG.sounds = $value
  return 0
}) >$null

# /T
[OptHandler]::newOption("T", 0x01, $null, $null, {
  param([bool] $value)

  $CONFIG.textures = $value
  return 0
}) >$null

# /V
[OptHandler]::newOption("V", 0x01, $null, $null, {
  param([bool] $value)

  $CONFIG.verbose = $value
  return 0
}) >$null

# /Y
[OptHandler]::newOption("Y", 0x01, $null, $null, {
  param([bool] $value)

  $CONFIG.yes = $value
  return 0
}) >$null


#======================================================|| MAIN ||======================================================#

[byte] $code = [OptHandler]::readArgs([string[]]$args)
if ($code -ne 0) {exit $code}

$script:args = [OptHandler]::POSITIONAL
debug "POSITIONAL ARGUMENTS: $($args -join " ")" >$null

if (-not (readConfig)) {exit 1}
if (-not (verifyPrograms)) {exit 2}

if ($args.Count -gt 0) {
  debug "Selecting files from positional arguments" >$null
  argFiles $args >$null
  $CONFIG.nogit = $true
} elseif ($CONFIG.nogit) {
  debug "Selecting files from current directory" >$null
  dirFiles >$null
} else {
  debug "Selecting files from Git repository" >$null
  gitFiles >$null
}
debug "Selected Files (Before CFG):`n$($FILE_selected -join "`n")" >$null

if (-not (applyCfgFileRules)) {exit 1}
debug "Selected Files (After CFG):`n$($FILE_selected -join "`n")" >$null

if ($FILE_selected.Count -le 0) {
  [Console]::Out.WriteLine("No files to optimize!")
  exit 0
}

if ($CONFIG.dry) {
  [Console]::Out.WriteLine(@"
  +--------------------------------------------------------------------------+
  |   (i)                   DRY RUNNING IS ENABLED.                    (i)   |
  | The commands that would have modified files will instead be printed and  |
  | the current Git commit will fail if this was run as a pre-commit hook!   |
  +--------------------------------------------------------------------------+

"@)
}

# Make backups if they are enabled
if ($CONFIG.backup) {
  debug "Starting backups..." >$null
  foreach ($file in $FILE_selected) {
    debug "Creating a backup of [$file] as [$file.bak]" >$null
    dry Copy-Item @{Force = [Switch]::Present; LiteralPath = $file; Destination = "$file.bak";}
    if ($LASTEXITCODE -ne 0) {
      [Console]::Error.WriteLine(@"
  +--------------------------------------------------------------------------+
  |   /!\       COULD NOT CREATE A BACKUP!                             /!\   |
  | Backups are enabled and a backup for a file could not be created. This   |
  | script will now stop to protect any files that were about to be changed. |
  +--------------------------------------------------------------------------+
"@)
      [Console]::Error.WriteLine(
        "Failed to write [$file.bak]`n" +
        "  with the contents of [$file]"
      )
      exit 1
    }
  }
}

# Optimize textures
if ($CONFIG.textures) {
  [Console]::Out.WriteLine("Optimizing texture files...")

  [List[string]] $FILE_png = [List[string]]::new()
  foreach ($file in $FILE_selected) {
    if ($file.EndsWith(".png")) {
      $FILE_png.Add($file)
    }
  }

  if ($FILE_png.Count -gt 0) {
    # Begin optimization
    [List[string]] $oxi_options = [List[string]]::new()
    if ($CONFIG.level -le 1) {
      $oxi_options.AddRange([string[]]@("-omax", "-s"))
    } elseif ($config.level -eq 2) {
      $oxi_options.AddRange([string[]]@("-omax", "-s", "-Z", "--fast"))
    } else{
      $oxi_options.AddRange([string[]]@("-omax", "-s", "-Z"))
    }

    debug "Optimizing files with options $($oxi_options -join " ")" >$null
    $oxi_options.Add("--")
    $oxi_options.AddRange($FILE_png)
    dry $OXIPNG $oxi_options

    if ($CONFIG.level -ge 4) {
      foreach ($file in $FILE_png) {
        dry $PNGOUT @("-y", $file)
      }
    }
  }
}

# Optimize sounds
if ($CONFIG.sounds) {
  [Console]::Out.WriteLine("Optimizing sound files...")

  [List[string]] $FILE_ogg = [List[string]]::new()
  foreach ($file in $FILE_selected) {
    if ($file.EndsWith(".ogg")) {
      $FILE_ogg.Add($file)
    }
  }

  foreach ($file in $FILE_ogg) {
    if (-not $CONFIG.dry) {[Console]::Out.WriteLine("Processing: $file")}
    [string] $optifile = "$($file -replace @('\.ogg$', '')).optivorbis.ogg"
    dry $OPTIVORBIS @("-q", $file, $optifile)
    dry Move-Item @{Force = [Switch]::Present; LiteralPath = $optifile; Destination = $file}
  }
}

# Re-stage all modified files.
if (-not $CONFIG.nogit) {
  debug "Re-staging files..." >$null
  $FILE_selected.InsertRange(0, [string[]]@("add", "--"))
  dry git $FILE_selected 2>$null
  if ($LASTEXITCODE -ge 128) {
    [Console]::Error.WriteLine(@"
  +--------------------------------------------------------------------------+
  |   /!\                   COULD NOT RESTAGE FILES!                   /!\   |
  | One of the optimzed files could not be restaged. This script will now    |
  | stop to avoid committing the wrong version of the optimized files.       |
  +--------------------------------------------------------------------------+
"@)
    [Console]::Error.WriteLine(
      "Failed to restage files. Did you attempt to`n" +
      "optimize a file outside of the Git repository?"
    )
    exit 1
  }
}

[Console]::Out.WriteLine("Optimization finished!")

if ($CONFIG.dry) {exit 3}
exit 0



########################################################################################################################
#####  LICENSE INFORMATION: OPTIFIGURA (THIS SCRIPT)  ##################################################################
########################################################################################################################

# MIT License
#
# Copyright (c) 2025 GrandpaScout
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.



########################################################################################################################
#####  LICENSE INFORMATION: OXIPNG  ####################################################################################
########################################################################################################################
# As this script uses the program in question, this is placed here to respect the license.

# The MIT License (MIT)
# Copyright (c) 2016 Joshua Holmer
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.



########################################################################################################################
#####  LICENSE INFORMATION: PNGOUT  ####################################################################################
########################################################################################################################
# As this script uses the program in question, this is placed here to respect the program's bundled usage terms.

# The software "PNGOUT" belongs to Ken Silverman.
# The software can be downloaded from https://advsys.net/ken/utils.htm
# The terms for bundled usage can be found at the website above.
# This script (the one running PNGOUT) is entirely free to use.



########################################################################################################################
#####  LICENSE INFORMATION: OPTIVORBIS  ################################################################################
########################################################################################################################
# As this script uses the program in question, this is placed here to respect the license.

# Copyright 2022 Alejandro González
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
