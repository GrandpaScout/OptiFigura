# <p align=center> ![](./assets/icon128.png)<br>OptiFigura
### <p align=center> A Figura avatar asset optimizer.
&nbsp;

Introduction
============
This is a script that attempts to losslessly optimize (reasonably compressable) Figura avatar files by automatically
executing other tools on specific files.

By default, all files are backed up before being optimized just in case something bad happens.


But Why?
--------
Figura avatars have a max size of 100 KB. While a fair amount of files can fit in that amount of space, there are some
much bigger files that just take up too much of it and leave very little for other features.

One of the more common larger files are textures. While texture files (specifically PNGs as that is what Figura uses)
have a lot of information to store, most of this size comes from one issue:  
Blockbench, the primary tool to make models for Figura avatars, does not attempt to compress texture files very well,
leaving them as 32-bit RGBA textures even if a grayscale, paletted, or RGB (no A) texture would be better.

Sounds are the less common of the larger files but that doesn't mean they are any smaller. Audio is very complex to
store which results in very large files. Anything longer than 2 seconds is usually too much for an avatar to reasonably
store.  
While not much can be done to reduce sizes without lowering the quality of the sound, many sound files might not store
the sound optimally or contain useless headers and comments that an avatar does not require to play the sound
properly.  
&nbsp;


Requirements
============
To begin using this script, simply download this repository's code by pressing the `<> Code ▾` button at the top of the
Github page.

To use the script on a Windows system, take the `optimize.bat` script.  
(From now on referred to as the "Windows" script.)

To use the script on a system with a POSIX-compliant shell, take the `optimize.sh` script.  
(From now on referred to as the "POSIX" script.)

If neither of the above are the case and the system somehow supports PowerShell Core, the `optimize.bat` script is a
valid PowerShell script.


