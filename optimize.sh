#!/usr/bin/env sh
: $optifigura

: || (
  @ECHO OFF & GOTO :Win
)
# ^ ^ ^ ^ ^ Ignore me ^ ^ ^ ^ ^

# <GrandpaScout>
# READ THE README FOR INSTRUCTIONS!
# RELEVANT LICENSES ARE PLACED AT THE BOTTOM OF THIS FILE!
#
# If you are looking for a list of command line options and what they do, use the `--help` option.
# If you want to generate a default config, use the `--gen-config` option.
#
# This file should not be edited by the end user (most likely you.)

SCRIPT_VERSION="1.0.3"


#===============================================|| DEPENDENCY CHECKS ||================================================#

verifyCommands_abort=false
for verifyCommands_cmdinfo in \
  "printf#handles text values in functions" \
  "cut#splits Git output" \
  "readlink#handles symbolic links" \
  "cp#creates backups of files" \
  "mv#applies OptiVorbis optimizations to the original file" \
  "eval#emulates array variables" \
  "find#finds files in subdirectories"
do
  verifyCommands_cmd="${verifyCommands_cmdinfo%%#*}"
  verifyCommands_desc="${verifyCommands_cmdinfo#*#}"
  if (! command -v "$verifyCommands_cmd" >/dev/null); then
    echo "Could not find required command \`$verifyCommands_cmd\`." >&2
    echo " ($verifyCommands_desc)" >&2
    verifyCommands_abort=true
  fi
done

if $verifyCommands_abort; then exit 2; fi


#================================================|| OPTION HANDLING ||=================================================#

# Escapes specific characters that don't play well in evaluated strings.
#
# ===== PARAMETERS =====
# $1 (String):
#   The string to escape.
#
# ====== RETURNS =======
# Status:
#   0 = Success
#
# Stdout:
#   The escaped string.
OptHandler_stringEscape() {
  OptHandler_unescaped="$1"
  OptHandler_escaped=""
  while true; do
    case $OptHandler_unescaped in
      *\\*)
        OptHandler_escaped="$OptHandler_escaped${OptHandler_unescaped%%\\*}\\\\"
        OptHandler_unescaped="${OptHandler_unescaped#*\\}"
        ;;
      *)
        break;;
    esac
  done

  OptHandler_unescaped="$OptHandler_escaped$OptHandler_unescaped"
  OptHandler_escaped=""
  while true; do
    case $OptHandler_unescaped in
      *\"*)
        OptHandler_escaped="$OptHandler_escaped${OptHandler_unescaped%%\"*}\\\""
        OptHandler_unescaped="${OptHandler_unescaped#*\"}"
        ;;
      *)
        break;;
    esac
  done

  OptHandler_unescaped="$OptHandler_escaped$OptHandler_unescaped"
  OptHandler_escaped=""
  while true; do
    case $OptHandler_unescaped in
      *\$*)
        OptHandler_escaped="$OptHandler_escaped${OptHandler_unescaped%%\$*}\\\$"
        OptHandler_unescaped="${OptHandler_unescaped#*\$}"
        ;;
      *)
        break;;
    esac
  done

  printf "%s" "$OptHandler_escaped$OptHandler_unescaped"
  return 0
}

# Checks the name of an option to see if it is valid.
#
# ===== PARAMETERS =====
# $1 (Option name):
#   The name of the option to check.
#
# ====== RETURNS =======
# Status:
#   0 = Success
#   1 = Failure
#
# Stderr:
#   The reason the name is not valid.
OptHandler_checkName() {
  if [ "$1" = "" ]; then
    echo "[OptHandler] option name cannot be empty -- " >&2
    return 1
  fi

  if [ "$1" = "-" ]; then
    echo "[OptHandler] option name cannot be \"-\" -- -" >&2
    return 1
  fi

  case "$1" in
    *[!A-Za-z0-9_-]*)
      echo "[OptHandler] option name can only contain A-Z, a-z, 0-9, -, and _ -- $1" >&2
      return 1;;
  esac

  return 0
}

# Checks if an option with the given name exists.
#
# ===== PARAMETERS =====
# $1 (Option name):
#   The name to check.
#
# $2 (Option type):
#   The type of option to check for. One of: `"SHORT"` or `"LONG"`.
#
# ====== RETURNS =======
# Status:
#   0 = An option with the name exists.
#   1 = An option with the name does not exist.
OptHandler_checkExists() {
  if [ "$2" ]; then
    if
      { [ "$2" = "SHORT" ] && [ "${OptHandler_SHORT_OPTIONS#*"=$1="}" != "$OptHandler_SHORT_OPTIONS" ]; } ||
      { [ "$2" = "LONG" ] && [ "${OptHandler_LONG_OPTIONS#*"=$1="}" != "$OptHandler_LONG_OPTIONS" ]; }
    then
      return 0
    fi

    return 1
  fi

  if
    [ "${OptHandler_DEFINED_OPTIONS#*"=$1="}" != "$OptHandler_DEFINED_OPTIONS" ] ||
    [ "${OptHandler_LONG_OPTIONS#*"=$1="}" != "$OptHandler_LONG_OPTIONS" ] ||
    [ "${OptHandler_SHORT_OPTIONS#*"=$1="}" != "$OptHandler_SHORT_OPTIONS" ]
  then
    return 0
  fi

  return 1
}

