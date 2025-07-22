@ECHO OFF
::$optimizepng


:: <GrandpaScout>
:: RELEVANT LICENSES ARE PLACED AT THE BOTTOM OF THIS FILE!
:: Make sure `oxipng.exe` and `pngout.exe` (if you want to use that as well) exist either in the root of your project or
:: in your PATH variable before using this.
::
:: This script attempts to optimize all png files that are staged as added or modifed.
::
:: All files are backed up as `filename.png.bak` before being optimized just in case something bad happens.

:: IF YOU ARE LOOKING FOR THE CONFIG, scroll down a bit.
:: Use [scriptname.bat /?] for help with using this script from the command line.

:: EXIT CODES:
:: 0 = Success
:: 1 = Generic error.
:: 2 = Missing required executable.
:: 3 = Forced error caused by dry running.
:: 4 = Option caused the script to do nothing to any files. (/CONFIG, /?)


:: Check to make sure Command Extensions exist.
VERIFY CommandExtensions 2>nul
SETLOCAL EnableExtensions
IF ERRORLEVEL 1 (
  ECHO Command extensions are not available!
  ECHO This script cannot run!
  ECHO Aborting...
  EXIT /B 1
)
SETLOCAL EnableDelayedExpansion


::================================|| CONFIG ||================================::

:: NOTICE:
::   IF THE PRE-COMMIT HOOK IS INSTALLED, THE CONFIG WILL BE READ FROM THAT INSTEAD AND THIS WILL BE IGNORED!
::   IF THIS FILE IS *SOMEHOW* THE PRE-COMMIT HOOK, DISREGARD THE ABOVE.


:: The optimization level of this script. Different levels have different speeds and average compression ratios.
::   1: Very fast | Low compression
::   2: Fast      | Standard compression
::   3: Slow      | High compression
::   4: Very slow | Highest compression (Requires PNGOUT!)
:: Valid values: 1-4
:: Default: 2
SET CONFIG_level=2

:: Create a backup of every file this script successfully works on.
:: This is a good idea to keep on just in case the script errors during saving.
:: Valid values: true / false
:: Default: true
SET CONFIG_backup=true

:: Print debug information to the output.
:: This only makes sense if you are running this hook in a command line environment. (AKA, *not* Github Desktop.)
:: Valid values: true / false
:: Default: false
SET CONFIG_debug=false

:: Only print what *would* happen if the script was run.
:: This also stops a git commit from succeeding if this script was run due to a pre-commit hook.
:: Incompatible with `CONFIG_level=4`!
:: Valid values: true / false
:: Default: false
SET CONFIG_dry=false

::============================================================================::


SET "FLAG_nogit=false"
:while_flags
  IF "%1"=="" GOTO :break_flags

  :: If a config was requested, print it.
  IF /I "%1"=="/CONFIG" (
    ECHO !CONFIG_level!:!CONFIG_backup!:!CONFIG_debug!:!CONFIG_dry!
    EXIT /B 4
  ) ELSE IF "%1"=="--config" (
    ECHO !CONFIG_level!:!CONFIG_backup!:!CONFIG_debug!:!CONFIG_dry!
    EXIT /B 4
  )

  IF /I "%1"=="/NOGIT" (
    SET "FLAG_nogit=true"
    GOTO :continue_flags
  ) ELSE IF "%1"=="--nogit" (
    SET "FLAG_nogit=true"
    GOTO :continue_flags
  )

  FOR /F "delims= " %%O IN ("/? --help") DO IF "%1"=="%%O" (
    ECHO Optimizes png files that are staged as added or modified in the current git repo
    ECHO with Oxipng. ^(And PNGOUT if available.^)
    ECHO This expects Oxipng and PNGOUT to be reachable from the current working directory.
    ECHO=
    ECHO %~nx0 [/CONFIG] [/NOGIT]
    ECHO=
    ECHO   /CONFIG  Prints the config stored in this script and exits.
    ECHO   /NOGIT   Optimizes all PNGs in the current directory ^(not subdirectories^) and
    ECHO              skips the restaging step.
    ECHO=
    ECHO This is a port of the shell script of the same name; and just like that script,
    ECHO most other options are stored in the script file itself. Open it with your
    ECHO favorite text editor and check out the config section for more information.
    ECHO=
    ECHO ^(c^) 2025 Grandpa Scout
    ECHO Oxipng ^(c^) 2016 Joshua Holmer
    ECHO PNGOUT ^(c^) 2015 Ken Silverman
    ECHO Check bottom of the script file for full licenses.
    EXIT /B 4
  )

  ECHO Unknown option %1
  EXIT /B 1

  :continue_flags
  SHIFT
  GOTO :while_flags
:break_flags


:: But why? There's a perfectly fine shell script to use as the pre-commit hook instead.
IF "%~nx0"=="pre-commit" GOTO :main
:: If the pre-commit hook exists, prefer to use that file's config instead.
IF NOT EXIST ".\.git\hooks\pre-commit" GOTO :main
FOR /F "usebackq delims=" %%L IN (`MORE +2 ".\.git\hooks\pre-commit"`) DO (
  IF NOT "%%L"=="#$optimizepng" GOTO :main
  GOTO :applyconfig
)
:applyconfig

