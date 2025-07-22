#!/bin/sh
#$optimizepng


# <GrandpaScout>
# RELEVANT LICENSES ARE PLACED AT THE BOTTOM OF THIS FILE!
# Make sure `oxipng.exe` and `pngout.exe` (if you want to use that as well) exist either in the root of your project or
# in your PATH variable before using this.
#
# This script attempts to optimize all png files that are staged as added or modifed.
#
# All files are backed up as `filename.png.bak` before being optimized just in case something bad happens.

# Don't try to use this script to optimize files with strange characters in their names. I'm not responsible for your
# blatant misuse of the script.

# IF YOU ARE LOOKING FOR THE CONFIG, scroll down a bit.
# Use [scriptname.sh --help] for help with using this script from the command line.

# EXIT CODES:
# 0 = Success
# 1 = Generic error.
# 2 = Missing required shell command.
# 3 = Forced error caused by dry running. This stops Git from committing staged files.
# 4 = Option caused the script to do nothing to any files. (--config, --help)


#=================================|| CONFIG ||=================================#

# NOTICE:
#   IF THE PRE-COMMIT HOOK IS INSTALLED, THE CONFIG WILL BE READ FROM THAT INSTEAD AND THIS WILL BE IGNORED!
#   IF THIS FILE IS THE PRE-COMMIT HOOK, DISREGARD THE ABOVE.


# The optimization level of this script. Different levels have different speeds and average compression ratios.
#   1: Very fast | Low compression
#   2: Fast      | Standard compression
#   3: Slow      | High compression
#   4: Very slow | Highest compression (Requires PNGOUT!)
# Valid values: 1-4
# Default: 2
CONFIG_level=2

# Create a backup of every file this script successfully works on.
# This is a good idea to keep on just in case the script errors during saving.
# Valid values: true / false
# Default: true
CONFIG_backup=true

# Print debug information to the output.
# This only makes sense if you are running this hook in a command line environment. (AKA, *not* Github Desktop.)
# Valid values: true / false
# Default: false
CONFIG_debug=false

# Only print what *would* happen if the script was run.
# This also stops a git commit from succeeding if this script was run due to a pre-commit hook.
# Incompatible with `CONFIG_level=4`!
# Valid values: true / false
# Default: false
CONFIG_dry=false

#==============================================================================#

FLAG_nogit=false
while [ "$1" ]; do
  if [ "$1" = "--config" ]; then
    # If a config was requested, print it.
    echo "$CONFIG_level:$CONFIG_backup:$CONFIG_debug:$CONFIG_dry"
    exit 4
  elif [ "$1" = "--nogit" ]; then
    # Disable git features.
    FLAG_nogit=true
  elif [ "$1" = "--help" ]; then
    # Display help message.
    echo "Usage: ${0##*/} [OPTION]..."
    echo "Optimizes png files that are staged as added or modified in the current git repo"
    echo "with Oxipng. (And PNGOUT if available.)"
    echo "This expects Oxipng and PNGOUT to be reachable from the current working directory."
    echo ""
    echo "  --config   print the config stored in this script and exit"
    echo "  --nogit    optimize all pngs in the current directory (not subdirectories) and"
    echo "               skip the restaging step"
    echo "  --help     display this help and exit"
    echo ""
    echo "Due to this also being a valid pre-commit hook, most other options are stored in"
    echo "the script file itself. Open it with your favorite text editor and check out the"
    echo "config section for more information."
    echo ""
    echo "(c) 2025 Grandpa Scout"
    echo "Oxipng (c) 2016 Joshua Holmer"
    echo "PNGOUT (c) 2015 Ken Silverman"
    echo "Check bottom of the script file for full licenses."
    exit 4
  else
    echo "Unknown option $1"
    exit 1
  fi
  shift
done


# IFSn't
_IFS="$IFS"
IFS=":"

# If this is not the hook and the hook exists, prefer the hook's config instead.
if [ "${0##*/}" != "pre-commit" ] && [ -f "./.git/hooks/pre-commit" ]; then
  if (command -v sed >/dev/null); then
    if [ "$(sed -n "2p" <./.git/hooks/pre-commit)" = "#\$optimizepng" ]; then
      read -r CONFIG_level CONFIG_backup CONFIG_debug CONFIG_dry <<@@@
$(./.git/hooks/pre-commit --config)
@@@
    fi
  fi
fi


set -u

S="$(printf "\x1F")"


#===============================|| FUNCTIONS ||================================#