# Gets the ID of the option with the given name if one exists.
#
# ===== PARAMETERS =====
# $1 (Option name):
#   The name to get the ID of.
#
# $2 (Option type):
#   The type of option to get the ID of. One of: `"SHORT"` or `"LONG"`.
#
# ====== RETURNS =======
# Status:
#   0 = An option with the name exists.
#   1 = An option with the name does not exist.
#
# Stdout:
#   The ID of the option.
OptHandler_getOptionID() {
  if ! OptHandler_checkExists "$1" "$2"; then return 1; fi

  OptHandler_optid=0
  while [ $OptHandler_optid -lt $OptHandler_NUM_OPTIONS ]; do
    if eval "
      [ \"\$OptHandler_OPTION_NAME_$OptHandler_optid\" = \"$1\" ] ||
      [ \"\$OptHandler_OPTION_ALIAS_$OptHandler_optid\" = \"$1\" ]
    " 2>/dev/null; then
      printf "%s" "$OptHandler_optid"
      return 0
    fi
    OptHandler_optid=$((OptHandler_optid + 1))
  done

  return 1
}

# Changes the name error messages will refer to this script as. Defaults to the basename of the script.
#
# ===== PARAMETERS =====
# $1 (Script name):
#   The new name of this script.
#
# ====== RETURNS =======
# Status:
#   Always 0.
OptHandler_SCRIPT_NAME="${0##*/}"
OptHandler_setScriptName() {
  OptHandler_SCRIPT_NAME="$1"
  return 0
}

# Changes the text printed by the `--version` option.
#
# ===== PARAMETERS =====
# $1 (Version text):
#   The new version text of this script.
#
# ====== RETURNS =======
# Status:
#   Always 0.
OptHandler_SCRIPT_VERSION="1.0.0"
OptHandler_setScriptVersion() {
  OptHandler_SCRIPT_VERSION="$1"
  return 0
}

# Creates a new option for use in the command line.
#
# ===== PARAMETERS =====
# $1 (Option Name):
#   The name of the option.
#   If this is more than one character long, a short alias can be defined in the next parameter.
#
# $2 (Short Alias):
#   Only valid if `Option Name` is not a single letter. Use a blank string `""` to define no short alias.
#
# $3 (Option Mode):
#   Can be provided as a standard decimal number or a prefixed hexadecimal number with two digits. (`29` or `0x1D`.)
#   ---- -000: Switch      (Does not accept a value, its existance is enough to trigger it.)
#   ---- -001: Flag        (AKA: Boolean. Accepts either boolean value. Shortcuts: `-x` = "-x=true", `+x` = "-x=false")
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
# $4 (Extra 1):
#   An extra value if an Option Mode needs it.
#     Integer: The minimum allowed value. If this is `""` then there is no minimum.
#     Float: The minimum allowed value. If this is `""` then there is no minimum.
#     Enum: A string containing the list of enums. The separator character is defined in Extra 2.
#
# $5 (Extra 2):
#   Another extra value if an Option Mode needs it.
#     Integer: The maximum allowed value. If this is `""` then there is no maximum.
#     Float: The maximum allowed value. If this is `""` then there is no maximum.
#     Enum: A string the singular separator character for splitting the enum list in Extra 1.
#
# $6 (Callback function):
#   The name of the function to call every time this option is provided.
#   The callback is executed as: `callback "$VALUE" "$OPTION_NAME" "$OPTION_MODE" "$EXTRA_1" "$EXTRA 2"`
#     `$VALUE` is the value provided to the option.
#     `$OPTION_NAME` is the name used to trigger the option. (This is the Short Alias if that was used.)
#     `$OPTION_MODE` is the Option Mode defined for this option.
#     `$EXTRA_1` is the Extra 1 defined for this option.
#     `$EXTRA_2` is the Extra 2 defined for this option.
#     The callback is expected to return an exit code.
#     0 is a success, anything else is a failure.
#
#   WIP: This function is called when help information is needed.
#   The callback is executed as: `callback "?" "$OPTION_NAME" "HELP"`
#     The `"?"` string is literal.
#     `$OPTION_NAME` is the name used to define the option.
#     The `"HELP"` string is literal.
#     The callback is expected to print the help string to stdout.
#
#   WIP: This function is called when the name of an argument is needed.
#   The callback is executed as: `callback "?" "$OPTION_NAME" "ARGNAME"`
#     The `"?"` string is literal.
#     `$OPTION_NAME` is the name used to define the option.
#     The `"ARGNAME"` string is literal.
#     The callback is expected to print the name of the argument to stdout.
#     If an argument name is not printed (or an empty string is printed) the
#     default name of "VALUE" will be used. If the command is a Flag command,
#     this will instead hide the value in the help text.
#
# ====== RETURNS =======
# Status:
#   0 = Success
#   1 = Failure
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_DEFINED_OPTIONS="="
OptHandler_LONG_OPTIONS="="
OptHandler_SHORT_OPTIONS="="
OptHandler_NUM_OPTIONS=0
OptHandler_newOption() {
  if [ "$2" ] && [ "${#1}" -eq 1 ]; then
    echo "[OptHandler] option name must be longer than one character -- $1" >&2
    return 1
  fi
  if ! OptHandler_checkName "$1"; then return 1; fi
  if [ "$2" ]; then
    if [ "${#2}" -ne 1 ]; then
      echo "[OptHandler] option short alias must be one character long -- $1" >&2
      return 1
    fi
    if ! OptHandler_checkName "$2"; then return 1; fi
  fi

  if OptHandler_checkExists "$1"; then
    echo "[OptHandler] option is already defined -- $1" >&2
    return 1
  fi
  if [ "$2" ] && OptHandler_checkExists "$2"; then
    echo "[OptHandler] option short alias is already defined -- $1" >&2
    return 1
  fi

  OptHandler_DEFINED_OPTIONS="$OptHandler_DEFINED_OPTIONS$1="

  OptHandler_modeint="$(($3))"

  eval "
    OptHandler_OPTION_NAME_$OptHandler_NUM_OPTIONS=\"\$1\"
    OptHandler_OPTION_ALIAS_$OptHandler_NUM_OPTIONS=\"\"
    OptHandler_OPTION_EXISTS_$OptHandler_NUM_OPTIONS=true
    OptHandler_OPTION_MODE_$OptHandler_NUM_OPTIONS=\"\$OptHandler_modeint\"
    OptHandler_OPTION_EXTRA1_$OptHandler_NUM_OPTIONS=\"\$4\"
    OptHandler_OPTION_EXTRA2_$OptHandler_NUM_OPTIONS=\"\$5\"
    OptHandler_OPTION_CALLBACK_$OptHandler_NUM_OPTIONS=\"\$6\"
    OptHandler_OPTION_HANDLED_$OptHandler_NUM_OPTIONS=0
  "

  if [ "$2" ]; then
    OptHandler_LONG_OPTIONS="$OptHandler_LONG_OPTIONS$1="
    OptHandler_SHORT_OPTIONS="$OptHandler_SHORT_OPTIONS$2="

    eval "
      OptHandler_OPTION_ALIAS_$OptHandler_NUM_OPTIONS=\"\$2\"
    "
  elif [ "${#1}" -le 1 ]; then
    OptHandler_SHORT_OPTIONS="$OptHandler_SHORT_OPTIONS$1="
  else
    OptHandler_LONG_OPTIONS="$OptHandler_LONG_OPTIONS$1="
  fi

  OptHandler_NUM_OPTIONS=$((OptHandler_NUM_OPTIONS + 1))
  return 0
}

# When provided with a list of arguments, this will read through all of them to determine which are actual options and
# which are standard arguments.
#
# ===== PARAMETERS =====
# $* (Args):
#   The arguments to read.
#
# ====== RETURNS =======
# Status:
#   0 = Success
#   1 = Failure
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_readArgs() {
  OptHandler_POSITIONAL=""
  while [ $# -gt 0 ]; do
    if [ "${1#"--"}" != "$1" ]; then # Full --option
      if [ "$1" = "--" ]; then
        shift
        break
      fi

      OptHandler_handleLongOption "$1" "$2"
      case $? in
        1) return 1;;
        2) shift;;
      esac
    elif [ "${1#"-"}" != "$1" ]; then # Short -o
      if ! OptHandler_handleShortOptions "$1" "$2"; then
        if [ $? -eq 2 ]; then
          shift
        else
          return 1
        fi
      fi
    elif [ "${1#"+"}" != "$1" ]; then # Negative Flag +o
      if ! OptHandler_handleNFlagOptions "$1"; then return 1; fi
    else
      OptHandler_POSITIONAL="$OptHandler_POSITIONAL \"$(OptHandler_stringEscape "$1")\""
    fi

    shift
  done

  while [ $# -gt 0 ]; do
    OptHandler_POSITIONAL="$OptHandler_POSITIONAL \"$(OptHandler_stringEscape "$1")\""
    shift
  done

  OptHandler_currentoptid=0
  while [ $OptHandler_currentoptid -lt $OptHandler_NUM_OPTIONS ]; do
    if [ "$(OptHandler_getValue "$OptHandler_currentoptid" "HANDLED")" -le 0 ]; then
      OptHandler_currentoptmode="$(($(OptHandler_getValue "$OptHandler_currentoptid" "MODE") >> 3))"

      # Required flag
      if [ "$(($(OptHandler_getValue "$OptHandler_currentoptid" "MODE") & 0x08))" -ne 0 ]; then
        echo "$OptHandler_SCRIPT_NAME: option is required -- $(OptHandler_getValue "$OptHandler_currentoptid" "NAME")" >&2
        return 1
      fi
    fi

    OptHandler_currentoptid="$((OptHandler_currentoptid + 1))"
  done

  OptHandler_currentoptpos=0
  while [ $OptHandler_currentoptpos -lt $OptHandler_NUM_HANDLED ]; do
    eval "
      OptHandler_currentoptcallback=\"\$OptHandler_HANDLED_CALLBACK_$OptHandler_currentoptpos\"
      OptHandler_currentoptname=\"\$OptHandler_HANDLED_NAME_$OptHandler_currentoptpos\"
      OptHandler_currentoptvalue=\"\$OptHandler_HANDLED_VALUE_$OptHandler_currentoptpos\"
    "
    if [ -z "$OptHandler_currentoptcallback" ]; then continue; fi

    OptHandler_currentoptid="$(OptHandler_getOptionID "$OptHandler_currentoptname")"
    OptHandler_currentoptmode="$(OptHandler_getValue "$OptHandler_currentoptid" "MODE")"
    OptHandler_currentoptextra1="$(OptHandler_getValue "$OptHandler_currentoptid" "EXTRA1")"
    OptHandler_currentoptextra2="$(OptHandler_getValue "$OptHandler_currentoptid" "EXTRA2")"

    $OptHandler_currentoptcallback "$OptHandler_currentoptvalue" "$OptHandler_currentoptname" "$OptHandler_currentoptmode" "$OptHandler_currentoptextra1" "$OptHandler_currentoptextra2"
    OptHandler_callbackstatus=$?
    if [ $OptHandler_callbackstatus -ne 0 ]; then return $OptHandler_callbackstatus; fi

    OptHandler_currentoptpos="$((OptHandler_currentoptpos + 1))"
  done

  return 0
}

# Gets a value from an option definition.
#
# ===== PARAMETERS =====
# $1 (Option ID):
#   The ID of the option to read.
#
# $2 (Value Type):
#   The type of value to get.
#     One of: `"NAME"`, `"ALIAS"`, `"EXISTS"`, `"MODE"`, `"EXTRA1"`, `"EXTRA2"`, `"CALLBACK"`, or `"HANDLED"`.
#
# ====== RETURNS =======
# Status:
#   0 = Value of that type exists.
#   1 = Value of that type does not exist or option with that id does not exist.
#
# Stdout:
#   The value.
OptHandler_getValue() {
  if [ "$1" -ge "$OptHandler_NUM_OPTIONS" ]; then return 1; fi

  case "$2" in
    "NAME"|"ALIAS"|"EXISTS"|"MODE"|"EXTRA1"|"EXTRA2"|"CALLBACK"|"HANDLED")
      # This is the kinda shit you pull if you don't have access to arrays or maps.
      eval "printf \"%s\" \"\$OptHandler_OPTION_${2}_$1\""
      ;;

    *)
      return 1;;
  esac

  return 0
}

