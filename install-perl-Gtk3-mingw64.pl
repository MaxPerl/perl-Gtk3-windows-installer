#! /usr/bin/env perl

use strict;
use warnings;
use Cwd;
use File::Path;
use POSIX qw(:sys_wait_h);
use Data::Dumper;

our $VERSION = 0.01;

select((select(STDERR),$| = 1)[0]);
select((select(STDOUT),$| = 1)[0]);

die "Wrong OS. Did you start the script from the MSys2 Terminal? Please use the MinGW64 Terminal. Thanks!\n" unless ($^O eq 'MSWin32');

my $script_dir = cwd();
my $build_dir = "$script_dir/perl-Gtk3-Build";
mkdir("$build_dir") or die "Could not create the build directory: $! \n Please remove $script_dir/perl-Gtk3-Build with rm -R \n";

print_welcome_page();

print "Please give the Path to your msys2 environment [default: C:\\msys64] \n";
my $path = <STDIN>;
$path =~ s/\\/\\\\/;
chomp $path;
$path = "C:\\msys64" unless ($path);
# Lösche "\" am Ende
$path =~ s/\\+$//;

print "*----------------------------------------\n";
print "* INSTALLING THE BUILD TOOLCHAIN \n";
print "*----------------------------------------\n";
my $exitcode;
$exitcode = exec_with_progress("pacman -S --needed --noconfirm mingw-w64-x86_64-toolchain autoconf automake libtool make patch mingw-w64-x86_64-libtool >> $script_dir/install.log 2>> $script_dir/error.log");
die " [FAIL]\n", $exitcode/256, ": ERROR at installing toolchain: $!\n" if ($exitcode != 0);
print " [OK]\n\n";

print "*----------------------------------------\n";
print "* INSTALLING NATIVE DEPENDENCIES \n";
print "*----------------------------------------\n";
$exitcode = exec_with_progress("pacman -S --needed --noconfirm mingw-w64-x86_64-gobject-introspection mingw-w64-x86_64-cairo mingw-w64-x86_64-gtk3 >> $script_dir/install.log 2>> $script_dir/error.log");
die "[ FAIL]\n", $exitcode/256, ": ERROR at installing native dependencies: $!\n" if ($exitcode != 0);
print "[ OK]\n\n";

print "*----------------------------------------\n";
print "* INSTALLING PERL DEPENDENCIES \n";
print "*----------------------------------------\n";
print "Running pl2bat on pl2bat";
my $pl2bat = `which pl2bat`;
$pl2bat =~ s/\//\\/g;
$pl2bat = $path . $pl2bat;
$exitcode = system("perl $pl2bat $pl2bat");
warn "    [FAIL]\n", $exitcode/256, ": ERROR at running pl2bat: $!\n" if ($exitcode != 0);
print "    [OK]\n";

print "Installing App::cpanminus";
#$exitcode = exec_with_progress("wget -qO - http://cpanmin.us | perl - --self-upgrade >> $script_dir/install.log 2>> $script_dir/error.log");
$exitcode = exec_with_progress("curl -s -L https://cpanmin.us | perl - App::cpanminus >> $script_dir/install.log 2>> $script_dir/error.log");
die " [FAIL]\n", $exitcode/256, ": ERROR at installing App::cpanminus: $!\n" if ($exitcode != 0);
print " [OK]\n";

print "Installing ExtUtils::Depends and ExtUtils::PkgConfig";
$exitcode = exec_with_progress("cpanm ExtUtils::Depends ExtUtils::PkgConfig >> $script_dir/install.log 2>> $script_dir/error.log");
die " [FAIL]\n", $exitcode/256, ": ERROR at installing Perl Dependencies: $!\n" if ($exitcode != 0);
print " [OK]\n\n";

install_prereq_module('Glib');
install_prereq_module('Cairo');
install_prereq_module('Glib::Object::Introspection');
install_prereq_module('Cairo::GObject');

print "*----------------------------------------\n";
print "* INSTALLING PERL/Gtk3 \n";
print "*----------------------------------------\n";
$exitcode = exec_with_progress("cpanm -n Gtk3 >> $script_dir/install.log 2>> $script_dir/error.log");
die " [FAIL]\n", $exitcode/256, ": ERROR at installing Gtk3: $!\n" if ($exitcode != 0);
print " [OK]\n";