General Requirements
--------------------
To begin using either script, the following tools must be installed:
- **Oxipng**: Handles optimization of .png files.  
  If you are on Windows, download the `oxipng-#.#.#-x86_64-pc-windows-msvc.zip` file.  
  ([Download](https://github.com/oxipng/oxipng/releases))
  ([Package Information](https://github.com/oxipng/oxipng/tree/master#installing))
- **OptiVorbis**: Handles optimization of .ogg files.  
  If you are on Windows, download the `OptiVorbis.CLI.x86_64-pc-windows-gnu.zip` file.  
  ([Download](https://github.com/OptiVorbis/OptiVorbis/releases))
- **PNGOUT**: Handles further optimization of .png files at higher optimization levels. Not necessary for lower
  levels.  
  ([Windows Download](https://advsys.net/ken/util/pngout.exe))
  ([Linux / MacOS Download](https://www.jonof.id.au/kenutils.html))

The tools downloaded above must be placed in one of three places:
- The same directory as the script.
- The `./git/hooks/` directory.
- Anywhere specified by the environment `$PATH`.


Windows Script Requirements
---------------------------
This script expects PowerShell Desktop 5.1+ or PowerShell Core to be on your system somewhere. Windows 10+ comes
with PowerShell Desktop 5.1 pre-installed.

The script itself does not have any extra requirements as it mostly uses PowerShell cmdlets and built‑ins.

If run as `optimize.bat`, there is only one extra requirement:
- **`where.exe`**: Used to find the name of PowerShell on your system.  
  This script prefers PowerShell Core (`pwsh.exe`) and will find that first.


POSIX Script Requirements
-------------------------
This script expects a POSIX-compliant shell. MacOS and most Linux distros should have one at `/bin/sh`.

Several shell commands and utilities are expected to exist for this script to function:
- **`/usr/bin/env`**: The shebang command that runs `sh`.
- **`cp`**: Creates backups of files.
- **`cut`**: Splits Git output.
- **`dd`**: Handles choice inputs.
- **`eval`**: Emulates array variables.
- **`find`**: Finds files in subdirectories.
- **`mv`**: Applies OptiVorbis optimizations to the original file.
- **`printf`**: Handles text values in functions.
- **`readlink`**: Handles symbolic links.
- **`stty`**: Makes the terminal quiet while a choice is being selected.  
  &nbsp;


Usage
=====
This script changes behavior depending on where and how it is used.
***
> ### I AM NOT RESPONSIBLE FOR ANY DAMAGES FROM BLATANT MISUSE OF THIS SCRIPT.
> - **Use the script appropriate for your system!**  
>   Use the Windows script on a Windows system.  
>   Use the POSIX script on a system that has a POSIX-compliant shell.
> 
> - **Follow the requirements of the script you download!**  
>   If you do not follow the requirements, the script will not behave as expected.
> 
> - **Do not attempt to run this script in a folder or repository that you do not want optimized!**  
>   This script *will* change the files you ask it to change.
> 
> - **Don't try to optimize files with unusual characters (such as line feeds) in their names!**  
>   Handling unusual characters is an unnecessary obstacle that is better off not dealt with.
> 
> - **Don't run this script in a folder with cyclical synlinks or with symlinks that cause files to appear multiple**
>   **times in the same directory tree!**  
>   Cyclical symlinks create folder structures with infinte depth, causing commands to run infinitely.  
>   If a file appears multiple times due to symlinks the script will not know if that file appears twice and will
>   attempt to interact with it twice.
> 
> - **For the Windows users in the back, don't try to change the extension of either script and expect it to work.**  
>   File extensions do not determine the contents of a file. It just tells Windows what program to open. If that program
>   gets wrong info it will crash and it will not be the file's fault.
***
&nbsp;


Directory Usage
--------------
If executed directly either through the file explorer or by entering its name in the command line with no positional
arguments and the current directory is *not* the root of a Git repository, all supported files in the current directory
and any subdirectories will be optimized.


Repository Usage
----------------
If executed directly either through the file explorer or by entering its name in the command line with no positional
arguments and the current directory *is* the root of a Git repository, all supported files staged as added or modified
will be optimized and then automatically re-staged.  

This script is a valid `pre‑commit` hook and will do the above if run by Git.


Targeted Usage
--------------
If executed with positional arguments, those arguments will be treated as files to optimize. Only supported files will
be optimized, other files will be skipped over with a warning.

**NOTE**: As explained above in the Repository Usage section. Specifying files will stop the script from checking for a
Git repository. This means that files will not be re-staged!

If using the Windows script, wildcards in file names are handled automatically.  
If using the POSIX script, the wildcards are expected to be handled by your shell.  
&nbsp;


Configuring
===========
The script can be given named arguments (called "switches" in Windows and "options" in other systems.) to change how it
functions and reads from a config file to allow configuring it in situations where it cannot be given arguments.

###### (From this point forward, if options are mentioned, they will be mentioned by their Windows names followed immediately by their POSIX names.)


Options
-------
The script has several command-line options used to temporarily change the behavior of the script.

Options are handled in the same order they are given to the script.  
This means that `/Y /GENCONFIG`|`--yes --gen-config` and `/GENCONFIG /Y`|`--gen-config --yes` do two different things.

The first will skip confirmation to overwrite a config file while the second will still ask the user to confirm because
the config is being generated before `/Y`|`--yes` is enforced.

To see a list of valid options for the script, use the `/?`|`--help` option.


Config File
-----------
The config file (`.opticonfig` by default) is used to handle default options and file inclusions/exclusions.

Running the script with the `/GENCONFIG`|`--gen-config` option will make the script generate a default config file named
`.opticonfig` without doing anything else.

The default config file can be found in this repository as `default.opticonfig`.  
Refer to the comments in that file for more information on how the config file works.  
&nbsp;


Advanced Information
====================
Exit Codes:
- `0`: Success.
- `1`: Generic error.
- `2`: Missing required shell command.
- `3`: Option caused the script to do nothing to files. (`/?`|`-help`, `/D`|`--dry`, etc.)  
  &nbsp;


Issues
======
Report issues in the issues tab of this repository.  
Issues are expected to have as many details as possible to help narrow the cause of the issue.  
&nbsp;


Contributing
============
Contributions are welcome. There is no `CONTRIBUTING` file yet, just follow the style of the script.  
&nbsp;


License
=======
This script is open-source and distributed under the MIT license.

The tools used by this script are subject to their own licenses. License information for those tools can be found at the
bottom of either script file.