# Sets a value for an option definition.
#
# ===== PARAMETERS =====
# $1 (Option ID):
#   The ID of the option to modify.
#
# $2 (Value Type):
#   The type of value to set.
#     One of: `"NAME"`, `"ALIAS"`, `"EXISTS"`, `"MODE"`, `"EXTRA1"`, `"EXTRA2"`, `"CALLBACK"`, or `"HANDLED"`.
#
# $3 (Value):
#   The value to set.
#
# ====== RETURNS =======
# Status:
#   0 = Success.
#   1 = Failure.
OptHandler_setValue() {
  if [ "$1" -ge "$OptHandler_NUM_OPTIONS" ]; then return 1; fi

  case "$2" in
    "NAME"|"ALIAS"|"EXISTS"|"MODE"|"EXTRA1"|"EXTRA2"|"CALLBACK"|"HANDLED")
      # This is the kinda shit you pull if you don't have access to arrays or maps.
      eval "OptHandler_OPTION_${2}_$1=\"$(OptHandler_stringEscape "$3")\""
      ;;

    *)
      return 1;;
  esac

  return 0
}

# Checks if an option requires a value to function.
#
# ===== PARAMETERS =====
# $1 (Option ID):
#   The ID of the option to check.
#
# ====== RETURNS =======
# Status:
#   0 = Requires a value.
#   1 = Does not require a value.
OptHandler_needsValue() {
  if [ "$(($(OptHandler_getValue "$1" "MODE") % 8))" -ge 2 ]; then return 0; fi
  return 1
}

# Attempts to coerce a string into a boolean value.
#
# ===== PARAMETERS =====
# $1 (Option Name):
#   The name of the option for error messages.
#
# $2 (String):
#   The string to coerce.
#
# ====== RETURNS =======
# Status:
#   0 = Success.
#   1 = Failure.
#
# Stdout:
#   The resulting boolean value as a string.
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_checkBoolean() {
  case "$2" in
    "t"|"T"|"true"|"True"|"TRUE"|"y"|"Y"|"yes"|"Yes"|"YES"|"on"|"On"|"ON")
      printf "%s" "true"
      ;;

    "f"|"F"|"false"|"False"|"FALSE"|"n"|"N"|"no"|"No"|"NO"|"off"|"Off"|"OFF")
      printf "%s" "false"
      ;;

    *)
      echo "$OptHandler_SCRIPT_NAME: option expects boolean value -- $1" >&2
      return 1;;
  esac

  return 0
}