# Prints a debug message if CONFIG_debug is `true`.
debug() {
  if $CONFIG_debug; then
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
    if $CONFIG_debug; then # Lines up the debug and dry messages for easier reading.
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


#=============================|| COMMAND CHECKS ||=============================#

# Make sure every used command exists.
abort=false

# Check for cp
if (! command -v cp >/dev/null); then
  echo "Could not find command \`cp\`."
  abort=true
fi

# Check for cut
if (! command -v cut >/dev/null); then
  echo "Could not find command \`cut\`."
  abort=true
fi

# Check for printf
if (! command -v printf >/dev/null); then
  echo "Could not find command \`printf\`."
  abort=true
fi

# Check for read
if (! command -v read >/dev/null); then
  echo "Could not find command \`read\`."
  abort=true
fi

# Check for rm
if (! command -v rm >/dev/null); then
  echo "Could not find command \`rm\`."
  abort=true
fi

# Check for wc
if (! command -v wc >/dev/null); then
  echo "Could not find command \`wc\`."
  abort=true
fi

# Check for git
if ! $FLAG_nogit; then
  if [ -e "./.git/" ]; then
    if (! command -v git >/dev/null); then
      echo "Could not find command \`git\`."
      abort=true
    fi
  else
    echo "Not in a git repository. Git features are disabled!"
    FLAG_nogit=true
  fi
fi

# Find Oxipng.
OXIPNG="$(command -v oxipng)"
if [ -z "$OXIPNG" ]; then
  if [ -f "./oxipng" ]; then
    OXIPNG="./oxipng"
  elif [ -f "../oxipng" ]; then
    OXIPNG="../oxipng"
  elif [ -f "./.git/hooks/oxipng" ]; then
    OXIPNG="./.git/hooks/oxipng"
  else
    echo "Could not find command \`oxipng\`."
    echo "  Get it from https://github.com/oxipng/oxipng/releases"
    echo "  If using Windows, you might want [oxipng-#.#.#-x86_64-pc-windows-msvc.zip]."
    echo "  Otherwise, you'll be smart enough to figure out which one you need."
    abort=true
  fi
fi

# Find PNGOUT.
PNGOUT=""
if [ "$CONFIG_level" -ge 4 ]; then
  if $CONFIG_dry; then
    echo "Optimization level 4 does not support dry running."
    echo "Dry running with level 3 instead..."
    CONFIG_level=3
  else
    PNGOUT="$(command -v pngout)"
    if [ -z "$PNGOUT" ]; then
      if [ -f "./pngout" ]; then
        PNGOUT="./pngout"
      elif [ -f "../pngout" ]; then
        PNGOUT="../pngout"
      elif [ -f "./.git/hooks/pngout" ]; then
        OXIPNG="./.git/hooks/pngout"
      else
        echo "Could not find command \`pngout\`."
        echo "  Optimization level 4 requires PNGOUT to function."
        echo "  If using Windows, get it from https://advsys.net/ken/util/pngout.exe"
        echo "  Otherwise, get it from https://www.jonof.id.au/kenutils.html"
        abort=true
      fi
    fi
  fi
fi

if $abort; then
  echo "Aborting..."
  IFS="$_IFS"
  exit 2
fi


#==============================|| BEGIN SCRIPT ||==============================#

if $CONFIG_dry; then
  echo "+------------------------------------------------+"
  echo "| (i)        DRY RUNNING IS ENABLED.         (i) |"
  echo "| No changes will be made to any files and the   |"
  echo "| current git commit will fail if there is one.  |"
  echo "+------------------------------------------------+"
  echo ""
fi


# Begin looking for files to optimize.
files=""
if $FLAG_nogit; then
  IFS="$_IFS"
  for line in *.png; do
    if [ "$line" = "" ]; then break; fi
    files="$files$S$line"
  done
  files="${files#"$S"}"
else
  IFS="$S"
  lines="$(git status -z -uno | cut -d "" -f1- --output-delimiter="$S")"
  for line in $lines; do
    if [ "$line" = "" ]; then break; fi
    file="./$(printf "%s" "$line" | cut -c4-)"
    type="$(printf "%s" "$line" | cut -c1)"
    if [ "$file" != "${file%.png}" ]; then case $type in
      " ")
        # No
        debug "File [$file] has not been staged. Doing nothing..."
        ;;

      "M")
        # Yes
        echo "File [$file] has been modified. Optimizing..."
        files="$files$S$file"
        ;;

      "T")
        # No
        debug "File [$file] had its type changed. Doing nothing..."
        ;;

      "A")
        # Yes
        echo "File [$file] has been added. Optimizing..."
        files="$files$S$file"
        ;;

      "D")
        # No
        debug "File [$file] has been deleted. Doing nothing..."
        ;;

      "R")
        # No
        debug "File [$file] has been renamed. Doing nothing..."
        ;;

      "C")
        # No
        debug "File [$file] has been copied. Doing nothing..."
        ;;

      ***)
        # No
        debug "Unknown status ($type) for file [$file]. Doing nothing..."
        ;;
    esac fi
  done
fi


set -f
# Make backups if they are enabled.
if $CONFIG_backup; then
  for file in $files; do
    debug "Creating a backup of [$file] as [$file.bak]."
    if ! dry cp -f "$file" "$file.bak"; then
      echo "+------------------------------------------------+"
      echo "| /!\       COULD NOT CREATE A BACKUP!       /!\ |"
      echo "| This script will now stop to protect any files |"
      echo "| that were about to be changed.                 |"
      echo "+------------------------------------------------+"
      echo "Failed to write [$file.bak]"
      echo "  with the contents of [$file]"
      IFS="$_IFS"
      exit 1
    fi
  done
fi


# Begin optimization
oxi_options=""
if [ "$CONFIG_level" -le 1 ]; then
  oxi_options="-omax$S-s"
elif [ "$CONFIG_level" -eq 2 ]; then
  oxi_options="-omax$S-s$S-Z$S--fast"
elif [ "$CONFIG_level" -ge 3 ]; then
  oxi_options="-omax$S-s$S-Z"
fi
if $CONFIG_dry; then oxi_options="$oxi_options$S-P"; fi

# shellcheck disable=SC2086 # Allow word splitting
debug "Optimizing files with options" $oxi_options
# shellcheck disable=SC2086 # Allow word splitting
$OXIPNG $oxi_options -- $files

# If optimization level is set to 4, run PNGOUT on every file.
if [ "$CONFIG_level" -ge 4 ]; then
  for file in $files; do
    $PNGOUT -y "$file"
  done
fi

# Re-stage all modified files.
if ! $FLAG_nogit; then
  debug "Re-staging files."
  # shellcheck disable=SC2086 # Allow word splitting
  dry git add -- $files
fi


# We're done here.
set +f
echo "PNG Optimization finished!"
#==============================================================================#

IFS="$_IFS"
if $CONFIG_dry; then exit 3; fi
exit 0



########################################################################################################################
#####  LICENSE INFORMATION: THIS SCRIPT  ###############################################################################
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
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
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
