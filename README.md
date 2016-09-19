# perl-Gtk3-windows-installer - The Perl/Gtk3 Installer for Mingw64/MSys2 on Windows
A script to easily install the perl Gtk3 module in the MinGW64/MSys2 shell on Windows
## License and Thanks
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself. This software comes with NO WARRANTY of any kind. This script is heavily inspired by the work of Zakariyya Mughal and especially his extraordinary desciption of the installation of curie on Windows.
## Usage
Please note that you need a complete installed MSys2 environment with perl installed. Therefore you should do the following steps before running this script:

1) Download and install the installer from https://msys2.github.io/

2) Start the MinGW64 Terminal

3) Run update-core

4) Close (X or Alt-4) and restart the MinGW64 Terminal

5) Run pacman -Suu (and if needed/the program asked for close the terminal)

NOTE that you can get the following warning:

`the shell starting scripts have been unified. Please update your shortcuts to the following targets, otherwise they will STOP WORKING:`

`   \* MSYS2_ROOT\\msys2_shell.cmd -mingw32`
`   \* MSYS2_ROOT\\msys2_shell.cmd -mingw64`
`   \* MSYS2_ROOT\\msys2_shell.cmd -msys`

6) Therefore if needed update your shortcuts

7) Repeat step 5 until nothing is to update anymore

8) Install perl with pacman -S --needed --noconfirm mingw-w64-x86_64-perl

If you followed these steps, you can open the MinGW64 shell and start the installation process with the command perl ./install-perl-Gtk3-mingw64.pl