# Attempts to coerce a string into an integer value.
#
# ===== PARAMETERS =====
# $1 (Option Name):
#   The name of the option for error messages.
#
# $2 (String):
#   The string to coerce.
#
# $3 (Minimum):
#   The minimum allowed value.
#   This is "" if no minimum is specified.
#
# $4 (Maximum):
#   The maximum allowed value.
#   This is "" if no maximum is specified.
#
# ====== RETURNS =======
# Status:
#   0 = Success.
#   1 = Failure.
#
# Stdout:
#   The resulting integer value as a string.
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_checkInteger() {
  OptHandler_negative=false
  OptHandler_integer="${2#"${2%%[! ]*}"}"
  OptHandler_integer="${OptHandler_integer%"${OptHandler_integer##*[! ]}"}"

  if [ "${OptHandler_integer#-}" != "$OptHandler_integer" ]; then
    OptHandler_negative=true
    OptHandler_integer="${OptHandler_integer#-}"
  else
    OptHandler_integer="${OptHandler_integer#+}"
  fi

  if [ "${OptHandler_integer#0[Xx]}" != "$OptHandler_integer" ]; then
    OptHandler_integer="${OptHandler_integer#0[Xx]}"
    if [ "${OptHandler_integer#*[!0-9A-Fa-f]}" != "${OptHandler_integer}" ]; then
      echo "$OptHandler_SCRIPT_NAME: option expects integer value -- $1" >&2
      return 1
    fi

    OptHandler_integer="$(printf "%d" "0x$OptHandler_integer" 2>/dev/null)"
  elif [ "${OptHandler_integer#*[!0-9]}" != "$OptHandler_integer" ]; then
    echo "$OptHandler_SCRIPT_NAME: option expects integer value -- $1" >&2
    return 1
  fi

  if $OptHandler_negative; then OptHandler_integer="-$OptHandler_integer"; fi

  if [ "$3" ] && [ "$OptHandler_integer" -lt "$3" ]; then
    echo "$OptHandler_SCRIPT_NAME: option received integer value below the minimum of $3 -- $1" >&2
    return 1
  elif [ "$4" ] && [ "$OptHandler_integer" -gt "$4" ]; then
    echo "$OptHandler_SCRIPT_NAME: option received integer value above the maximum of $4 -- $1" >&2
    return 1
  fi

  printf "%d" "$OptHandler_integer"
  return 0
}

# Attempts to coerce a string into a number value.
#
# ===== PARAMETERS =====
# $1 (Option Name):
#   The name of the option for error messages.
#
# $2 (String):
#   The string to coerce.
#
# $3 (Minimum):
#   The minimum allowed value.
#   This is "" if no minimum is specified.
#
# $4 (Maximum):
#   The maximum allowed value.
#   This is "" if no maximum is specified.
#
# ====== RETURNS =======
# Status:
#   0 = Success.
#   1 = Failure.
#
# Stdout:
#   The resulting number value as a string.
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_checkNumber() {
  OptHandler_negative=false
  OptHandler_number="${2#"${2%%[! ]*}"}"
  OptHandler_number="${OptHandler_number%"${OptHandler_number##*[! ]}"}"

  if [ "${OptHandler_number#-}" != "$OptHandler_number" ]; then
    OptHandler_negative=true
    OptHandler_number="${OptHandler_number#-}"
  else
    OptHandler_number="${OptHandler_number#+}"
  fi

  if [ "${OptHandler_number#*.}" = "$OptHandler_number" ]; then
    if [ "${OptHandler_integer#*[!0-9]}" != "$OptHandler_integer" ]; then
      echo "$OptHandler_SCRIPT_NAME: option expects number value -- $1" >&2
      return 1
    fi

    OptHandler_integral="$OptHandler_number"
    OptHandler_fractional="0"
  else
    OptHandler_integral="${OptHandler_number%%.*}"
    OptHandler_fractional="${OptHandler_number#*.}"

    if
      [ "${OptHandler_integral#*[!0-9]}" != "$OptHandler_integral" ] ||
      [ "${OptHandler_fractional#*[!0-9]}" != "$OptHandler_fractional" ]
    then
      echo "$OptHandler_SCRIPT_NAME: option expects number value -- $1" >&2
      return 1
    fi

    if [ -z "$OptHandler_integral" ]; then OptHandler_integral="0"; fi
    if [ -z "$OptHandler_fractional" ]; then OptHandler_fractional="0"; fi
  fi

  OptHandler_fractionalsize="${#OptHandler_fractional}"
  if $OptHandler_negative; then
    OptHandler_integral="-$OptHandler_integral"
    OptHandler_fractional="-$OptHandler_fractional"
  fi

  if [ "$3" ]; then
    OptHandler_minneg=false
    if [ "${3#-}" != "$3" ]; then
      OptHandler_minneg=true
      OptHandler_minint="${3#-}"
    else
      OptHandler_minint="${3#+}"
    fi

    if [ "${3#*.}" = "$3" ]; then
      OptHandler_minint="$3"
      OptHandler_minfrac="0"
    else
      OptHandler_minint="${OptHandler_minint%%.*}"
      OptHandler_minfrac="${3#*.}"
      if [ -z "$OptHandler_minint" ]; then OptHandler_minint="0"; fi
      if [ -z "$OptHandler_minfrac" ]; then OptHandler_minfrac="0"; fi
    fi

    OptHandler_minfracsize="${#OptHandler_minfrac}"

    if $OptHandler_minneg; then
      OptHandler_minint="-$OptHandler_minint"
      OptHandler_minfrac="-$OptHandler_minfrac"
    fi

    if [ "$OptHandler_integral" -lt "$OptHandler_minint" ]; then
      echo "$OptHandler_SCRIPT_NAME: option received number value below the minimum of $3 -- $1" >&2
      return 1
    elif [ "$OptHandler_integral" -eq "$OptHandler_minint" ]; then
      if [ $OptHandler_minfracsize -gt $OptHandler_fractionalsize ]; then
        OptHandler_fracsize="$OptHandler_minfracsize"
      else
        OptHandler_fracsize="$OptHandler_fractionalsize"
      fi

      if [ \
        "$(printf "%s%0*s" "$OptHandler_fractional" "$(($OptHandler_fractionalsize - $OptHandler_fracsize))" "")" -lt \
        "$(printf "%s%0*s" "$OptHandler_minfrac" "$(($OptHandler_minfracsize - $OptHandler_fracsize))" "")" \
      ]; then
        echo "$OptHandler_SCRIPT_NAME: option received number value below the minimum of $3 -- $1" >&2
        return 1
      fi
    fi
  fi

  if [ "$4" ]; then
    OptHandler_maxneg=false
    if [ "${4#-}" != "$4" ]; then
      OptHandler_maxneg=true
      OptHandler_maxint="${4#-}"
    else
      OptHandler_maxint="${4#+}"
    fi

    if [ "${4#*.}" = "$4" ]; then
      OptHandler_maxint="$4"
      OptHandler_maxfrac="0"
    else
      OptHandler_maxint="${OptHandler_maxint%%.*}"
      OptHandler_maxfrac="${4#*.}"
      if [ -z "$OptHandler_maxint" ]; then OptHandler_maxint="0"; fi
      if [ -z "$OptHandler_maxfrac" ]; then OptHandler_maxfrac="0"; fi
    fi

    OptHandler_maxfracsize="${#OptHandler_maxfrac}"

    if $OptHandler_maxneg; then
      OptHandler_maxint="-$OptHandler_maxint"
      OptHandler_maxfrac="-$OptHandler_maxfrac"
    fi

    if [ "$OptHandler_integral" -lt "$OptHandler_maxint" ]; then
      echo "$OptHandler_SCRIPT_NAME: option received number value above the maximum of $4 -- $1" >&2
      return 1
    elif [ "$OptHandler_integral" -eq "$OptHandler_maxint" ]; then
      if [ $OptHandler_maxfracsize -gt $OptHandler_fractionalsize ]; then
        OptHandler_fracsize="$OptHandler_maxfracsize"
      else
        OptHandler_fracsize="$OptHandler_fractionalsize"
      fi

      if [ \
        "$(printf "%s%0*s" "$OptHandler_fractional" "$(($OptHandler_fractionalsize - $OptHandler_fracsize))" "")" -lt \
        "$(printf "%s%0*s" "$OptHandler_maxfrac" "$(($OptHandler_maxfracsize - $OptHandler_fracsize))" "")" \
      ]; then
        echo "$OptHandler_SCRIPT_NAME: option received number value above the maximum of $4 -- $1" >&2
        return 1
      fi
    fi
  fi

  printf "%d.%d" "$OptHandler_integral" "${OptHandler_fractional#-}"
  return 0
}

OptHandler_checkEnum() {
  # WIP: Finish this
  :
}

# Prepares an option to be run later.
#
# ===== PARAMETERS =====
# $1 (Option Name):
#   The name of the option to prepare.
#
# $2 (Option Value):
#   The value being passed into the option, if any.
#   THIS SHOULD ONLY BE PROVIDED IF IT EXISTS.
#
# ====== RETURNS =======
# Status:
#   0 = Success
#   1 = Failure
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_NUM_HANDLED=0
OptHandler_handleOption() {
  OptHandler_currentoptid="$(OptHandler_getOptionID "$1")"
  OptHandler_currentoptmode="$(OptHandler_getValue "$OptHandler_currentoptid" "MODE")"
  OptHandler_currentopttype="$((OptHandler_currentoptmode % 8))"
  OptHandler_currentoptmrep="$((OptHandler_currentoptmode >> 4))"
  OptHandler_currentoptcrep="$(OptHandler_getValue "$OptHandler_currentoptid" "HANDLED")"

  if [ $OptHandler_currentoptmrep -lt 15 ] && [ $OptHandler_currentoptcrep -gt $OptHandler_currentoptmrep ]; then
    if [ $OptHandler_currentoptmrep -eq 0 ]; then
      echo "$OptHandler_SCRIPT_NAME: option cannot be repeated -- $1" >&2
    else
      echo "$OptHandler_SCRIPT_NAME: option cannot be repeated more than $((OptHandler_currentoptmrep + 1)) times -- $1" >&2
    fi
    return 1
  fi

  OptHandler_currentoptvalue="$2"

  case "$OptHandler_currentopttype" in
    "0")
      if [ $# -gt 1 ]; then
        echo "$OptHandler_SCRIPT_NAME: switch option cannot take a value -- $1"
        return 1
      fi
      ;;

    "1")
      if [ $# -le 1 ]; then
        OptHandler_currentoptvalue="true"
      else
        OptHandler_currentoptvalue="$(OptHandler_checkBoolean "$1" "$2")"
      fi
      ;;

    "2")
      if [ $# -le 1 ]; then
        echo "$OptHandler_SCRIPT_NAME: option requires an argument -- $1" >&2
        return 1
      fi
      OptHandler_currentoptvalue="$(OptHandler_checkInteger "$1" "$2")"
      ;;

    "3")
      if [ $# -le 1 ]; then
        echo "$OptHandler_SCRIPT_NAME: option requires an argument -- $1" >&2
        return 1
      fi
      OptHandler_currentoptvalue="$(OptHandler_checkNumber "$1" "$2")"
      ;;

    "4")
      if [ $# -le 1 ]; then
        echo "$OptHandler_SCRIPT_NAME: option requires an argument -- $1" >&2
        return 1
      fi
      ;;

    "5")
      if [ $# -le 1 ]; then
        echo "$OptHandler_SCRIPT_NAME: option requires an argument -- $1" >&2
        return 1
      fi
      OptHandler_currentoptvalue="$(OptHandler_checkEnum "$1" "$2")"
      ;;
  esac

  eval "
    OptHandler_HANDLED_CALLBACK_$OptHandler_NUM_HANDLED=\"\$(OptHandler_getValue \"\$OptHandler_currentoptid\" \"CALLBACK\")\"
    OptHandler_HANDLED_NAME_$OptHandler_NUM_HANDLED=\"$1\"
    OptHandler_HANDLED_VALUE_$OptHandler_NUM_HANDLED=\"\$OptHandler_currentoptvalue\"
  "

  OptHandler_NUM_HANDLED="$((OptHandler_NUM_HANDLED + 1))"
  OptHandler_setValue "$OptHandler_currentoptid" "HANDLED" "$((OptHandler_currentoptcrep + 1))"

  return 0
}

# Handles a single long option.
#
# ===== PARAMETERS =====
# $1 (Option):
#   The argument containing the option to handle.
#
# $2 (Extra Arg):
#   An extra argument just in case the option needs it.
#   THIS SHOULD ONLY BE PROVIDED IF IT EXISTS.
#
# ====== RETURNS =======
# Status:
#   0 = Success
#   1 = Failure
#   2 = Success, shift argument list.
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_handleLongOption() {
  OptHandler_currentoptname="${1#"--"}"
  OptHandler_currentoptname="${OptHandler_currentoptname%%=*}"
  if ! OptHandler_optid="$(OptHandler_getOptionID "$OptHandler_currentoptname" "LONG")"; then
    echo "$OptHandler_SCRIPT_NAME: unknown option -- $OptHandler_currentoptname"
    return 1
  fi

  if [ "${1%%=*}" != "$1" ]; then
    if ! OptHandler_handleOption "$OptHandler_currentoptname" "${1#*=}"; then return 1; fi
  elif [ $# -gt 1 ] && OptHandler_needsValue "$OptHandler_optid"; then
    if ! OptHandler_handleOption "$OptHandler_currentoptname" "$2"; then return 1; fi
    return 2
  elif ! OptHandler_handleOption "$OptHandler_currentoptname"; then
    return 1
  fi

  return 0
}

# Handles multiple connected short options.
#
# ===== PARAMETERS =====
# $1 (Options):
#   The argument containing the options to handle.
#
# $2 (Extra Arg):
#   An extra argument just in case the last option needs it.
#   THIS SHOULD ONLY BE PROVIDED IF IT EXISTS.
#
# ====== RETURNS =======
# Status:
#   0 = Success
#   1 = Failure
#   2 = Success, shift argument list.
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_handleShortOptions() {
  OptHandler_currentoptnames="${1#"-"}"
  OptHandler_currentoptnames="${OptHandler_currentoptnames%%=*}"

  while [ "${#OptHandler_currentoptnames}" -gt 0 ]; do
    OptHandler_currentoptname="${OptHandler_currentoptnames%%${OptHandler_currentoptnames#?}}"
    OptHandler_currentoptnames="${OptHandler_currentoptnames#?}"
    if ! OptHandler_optid="$(OptHandler_getOptionID "$OptHandler_currentoptname" "SHORT")"; then
      echo "$OptHandler_SCRIPT_NAME: unknown option -- $OptHandler_currentoptname"
      return 1
    fi

    if [ "${#OptHandler_currentoptnames}" -le 0 ]; then
      # Checks specific to the last option in the group.
      if [ "${1%%=*}" != "$1" ]; then
        if ! OptHandler_handleOption "$OptHandler_currentoptname" "${1#*=}"; then return 1; fi
        return 0
      elif [ $# -gt 1 ] && OptHandler_needsValue "$OptHandler_optid"; then
        if ! OptHandler_handleOption "$OptHandler_currentoptname" "$2"; then return 1; fi
        return 2
      fi
    elif OptHandler_needsValue "$OptHandler_optid"; then
      # Checks specific to any option that is not the last that requires a value.
      OptHandler_handleOption "$OptHandler_currentoptname" "$OptHandler_currentoptnames${1#"${1%=*}"}"
      return $?
    fi

    if ! OptHandler_handleOption "$OptHandler_currentoptname"; then return 1; fi
  done

  return 0
}

# Handles multiple connected negative flag options.
#
# ===== PARAMETERS =====
# $1 (Options):
#   The argument containing the options to handle.
#
# ====== RETURNS =======
# Status:
#   0 = Success
#   1 = Failure
#
# Stderr:
#   The error message if a failure occurred.
OptHandler_handleNFlagOptions() {
  OptHandler_currentoptnames="${1#"+"}"
  OptHandler_currentoptnames="${OptHandler_currentoptnames%%=*}"

  while [ "${#OptHandler_currentoptnames}" -gt 0 ]; do
    OptHandler_currentoptname="${OptHandler_currentoptnames%%${OptHandler_currentoptnames#?}}"
    OptHandler_currentoptnames="${OptHandler_currentoptnames#?}"
    if ! OptHandler_optid="$(OptHandler_getOptionID "$OptHandler_currentoptname" "SHORT")"; then
      echo "$OptHandler_SCRIPT_NAME: unknown option -- $OptHandler_currentoptname"
      return 1
    fi

    if [ "$(($(OptHandler_getValue "$OptHandler_optid" "MODE") % 8))" -ne 1 ]; then
      echo "$OptHandler_SCRIPT_NAME: option cannot be unset as it is not a flag -- $OptHandler_currentoptname"
    fi

    # Checks specific to the last option in the group.
    if [ "${#OptHandler_currentoptnames}" -le 0 ] && [ "${1%%=*}" != "$1" ]; then
      echo "$OptHandler_SCRIPT_NAME: option cannot accept value while being unset -- $OptHandler_currentoptname" >&2
      return 1
    fi

    if ! OptHandler_handleOption "$OptHandler_currentoptname" false; then return 1; fi
  done

  return 0
}

# OptHandler_newOption "help" "" 0 "" "" OptHandler_optionhelp
# OptHandler_optionhelp() {
#   OptHandler_currenthelpid=0
#   OptHandler_hasshort=false
#   OptHandler_helpleft=13
#   while [ $OptHandler_currenthelpid -lt $OptHandler_NUM_OPTIONS ]; do
#     OptHandler_currenthelplong="$(OptHandler_getValue $OptHandler_currenthelpid "NAME")"
#     if [ "$OptHandler_currenthelplong" = "help" ] || [ "$OptHandler_currenthelplong" = "version" ]; then continue; fi
#     OptHandler_currenthelpshort="$(OptHandler_getValue $OptHandler_currenthelpid "ALIAS")"
# 
#     if [ ! "$OptHandler_currenthelpshort" ] && [ "${#OptHandler_currenthelplong}" -eq 1 ]; then
#       OptHandler_currenthelpshort="$OptHandler_currenthelplong"
#       OptHandler_currenthelplong=""
#     fi
# 
#     OptHandler_currenthelpleft=0
#     if [ "$OptHandler_currenthelplong" ]; then
#       OptHandler_haslong=true
#       if [ "$OptHandler_currenthelpshort" ]; then
#         OptHandler_hasshort=true
#         OptHandler_currenthelpleft="$(( 8 +  ))"
#       fi
#     fi
#   done
#
#   exit 0
# }


#===================================================|| VARIABLES ||====================================================#

T="$(printf "\t")"
N="
"

# Config Options.
unset -v CONFIG_textures
unset -v CONFIG_level
unset -v CONFIG_sounds
unset -v CONFIG_backup
unset -v CONFIG_nogit
unset -v CONFIG_verbose
unset -v CONFIG_dry

CONFIG_config="./.opticonfig"
CONFIG_yes=false
if [ -t 0 ]; then CONFIG_yes=true; fi

FILE_selected=""
FILE_cfgrules=""


#===================================================|| FUNCTIONS ||====================================================#

# Prints a debug message if CONFIG_verbose is `true`.
debug() {
  if [ "$CONFIG_verbose" = "true" ]; then
    echo "[debug]>" "$@"
    return 0
  fi
  return 1
}


# Sets up a command for dry running.
# If CONFIG_dry is `true`, the command is printed to stdout. Otherwise the command is run as normal.
dry() {
  dry_quiet=false
  if [ "$1" = "-q" ]; then
    dry_quiet=true
    shift
  fi

  if $CONFIG_dry; then
    if $CONFIG_verbose; then # Lines up the debug and dry messages for easier reading.
      echo "[dry]>  " "$@"
    else
      echo "[dry]>" "$@"
    fi
    return 0
  fi

  if $dry_quiet; then
    "$@" >/dev/null
  else
    "$@"
  fi
  return $?
}

# Gives the user a yes/no choice.
choiceYN() {
  choice_verifyCommands_abort=false
  for verifyCommands_cmdinfo in \
    "stty#makes the terminal quiet while a choice is being selected" \
    "dd#handles choice inputs"
  do
    choice_verifyCommands_cmd="${verifyCommands_cmdinfo%%#*}"
    choice_verifyCommands_desc="${verifyCommands_cmdinfo#*#}"
    if (! command -v "$verifyCommands_cmd" >/dev/null); then
      echo "Could not find required command \`$choice_verifyCommands_cmd\`." >&2
      echo " ($choice_verifyCommands_desc)" >&2
      choice_verifyCommands_abort=true
    fi
  done

  if $choice_verifyCommands_abort; then exit 2; fi
  

  if $CONFIG_yes; then return 0; fi

  choice_msg="Confirm?"
  if [ "$1" ]; then choice_msg="$1"; fi
  printf "%s [Y/N]> " "$choice_msg" >/dev/tty

  choice_exit=0
  choice_stty="$(stty -g)"
  stty raw -echo
  while true; do
    choice_input="$(dd if=/dev/tty bs=1 count=1 2>/dev/null)"
    case "$choice_input" in
      y|Y)
        choice_exit=0
        break;;

      n|N)
        choice_exit=1
        break;;

      *)
        printf "\a"
        ;;
    esac
  done
  stty "$choice_stty"

  printf "%s\n" "$choice_input" >/dev/tty

  return $choice_exit
}

#
readConfig() {
  if [ "$CONFIG_config" = "./.opticonfig" ]; then
    if ! [ -f "$CONFIG_config" ]; then option_genconfig; fi
  elif ! [ -f "$CONFIG_config" ]; then
    echo "config with path [$CONFIG_config] does not exist" >&2
    return 1
  fi

  readConfig_fail=false
  readConfig_lineno=0
  while IFS= read readConfig_line; do
    readConfig_lineno="$((readConfig_lineno + 1))"
    readConfig_line="${readConfig_line#"${readConfig_line%%[! $T]*}"}"
    if [ -z "$readConfig_line" ] || [ "${readConfig_line#"#"}" != "$readConfig_line" ]; then
      # "" or "# comment"
      continue;
    elif [ "${readConfig_line#"+"}" != "$readConfig_line" ]; then
      # "+ ./inclusion"
      readConfig_line="${readConfig_line#"+"}"
      readConfig_line="${readConfig_line#" "}"
      debug "Read config inclusion +$readConfig_line"
      set -- $readConfig_line
      while [ $# -gt 0 ]; do
        if [ "${1%"/"}" != "$1" ] || [ -d "$1" ] ; then
          echo "$CONFIG_config:$readConfig_lineno: unable to include '$1', cannot include directories" >&2
        elif [ ! -f "$1" ]; then
          echo "$CONFIG_config:$readConfig_lineno: unable to include '$1', file does not exist" >&2
        elif [ "${1%".png"}" = "$1" ] && [ "${1%".ogg"}" = "$1" ]; then
          echo "$CONFIG_config:$readConfig_lineno: unable to include '$1', file type is not supported" >&2
        else
          FILE_cfgrules="$FILE_cfgrules$N+$1"
        fi

        shift
      done
    elif [ "${readConfig_line#"-"}" != "$readConfig_line" ]; then
      # "- ./exclusion"
      readConfig_line="${readConfig_line#"-"}"
      readConfig_line="${readConfig_line#" "}"
      debug "Read config exclusion -$readConfig_line"
      set -- $readConfig_line
      while [ $# -gt 0 ]; do
        if [ ! -e "$1" ]; then
          echo "$CONFIG_config:$readConfig_lineno: unable to exclude '$1', it does not exist" >&2
        elif [ -d "$1" ]; then
          FILE_cfgrules="$FILE_cfgrules$N!$1"
        elif [ "${1%".png"}" = "$1" ] && [ "${1%".ogg"}" = "$1" ]; then
          echo "$CONFIG_config:$readConfig_lineno: unable to exclude '$1', file type is not supported" >&2
        else
          FILE_cfgrules="$FILE_cfgrules$N-$1"
        fi

        shift
      done
    elif [ "${readConfig_line#*=}" != "$readConfig_line" ]; then
      # "key=value"
      readConfig_key="${readConfig_line%%=*}"
      readConfig_value="${readConfig_line#*=}"
      if [ "${readConfig_key% }" != "$readConfig_key" ]; then
        readConfig_key="${readConfig_key%${readConfig_key##*[! $T]}}"
        readConfig_value="${readConfig_value#" "}"
      fi

      debug "Read config option $readConfig_key=$readConfig_value"
      case "$readConfig_key" in
        "textures")
          if ! readConfig_value="$(OptHandler_checkBoolean "" "$readConfig_value" 2>/dev/null)"; then
            echo "$CONFIG_config:$readConfig_lineno: invalid value given to config option 'textures'" >&2
            readConfig_fail=true
          elif [ "${CONFIG_textures+_}" != "_" ]; then
            CONFIG_textures="$readConfig_value"
          fi
          ;;

        "level")
          if ! readConfig_value="$(OptHandler_checkInteger "" "$readConfig_value" 1 4 2>/dev/null)"; then
            echo "$CONFIG_config:$readConfig_lineno: invalid value given to config option 'level'" >&2
            readConfig_fail=true
          elif [ "${CONFIG_level+_}" != "_" ]; then
            CONFIG_level="$readConfig_value"
          fi
          ;;

        "sounds")
          if ! readConfig_value="$(OptHandler_checkBoolean "" "$readConfig_value" 2>/dev/null)"; then
            echo "$CONFIG_config:$readConfig_lineno: invalid value given to config option 'sounds'" >&2
            readConfig_fail=true
          elif [ "${CONFIG_sounds+_}" != "_" ]; then
            CONFIG_sounds="$readConfig_value"
          fi
          ;;

        "backup")
          if ! readConfig_value="$(OptHandler_checkBoolean "" "$readConfig_value" 2>/dev/null)"; then
            echo "$CONFIG_config:$readConfig_lineno: invalid value given to config option 'backup'" >&2
            readConfig_fail=true
          elif [ "${CONFIG_backup+_}" != "_" ]; then
            CONFIG_backup="$readConfig_value"
          fi
          ;;

        "nogit")
          if ! readConfig_value="$(OptHandler_checkBoolean "" "$readConfig_value" 2>/dev/null)"; then
            echo "$CONFIG_config:$readConfig_lineno: invalid value given to config option 'nogit'" >&2
            readConfig_fail=true
          elif [ "${CONFIG_nogit+_}" != "_" ]; then
            CONFIG_nogit="$readConfig_value"
          fi
          ;;

        "verbose")
          if ! readConfig_value="$(OptHandler_checkBoolean "" "$readConfig_value" 2>/dev/null)"; then
            echo "$CONFIG_config:$readConfig_lineno: invalid value given to config option 'debug'" >&2
            readConfig_fail=true
          elif [ "${CONFIG_verbose+_}" != "_" ]; then
            CONFIG_verbose="$readConfig_value"
          fi
          ;;

        "dry")
          if ! readConfig_value="$(OptHandler_checkBoolean "" "$readConfig_value" 2>/dev/null)"; then
            echo "$CONFIG_config:$readConfig_lineno: invalid value given to config option 'dry'" >&2
            readConfig_fail=true
          elif [ "${CONFIG_dry+_}" != "_" ]; then
            CONFIG_dry="$readConfig_value"
          fi
          ;;

        *)
          echo "$CONFIG_config:$readConfig_lineno: unknown config option '$readConfig_key'" >&2
          readConfig_fail=true
          ;;
      esac
    else
      echo "$CONFIG_config:$readConfig_lineno: failed to parse line" >&2
      readConfig_fail=true
    fi
  done <"$CONFIG_config"

  FILE_cfgrules="${FILE_cfgrules#"$N"}"

  if $readConfig_fail; then return 1; fi
  return 0
}