sub install_prereq_module {
	my ($module) = @_;
	if ($module eq 'Glib::Object::Introspection') {
	print "*----------------------------------------\n";
	print "* INSTALLING \U$module \n";
	print "*----------------------------------------\n";
	}
	else {
	print "*--------------------------\n";
	print "* INSTALLING \U$module \n";
	print "*--------------------------\n";
	}
	my $info = `cpanm --info $module`;
	#$info =~ s/\s*$//;
	chomp $info;
	my $link = get_link($info);

	print "Download $module";
	chdir("$build_dir");
	$exitcode = system("wget -q $link >> $script_dir/install.log 2>> $script_dir/error.log");
	die "    [FAIL]\n", $exitcode/256, ": ERROR: Could not download $module: $!\n" if ($exitcode != 0);
	print "    [OK]\n";
	
	print "Extract $module";
	my (undef, $filename) = $info =~ m/(.*)\/(.*)/;
	my $dirname = $filename;
	$dirname =~ s/\.tar\.gz$//;
	$exitcode = system("tar xzf $filename >> $script_dir/install.log 2>> $script_dir/error.log");
	die "    [FAIL]\n", $exitcode/256, ": ERROR: Could not extract $filename: $!\n" if ($exitcode != 0);
	print "    [OK]\n";

	print "Hacking Makefile.PL\n";
	chdir("$build_dir/$dirname") or die "Could not change to $build_dir/$dirname\n";
	make_file_hack();
	print "Hack completed    [OK]\n";
	
	print "Building $module";
	$exitcode = exec_with_progress("dmake >> $script_dir/install.log 2>> $script_dir/error.log");
	die " [FAIL]\n", $exitcode/256, ": ERROR: Could not build $module: $!\n" if ($exitcode != 0);
	print " [OK]\n";
		
	print "Installing $module";
	$exitcode = exec_with_progress("dmake install >> $script_dir/install.log 2>> $script_dir/error.log");
	die " [FAIL]\n", $exitcode/256, ": ERROR: Could not install $module: $!\n" if ($exitcode != 0);
	print " [OK]\n\n";
}

sub make_file_hack {
	my $libs;
	my $unix_style_path = $path;
	$unix_style_path =~ s/^.:\\//;
	open (MAKE, "perl Makefile.PL verbose 2>> $script_dir/error.log |");
	while (my $line = <MAKE>) {
		if ($line =~ m/^\s* LIBS =>/) {
		#$line =~ s/\s*$//;
		chomp $line;
		$libs = $line;
		last;
		}
	} 
	close MAKE;
	chomp $libs;
	$libs =~ s/^\s* LIBS => q\[//;
	$libs =~ s/\]$//;
	my @libs = split(/-L/, $libs);
	shift @libs;

	foreach my $element (@libs) {
		if ( $element =~ m/C:\/$unix_style_path\/mingw64\/lib\s+/ ) {
			$element = ":nosearch -L$element";
		}
		# Hack for Glib::Object::Introspection
		elsif ( $element =~ m/C:\/$unix_style_path\/mingw64\/lib\/\.\.\/lib\s+/ ) {
			$element = ":nosearch -L$element";
		} 
		else {
			$element = ":search -L$element";
		}
		print "LIBS: $element\n";
	}

	system("perl ./Makefile.PL LIBS=\"@libs\" >> $script_dir/install.log 2>> $script_dir/error.log");
}

sub get_link {
	my ($info) = @_;
	my $firstletter = substr($info, 0, 1);
	my $firsttwoletters = substr($info, 0, 2);
	my $link = "https://cpan.metacpan.org/authors/id/$firstletter/$firsttwoletters/$info";
	return $link;
}

sub exec_with_progress {
	my ($command) = @_;
	
	pipe(READER, WRITER);
	select((select(WRITER),$| = 1)[0]);
	
	my $pid = fork();
	die "Could not fork: $!\n" unless (defined $pid);
	
	if ($pid == 0) {
		# child only writes, therefore close READER
		close READER;
		
		my $exitcode = system ("$command");
		
		print WRITER $exitcode;
		close WRITER;
		
		exit(0);
	}
	else {
		# parent process only reads, therefore close WRITE
		close WRITER;
		
		# output the progress indicator
		while (! waitpid($pid, WNOHANG) ) {
			print ".";
			sleep 3;
		}
		
		# reads the output of the child
		my $exitcode;
		while (my $line = <READER>) {
			chomp $line;
			$exitcode = $line;
		}
		
		close READER;
		return $exitcode;
	}
	
}