FOR /F "usebackq tokens=* delims=" %%L IN (`FINDSTR /B "CONFIG_intensity=[1-4]" ".\.git\hooks\pre-commit"`) DO (
  SET "CONFIG_level=%%L"
)
SET "CONFIG_level=%CONFIG_level:CONFIG_level=%"
SET "CONFIG_level=%CONFIG_level:~1%"

FINDSTR /B "CONFIG_backup=true" ".\.git\hooks\pre-commit" >nul
IF ERRORLEVEL 1 ( SET "CONFIG_backup=false" ) ELSE ( SET "CONFIG_backup=true" )

FINDSTR /B "CONFIG_debug=true" ".\.git\hooks\pre-commit" >nul
IF ERRORLEVEL 1 ( SET "CONFIG_debug=false" ) ELSE ( SET "CONFIG_debug=true" )

FINDSTR /B "CONFIG_dry=true" ".\.git\hooks\pre-commit" >nul
IF ERRORLEVEL 1 ( SET "CONFIG_dry=false" ) ELSE ( SET "CONFIG_dry=true" )

GOTO :main


::==============================|| FUNCTIONS ||===============================::

:: Prints a debug message if CONFIG_debug is `true`.
:$debug
  SET "debug$rest=%*"
  IF "!CONFIG_debug!"=="true" (
    ECHO [debug]^> !debug$rest!
    EXIT /B 0
  )
  EXIT /B 1
GOTO :EOF

:: Sets up a command for dry running.
:: If CONFIG_dry is `true`, the command is printed to stdout. Otherwise the commmand is run as normal.
:$dry
  IF /I "%1"=="/Q" (
    SET "dry$quiet=true"
    SHIFT
  )

  SET "dry$command=%*"
  IF "!CONFIG_dry!"=="true" (
    IF "!CONFIG_debug!"=="true" (
      ECHO [dry]^>   !dry$command!
    ) ELSE (
      ECHO [dry]^> !dry$command!
    )
    EXIT /B 0
  )

  IF "!dry$quiet!"=="true" GOTO :$dry/quiet

  !dry$command!
  EXIT /B !ERRORLEVEL!

  :$dry/quiet
  !dry$command! >nul 2>&1
  EXIT /B !ERRORLEVEL!
GOTO :EOF


:main
::============================|| COMMAND CHECKS ||============================::

:: Check for git
IF NOT "$FLAG_nogit"=="true" (
  IF EXIST ".\.git\" (
    WHERE /Q git
    IF ERRORLEVEL 1 (
      ECHO Could not find command `git`.
      ECHO Aborting...
      EXIT /B 2
    )
  ) ELSE (
    ECHO Not in a git repository. Git features are disabled!
    SET "FLAG_nogit=true"
  )
)

:: Find Oxipng.
WHERE /Q oxipng
IF ERRORLEVEL 1 (
  IF EXIST "..\oxipng.exe" (
    SET "OXIPNG=..\oxipng"
  ) ELSE IF EXIST ".\.git\hooks\oxipng.exe" (
    SET "OXIPNG=.\.git\hooks\oxipng.exe"
  ) ELSE (
    ECHO Could not find command `oxipng`.
    ECHO Aborting...
    EXIT /B 2
  )
) ELSE (
  SET "OXIPNG=oxipng"
)

:: Find PNGOUT.
SET "PNGOUT="
IF "!CONFIG_usepngout!"=="true" (
  WHERE /Q pngout
  IF ERRORLEVEL 1 (
    IF EXIST "..\pngout.exe" (
      SET "PNGOUT=..\pngout.exe"
    ) ELSE IF EXIST ".\.git\hooks\pngout.exe" (
      SET "PNGOUT=.\.git\hooks\pngout.exe"
    ) ELSE (
      ECHO Could not find command `pngout`.
      ECHO   Optimization will be faster but slightly less effective.
    )
  ) ELSE (
    SET "PNGOUT=pngout"
  )
)


::=============================|| BEGIN SCRIPT ||=============================::

IF "!CONFIG_dry!"=="true" (
  ECHO +------------------------------------------------+
  ECHO ^| ^(i^)        DRY RUNNING IS ENABLED.         ^(i^) ^|
  ECHO ^| No changes will be made to any files and the   ^|
  ECHO ^| current git commit will fail if there is one.  ^|
  ECHO +------------------------------------------------+
  ECHO=
)

SET "GIT_status=git status "--porcelain=v1" -uno"
IF "!FLAG_nogit!"=="true" SET "GIT_status=dir /A-D /B *.png"