#
verifyPrograms() {
  verifyPrograms_status=0

  # Check for git
  if ! $CONFIG_nogit; then
    if [ -e "./.git/" ]; then
      if (! command -v git >/dev/null); then
        echo "Could not find command \`git\`." >&2
        verifyPrograms_status=1
      fi
    else
      debug "Not in a git repository. Git features are disabled!"
      CONFIG_nogit=true
    fi
  fi

  if $CONFIG_textures; then
    # Find Oxipng.
    OXIPNG="$(command -v oxipng)"
    if [ -z "$OXIPNG" ]; then
      if [ -x "./oxipng" ]; then
        OXIPNG="./oxipng"
      elif [ -x "../oxipng" ]; then
        OXIPNG="../oxipng"
      elif [ -x "./.git/hooks/oxipng" ]; then
        OXIPNG="./.git/hooks/oxipng"
      else
        echo "Could not find program \`oxipng\`." >&2
        echo "  Get it from https://github.com/oxipng/oxipng/releases" >&2
        echo "  If using Windows, you might want [oxipng-#.#.#-x86_64-pc-windows-msvc.zip]." >&2
        echo "  Otherwise, you'll be smart enough to figure out which one you need." >&2
        verifyPrograms_status=1
      fi
    fi

    # Find PNGOUT.
    PNGOUT=""
    if [ "$CONFIG_level" -ge 4 ]; then
      PNGOUT="$(command -v pngout)"
      if [ -z "$PNGOUT" ]; then
        if [ -x "./pngout" ]; then
          PNGOUT="./pngout"
        elif [ -x "../pngout" ]; then
          PNGOUT="../pngout"
        elif [ -x "./.git/hooks/pngout" ]; then
          OXIPNG="./.git/hooks/pngout"
        else
          echo "Could not find program \`pngout\`." >&2
          echo "  Optimization level 4 requires PNGOUT to function." >&2
          echo "  If using Windows, get it from https://advsys.net/ken/util/pngout.exe" >&2
          echo "  Otherwise, get it from https://www.jonof.id.au/kenutils.html" >&2
          verifyPrograms_status=1
        fi
      fi
    fi
  fi

  if $CONFIG_sounds; then
    # Find OptiVorbis.
    OPTIVORBIS="$(command -v optivorbis)"
    if [ -z "$OPTIVORBIS" ]; then
      if [ -x "./optivorbis" ]; then
        OPTIVORBIS="./optivorbis"
      elif [ -x "../optivorbis" ]; then
        OPTIVORBIS="../optivorbis"
      elif [ -x "./.git/hooks/optivorbis" ]; then
        OPTIVORBIS="./.git/hooks/optivorbis"
      else
        echo "Could not find program \`optivorbis\`." >&2
        echo "  Get it from https://github.com/OptiVorbis/OptiVorbis/releases" >&2
        echo "  If using Windows, you might want [OptiVorbis.CLI.x86_64-pc-windows-gnu.zip]." >&2
        echo "  Otherwise, you'll be smart enough to figure out which one you need." >&2
        verifyPrograms_status=1
      fi
    fi
  fi

  return $verifyPrograms_status
}