sub print_welcome_page {
	print "Welcome to the Perl/Gtk3 Installer for Mingw64/MSys2 on Windows\n";
	print "*--------------------------------------------------------------*\n";
	print "This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself. This software comes with NO WARRANTY of any kind. This script is heavily inspired by the work of Zakariyya Mughal and especially his extraordinary desciption of the installation of curie on Windows. \n\n";

	print "Please note that you need a complete installed MSys2 environment with perl installed. Therefore you should do the following steps before running this script:\n\n";

	print "1) Download and install the installer from https://msys2.github.io/ \n";
	print "2) Start the MinGW64 Terminal \n";
	print "3) Run update-core \n";
	print "4) Close (X or Alt-4) and restart the MinGW64 Terminal \n";
	print "5) Run pacman -Suu (and if needed/the program asked for close the terminal) \n\n";

	print "NOTE that you can get the following warning: \n";
	print "the shell starting scripts have been unified. Please update your shortcuts to the following targets, otherwise they will STOP WORKING:\n";
	print "   \* MSYS2_ROOT\\msys2_shell.cmd -mingw32\n";
	print "   \* MSYS2_ROOT\\msys2_shell.cmd -mingw64\n";
	print "   \* MSYS2_ROOT\\msys2_shell.cmd -msys\n\n";

	print "6) Therefore if needed update your shortcuts\n";
	print "7) Repeat step 5 until nothing is to update anymore\n";
	print "8) Install perl with pacman -S --needed --noconfirm mingw-w64-x86_64-perl\n\n";

	print "If you followed these steps, press <ENTER> to start the installation!\n";
	print "Otherwise exit the program with Ctrl-C!\n";
	<STDIN>;
}

# With this function you can easyils install the perl module XML::Parser::Expat
# This is NOT necessary for installing the perl/Gtk3 module and usually superfluous
# But for installing "curie" (whose installation process was the inspiration for this script) # this would be necessary, so that this function is still here for compatibility reasons
sub install_xml_parser_expat {
	my $module = "XML::Parser::Expat";
	print "*----------------------------------------\n";
	print "* INSTALLING \U$module \n";
	print "*----------------------------------------\n";

	my $info = `cpanm --info $module`;
	chomp $info;
	my $link = get_link($info);

	print "Download $module";
	chdir("$build_dir");
	$exitcode = system("wget -q $link >> $script_dir/install.log 2>> $script_dir/error.log");
	die "    [FAIL]\n", $exitcode/256, ": ERROR: Could not download $module: $!\n" if ($exitcode != 0);
	print "    [OK]\n";
	
	print "Extract $module";
	my (undef, $filename) = $info =~ m/(.*)\/(.*)/;
	my $dirname = $filename;
	$dirname =~ s/\.tar\.gz$//;
	$exitcode = system("tar xzf $filename >> $script_dir/install.log 2>> $script_dir/error.log");
	die "    [FAIL]\n", $exitcode/256, ": ERROR: Could not extract $filename: $!\n" if ($exitcode != 0);
	print "    [OK]\n";

	print "Hacking Makefile.PL\n";
	chdir("$build_dir/$dirname") or die "Could not change to $build_dir/$dirname\n";
	system("perl ./Makefile.PL EXPATLIBPATH=\"$path\\mingw64\\lib\" EXPATINCPATH=\"$path\\mingw64\\include\" >> $script_dir/install.log 2>> $script_dir/error.log");
	print "Hack completed    [OK]\n";
	
	print "Building $module";
	$exitcode = exec_with_progress("dmake >> $script_dir/install.log 2>> $script_dir/error.log");
	die " [FAIL]\n", $exitcode/256, ": ERROR: Could not build $module: $!\n" if ($exitcode != 0);
	print " [OK]\n";
	
	print "Testing $module";
	$exitcode = exec_with_progress("dmake test >> $script_dir/install.log 2>> $script_dir/error.log");
	die " [FAIL]\n", $exitcode/256, ": ERROR: Could not build $module: $!\n" if ($exitcode != 0);
	print " [OK]\n";
		
	print "Installing $module";
	$exitcode = exec_with_progress("dmake install >> $script_dir/install.log 2>> $script_dir/error.log");
	die " [FAIL]\n", $exitcode/256, ": ERROR: Could not install $module: $!\n" if ($exitcode != 0);
	print " [OK]\n\n";
}

#END {
#	chdir($script_dir);
#	print "Räume auf! \n";
#	rmtree($build_dir);
#}