:: Begin looking for files to optimize.
SET "files="
FOR /F "usebackq delims=" %%L IN (`!GIT_status!`) DO (
  IF "!FLAG_nogit!"=="true" (
    SET "files=!files! "./%%L""
  ) ELSE (
    IF "%%L"=="" GOTO :break_collect
    SET "line=%%L"
    SET "file=./!line:~3!"
    SET "type=!line:~0:1!"
    IF "!file:~-4!"==".png" (
      IF "!type!"==" " (
        CALL :$debug "File [!file!] has not been staged. Doing nothing..."
      ) ELSE IF "!type!"=="M" (
        ECHO File [!file!] has been modified. Optimizing...
        SET "files=!files! "./!file!""
      ) ELSE IF "!type!"=="T" (
        CALL :$debug "File [!file!] had its type changed. Doing nothing..."
      ) ELSE IF "!type!"=="A" (
        ECHO File [!file!] has been added. Optimizing...
        SET "files=!files! "./!file!""
      ) ELSE IF "!type!"=="D" (
        CALL :$debug "File [!file!] has been deleted. Doing nothing..."
      ) ELSE IF "!type!"=="R" (
        CALL :$debug "File [!file!] has been renamed. Doing nothing..."
      ) ELSE IF "!type!"=="C" (
        CALL :$debug "File [!file!] has been copied. Doing nothing..."
      ) ELSE (
        CALL :$debug "Unknown status (!type!) for file [!file!]. Doing nothing..."
      )
    )
  )
)
:break_collect
SET "files=!files:~1!"

:: Make backups if they are enabled.
IF "!CONFIG_backup!"=="true" (
  FOR %%F IN (!files!) DO (
    CALL :$debug "Creating a backup of [%%~F] as [%%~F.bak]."
    CALL :$dry /Q COPY /Y /B "%%~F" "%%~F.bak" /B
    IF ERRORLEVEL 1 (
      ECHO +------------------------------------------------+
      ECHO ^| /^^!\       COULD NOT CREATE A BACKUP^^!       /^^!\ ^|
      ECHO ^| This script will now stop to protect any files ^|
      ECHO ^| that were about to be changed.                 ^|
      ECHO +------------------------------------------------+
      ECHO Failed to write [%%~F.bak]
      ECHO   with the contents of [%%~F]
      EXIT /B 1
    )
  )
)

:: Begin optimization
SET "oxi_options="
IF "!CONFIG_level!" LEQ 1 (
  SET "oxi_options=-omax -s"
) ELSE IF "!CONFIG_level!" EQU 2 (
  SET "oxi_options=-omax -s -Z --fast"
) ELSE IF "!CONFIG_level!" GEQ 3 (
  SET "oxi_options=-omax -s -Z"
)
IF "!CONFIG_dry!"=="true" SET "oxi_options=!oxi_options! -P"

CALL :$debug "Optimizing files with options" !oxi_options!
!OXIPNG! !oxi_options! -- !files!

:: If optimization level is set to 4, run PNGOUT on every file.
IF "!CONFIG_level!" GEQ 4 (
  FOR %%F IN (!files!) DO (
    !PNGOUT! /Y "%%~F"
  )
)

:: Re-stage all modified files.
IF NOT "!FLAG_nogit"=="true" (
  CALL :$debug "Re-staging files."
  CALL :$dry git add -- !files!
)

:: We're done here.
ECHO PNG Optimization finished!
::============================================================================::

IF "!CONFIG_dry!"=="true" EXIT /B 20
EXIT /B 0



::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::  LICENSE INFORMATION: THIS SCRIPT  :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: MIT License
:: 
:: Copyright (c) 2025 GrandpaScout
:: 
:: Permission is hereby granted, free of charge, to any person obtaining a copy
:: of this software and associated documentation files (the "Software"), to deal
:: in the Software without restriction, including without limitation the rights
:: to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
:: copies of the Software, and to permit persons to whom the Software is
:: furnished to do so, subject to the following conditions:
:: 
:: The above copyright notice and this permission notice shall be included in all
:: copies or substantial portions of the Software.
:: 
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
:: IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
:: FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
:: AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
:: LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
:: OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
:: SOFTWARE.



::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::  LICENSE INFORMATION: OXIPNG  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: As this script uses the program in question, this is placed here to respect the license.

:: The MIT License (MIT)
:: Copyright (c) 2016 Joshua Holmer
:: 
:: Permission is hereby granted, free of charge, to any person obtaining a copy of
:: this software and associated documentation files (the "Software"), to deal in
:: the Software without restriction, including without limitation the rights to
:: use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
:: of the Software, and to permit persons to whom the Software is furnished to do
:: so, subject to the following conditions:
:: 
:: The above copyright notice and this permission notice shall be included in all
:: copies or substantial portions of the Software.
:: 
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
:: IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
:: FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
:: AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
:: LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
:: OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
:: SOFTWARE.



::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::  LICENSE INFORMATION: PNGOUT  ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: As this script uses the program in question, this is placed here to respect the rights holder's terms.

:: The software "PNGOUT" belongs to Ken Silverman.
:: The software can be downloaded from https://advsys.net/ken/utils.htm
:: The terms for bundled usage can be found at https://advsys.net/ken/utils.htm#pngoutkziplicense.