#
gitFiles() {
  for gitFiles_line in $(git status -z -uno | cut -d "" -f1- --output-delimiter="$N"); do
    if [ "$gitFiles_line" = "" ]; then continue; fi
    gitFiles_file="./${gitFiles_line#???}"
    gitFiles_type="${gitFiles_line%"${gitFiles_line#?}"}"
    debug "Checking file ($gitFiles_type) [$gitFiles_file]."
    if [ "$gitFiles_file" != "${gitFiles_file%.png}" ] || [ "$gitFiles_file" != "${gitFiles_file%.ogg}" ]; then
      case $gitFiles_type in
        # Yes
        "M")
          echo "File [$gitFiles_file] has been modified. Optimizing..."
          FILE_selected="$FILE_selected$N$gitFiles_file"
          ;;

        "A")
          echo "File [$gitFiles_file] has been added. Optimizing..."
          FILE_selected="$FILE_selected$N$gitFiles_file"
          ;;

        # No
        " "|"?"|"!")
          debug "File [$gitFiles_file] has not been staged. Doing nothing..."
          ;;

        "T")
          debug "File [$gitFiles_file] had its type changed. Doing nothing..."
          ;;

        "D")
          debug "File [$gitFiles_file] has been deleted. Doing nothing..."
          ;;

        "R")
          debug "File [$gitFiles_file] has been renamed. Doing nothing..."
          ;;

        "C")
          debug "File [$gitFiles_file] has been copied. Doing nothing..."
          ;;

        *)
          debug "Unknown status ($gitFiles_type) for file [$gitFiles_file]. Doing nothing..."
          ;;
      esac
    else
      debug "File [$gitFiles_file] is not supported. Doing nothing..."
    fi
  done

  FILE_selected="${FILE_selected#"$N"}"
  return 0
}

#
dirFiles() {
  for dirFiles_file in $(find . "(" -name "*.png" -o -name "*.ogg" ")"); do
    debug "Checking file [$dirFiles_file]."
    if [ -e "$dirFiles_file" ]; then
      echo "File [$dirFiles_file] was found in current directory. Optimizing..."
      FILE_selected="$FILE_selected$N$dirFiles_file"
    fi
  done

  FILE_selected="${FILE_selected#"$N"}"
  return 0
}

#
argFiles() {
  for argFiles_file in "$@"; do
    debug "Checking file [$argFiles_file]."
    if [ -e "$argFiles_file" ]; then
      if [ "$argFiles_file" = "${argFiles_file%.png}" ] && [ "$argFiles_file" = "${argFiles_file%.ogg}" ]; then
        echo "File [$argFiles_file] is not supported by this script!" >&2
      else
        echo "File [$argFiles_file] was found. Optimizing..."
        FILE_selected="$FILE_selected$N$argFiles_file"
      fi
    else
      echo "File [$argFiles_file] does not exist!" >&2
    fi
  done

  FILE_selected="${FILE_selected#"$N"}"
  return 0
}

#
applyCfgFileRules() {
  for applyCfgFileRules_rule in $FILE_cfgrules; do
    applyCfgFileRules_path="${applyCfgFileRules_rule#?}"
    applyCfgFileRules_mode="${applyCfgFileRules_rule%"${applyCfgFileRules_rule#?}"}"

    # The validity of files in the CFG rule set is handled as they are read in `readConfig()`.

    if [ "$applyCfgFileRules_mode" = "+" ]; then
      # Adds the given path to the list of selected files. Included files are verified before being added to this list.
      # Unless you are intentionally trying to mess up the script or are playing with files that are not guaranteed to
      # exist at a later time, nothing should go wrong here.
      FILE_selected="$FILE_selected$N$applyCfgFileRules_path"
      debug "Applying config inclusion [+ $applyCfgFileRules_path]"
      debug "  File [$applyCfgFileRules_path] was included"
    elif [ "$applyCfgFileRules_mode" = "-" ]; then
      # Compares the real path of the excluded file to the real path of the file to exclude.
      # If they match, then the file is the one to exclude.
      # The search does not stop on the first match so that duplicate entries can be handled properly.
      debug "Applying config exclusion [- $applyCfgFileRules_path]"
      applyCfgFileRules_realpath="$(readlink -nf "$applyCfgFileRules_path")"
      applyCfgFileRules_newSelected=""
      for applyCfgFileRules_file in $FILE_selected; do
        applyCfgFileRules_realfile="$(readlink -nf "$applyCfgFileRules_file")"
        if [ "$applyCfgFileRules_realpath" != "$applyCfgFileRules_realfile" ]; then
          applyCfgFileRules_newSelected="$applyCfgFileRules_newSelected$N$applyCfgFileRules_file"
        else
          debug "  File [$applyCfgFileRules_file] was excluded."
        fi
      done
      FILE_selected="${applyCfgFileRules_newSelected#"$N"}"
    elif [ "$applyCfgFileRules_mode" = "!" ]; then
      # Compares the real path of the excluded directory to the real path of the file to exclude.
      # If the "real path is a prefix of the "real file" then the file exists in the excluded directory.
      debug "Applying config exclusion [! $applyCfgFileRules_path]"
      applyCfgFileRules_realpath="$(readlink -nf "$applyCfgFileRules_path")"
      applyCfgFileRules_newSelected=""
      for applyCfgFileRules_file in $FILE_selected; do
        applyCfgFileRules_realfile="$(readlink -nf "$applyCfgFileRules_file")"
        if [ "${applyCfgFileRules_realfile##"$applyCfgFileRules_realpath"}" = "$applyCfgFileRules_realfile" ]; then
          applyCfgFileRules_newSelected="$applyCfgFileRules_newSelected$N$applyCfgFileRules_file"
        else
          debug "  File [$applyCfgFileRules_file] was excluded."
        fi
      done
      FILE_selected="${applyCfgFileRules_newSelected#"$N"}"
    else
      echo "Unknown rule [$applyCfgFileRules_mode $applyCfgFileRules_path]." >&2
      return 1
    fi
  done

  return 0
}


#====================================================|| OPTIONS ||=====================================================#

#     --help
OptHandler_newOption "help" "" 0x00 "" "" option_help
option_help() {
  printf "%s" "\
Usage: ${0##*/} [OPTION]... [FILE]...
Optimizes Figura avatar files, reducing the impact they have on the limited
space available to an avatar.

If this script is given file arguments, it will optimize only those files.
If not given any file arguments, it will do one of two things:
- Optimize all files in the current Git repository if the current directory is
  the root of said repo.
- Optimize all files in the current directory and any subdirectories if the
  current directory is not the root of a Git repo.

The \`.opticonfig\` file further controls what settings the script uses and the
list of files it optimizes. If the config does not exist, it will be created
when the script next runs. Use the \`--gen-config\` option to only generate the
config and do nothing else.

Options are read in the order they are provided to the script!
(\`-yg\` will skip confirmation to overwrite a config file, \`-gy\` will not.)

  -b, --backup        create backups of optimized files
  -c, --config=PATH   use a different file as the config; this also changes the
                      path that --gen-config writes to.
  -d, --dry           print the commands that would be executed if this script
                      was run; no actual changes will be made to files
  -g, --gen-config    generate the base config used by this script and exit; if
                      the config already exists, it will be backed up and a
                      clean one will be written
  -n, --nogit         disable Git features even if this script is run in the
                      root of a Git repository
  -o, --level=LEVEL   set the level of optimization applied to texture files
  -s, --sounds        optimize sound files
  -t, --textures      optimize texture files
  -v, --verbose       print debug information while the script is running
  -y, --yes           automatically respond with 'y' to confirmation dialogs
      --help          display this help and exit
      --version       display version information and exit

Prefixing options b, d, n, s, t, or y with + instead of - turns them off.
If the current session is not interactive, \`--yes\` is implied.

"
  if [ "${0##*/}" != "pre-commit" ]; then
    printf "%s" "\
This script is a valid Git pre-commit hook and will automatically optimize any
files staged as added or modified and restage them after optimization just
before a commit is completed.
Since Git does not provide hooks with values, the \`.opticonfig\` file is the
only way to configure it if used as a hook.

"
  fi

  printf "%s" "\
OptiFigura (c) 2025 Grandpa Scout
Oxipng (c) 2016 Joshua Holmer
PNGOUT (c) 2015 Ken Silverman
OptiVorbis (c) 2022 Alejandro Gonzalez
Check bottom of the script file for full licenses.
"

  return 3
}

#     --version
OptHandler_newOption "version" "" 0x00 "" "" option_version
option_version() {
  echo "$SCRIPT_VERSION"
  return 3
}


# -b, --backup
OptHandler_newOption "backup" "b" 0x01 "" "" option_backup
option_backup() {
  CONFIG_backup="$1"
  return 0
}

# -c, --config=PATH
OptHandler_newOption "config" "c" 0x04 "" "" option_config
option_config() {
  CONFIG_config="$1"
  return 0
}

# -d, --dry
OptHandler_newOption "dry" "d" 0x01 "" "" option_dry
option_dry() {
  CONFIG_dry="$1"
  return 0
}

# -g, --gen-config
OptHandler_newOption "gen-config" "g" 0x00 "" "" option_genconfig
option_genconfig() {
  if [ -e "$CONFIG_config" ]; then
    if ! choiceYN "Do you wish to overwrite \`$CONFIG_config\`?"; then
      return 1
    fi

    if $CONFIG_backup; then
      cp -f "$CONFIG_config" "$CONFIG_config.bak"
    fi
  fi
  printf "%s" "\
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


" >"$CONFIG_config" 2>/dev/null
  if [ $? != 0 ]; then
    echo "Could not write config to '$CONFIG_config'!"
    return 1
  fi

  echo "Generated new config file!"
  return 3
}

# -n, --nogit
OptHandler_newOption "nogit" "n" 0x01 "" "" option_nogit
option_nogit() {
  CONFIG_nogit="$1"
  return 0
}

# -o, --level=LEVEL
OptHandler_newOption "level" "o" 0x02 1 4 option_level
option_level() {
  CONFIG_level="$1"
  return 0
}

# -s, --sounds
OptHandler_newOption "sounds" "s" 0x01 "" "" option_sounds
option_sounds() {
  CONFIG_sounds="$1"
  return 0
}

# -t, --textures
OptHandler_newOption "textures" "t" 0x01 "" "" option_textures
option_textures() {
  CONFIG_textures="$1"
  return 0
}

# -v, --verbose
OptHandler_newOption "verbose" "v" 0x01 "" "" option_verbose
option_verbose() {
  CONFIG_verbose="$1"
  return 0
}

# -y, --yes
OptHandler_newOption "yes" "y" 0xF1 "" "" option_yes
option_yes() {
  CONFIG_yes="$1"
  return 0
}


#======================================================|| MAIN ||======================================================#

# Collect positional arguments and exit if a failure happened.
OptHandler_readArgs "$@"
OptHandler_status=$?
if [ $OptHandler_status -ne 0 ]; then exit $OptHandler_status; fi

# Set the new positonal arguments.
eval set -- $OptHandler_POSITIONAL
debug "POSITIONAL ARGUMENTS:" "$@"

# Set IFS
_IFS="$IFS"
IFS="$N"

# Read the config file
if ! readConfig; then exit 1; fi

# Verify program dependencies
if ! verifyPrograms; then
  IFS="$_IFS"
  exit 2
fi

# Read files.
if [ $# -gt 0 ]; then
  debug "Selecting files from positional arguments."
  argFiles "$@"
  CONFIG_nogit=true
elif $CONFIG_nogit; then
  debug "Selecting files from current directory."
  dirFiles
else
  debug "Selecting files from Git repository."
  gitFiles
fi
debug "Selected Files (Before CFG):" "$FILE_selected"

if ! applyCfgFileRules; then exit 1; fi
debug "Selected Files (After CFG):" "$FILE_selected"

if [ -z "$FILE_selected" ]; then
  echo "No files to optimize!"
  IFS="$_IFS"
  exit 0
fi

if $CONFIG_dry; then
  echo "\
  +--------------------------------------------------------------------------+
  |   (i)                   DRY RUNNING IS ENABLED.                    (i)   |
  | The commands that would have modified files will instead be printed and  |
  | the current Git commit will fail if this was run as a pre-commit hook!   |
  +--------------------------------------------------------------------------+
"
fi

set -f
# Make backups if they are enabled.
if $CONFIG_backup; then
  debug "Starting backups..."
  for file in $FILE_selected; do
    debug "Creating a backup of [$file] as [$file.bak]."
    if ! dry cp -f "$file" "$file.bak"; then
      echo "\
  +--------------------------------------------------------------------------+
  |   /!\                  COULD NOT CREATE A BACKUP!                  /!\   |
  | Backups are enabled and a backup for a file could not be created. This   |
  | script will now stop to protect any files that were about to be changed. |
  +--------------------------------------------------------------------------+\
" >&2
      echo "Failed to write [$file.bak]" >&2
      echo "  with the contents of [$file]" >&2
      IFS="$_IFS"
      exit 1
    fi
  done
fi

# Optimize textures
if $CONFIG_textures; then
  echo "Optimizing texture files..."

  FILE_png=""
  for file in $FILE_selected; do
    if [ "${file%".png"}" != "$file" ]; then
      FILE_png="$FILE_png$N$file"
    fi
  done
  FILE_png="${FILE_png#"$N"}"

  if [ "$FILE_png" ]; then
    # Begin optimization
    oxi_options=""
    if [ "$CONFIG_level" -le 1 ]; then
      oxi_options="-omax$N-s"
    elif [ "$CONFIG_level" -eq 2 ]; then
      oxi_options="-omax$N-s$N-Z$N--fast"
    else
      oxi_options="-omax$N-s$N-Z"
    fi

    debug "Optimizing files with options" $oxi_options
    dry $OXIPNG $oxi_options -- $FILE_png

    # If optimization level is set to 4, run PNGOUT on every file.
    if [ "$CONFIG_level" -ge 4 ]; then
      for file in $FILE_png; do
        dry $PNGOUT -y "$file"
      done
    fi
  fi
fi

# Optimize sounds
if $CONFIG_sounds; then
  echo "Optimizing sound files..."

  FILE_ogg=""
  for file in $FILE_selected; do
    if [ "${file%".ogg"}" != "$file" ]; then
      FILE_ogg="$FILE_ogg$N$file"
    fi
  done
  FILE_ogg="${FILE_ogg#"$N"}"

  for file in $FILE_ogg; do
    if ! $CONFIG_dry; then echo "Processing: $file"; fi
    dry $OPTIVORBIS -q "$file" "${file%".ogg"}.optivorbis.ogg"
    dry mv -f "${file%".ogg"}.optivorbis.ogg" "$file"
  done
fi


# Re-stage all modified files.
if ! $CONFIG_nogit; then
  debug "Re-staging files..."
  dry git add -- $FILE_selected 2>/dev/null
  if [ $? -ge 128 ]; then
    echo "\
  +--------------------------------------------------------------------------+
  |   /!\                   COULD NOT RESTAGE FILES!                   /!\   |
  | One of the optimized files could not be restaged. This script will now   |
  | stop to avoid committing the wrong version of the optimized files.       |
  +--------------------------------------------------------------------------+\
" >&2
    echo "Failed to restage files. Did you attempt to" >&2
    echo "optimize a file outside of the Git repository?" >&2
    IFS="$_IFS"
    exit 1
  fi
fi


# We're done here.
set +f
echo "Optimization finished!"

IFS="$_IFS"
if $CONFIG_dry; then exit 3; fi
exit 0


# This runs as a batch script if this file is detected as running from Windows CMD.
# shellcheck disable=all
{
  :Win
  SET "0=%~0"
  IF "%0:~-4%"==".bat" (
    ECHO Changing the extension of this file will not magically make it work on Windows.
  ) ELSE (
    ECHO Windows CMD cannot run Posix shell scripts.
  )
  ECHO+
  ECHO You can find the Windows version of this script at the same place you got this one.
  EXIT /B 1
}



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
