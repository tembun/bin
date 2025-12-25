#!/usr/local/bin/perl

#
# hnt -- manage hint (.hnt) files.
#

use File::Basename;

my $progname = basename($0, ".pl");
my $file = $ARGV[0];
my $getidx;
my $getmod = 0;
my $append_mode = 0;

my sub err {
	my $args = join(" ", @_);
	die "$progname: " . $args . "\n";
}

my sub usage {
	print STDERR "usage: $progname file [entry_index]\n",
	    "       $progname file [-a title]\n";
	exit 2;
}

my sub append_mode {
	my $title = $ARGV[2];
	
	$title or usage();
	
	# Open file for both reading and writing.
	open(\*HNTFILE, "+<", "$file") or err "Can't open file $file: $!";
	
	#
	# Reading two last characters from the target file in order to decide
	# whether or not should we add some newlines in there.
	#
	my $last_two_chars;
	seek HNTFILE, -2, 2;
	read HNTFILE, $last_two_chars, 2;
	
	#
	# If there are not enough newlines in the end of file already, we
	# insert as much as we need.
	#
	if ($last_two_chars ne "\n\n") {
		my $append_newlines = "\n";
		
		if (substr($last_two_chars, -1) ne "\n") {
			$append_newlines .= "\n";
		}
		print HNTFILE "$append_newlines";
	}
	print HNTFILE "$title\n";
	
	while (my $line = <STDIN>) {
		#
		# We're doing a trick: first chomp the line, which would remove
		# the trailing newline, and then print the line into file with
		# a newline explicitly specified. It helps us to keep newline
		# in the end even if standard input doesn't include it.
		#
		chomp ($line);
		print HNTFILE "\t$line\n";
	}
	close (HNTFILE);
}

my sub read_mode {
	if ($append_mode and $getidx eq 0) {
		err "Entry index can't be 0";
	}
	open(FILE, $file) or err "Can't open $file: $!";
	my %table;
	my $title;
	my $idx = 0;
	while (my $line = <FILE>) {
		# Chomp the line for the same trick as in &append_mode.
		chomp ($line);
		
		my $frstch = substr($line, 0, 1);
		if ($frstch eq "") { next };
		if ($frstch ne "\t") {
			if ($getmod && $getidx == $idx) {
				print "$table{$title}";
				exit 0;
			}
			$idx++;
			$title = $line;
			if (!$getmod) {
				print "$idx: $title\n";
			}
			$table{$title} = "";
		} else {
			$line =~ s/^[\t]*//m;
			$table{$title} .= "$line\n";
		}
	}
	
	if ($getmod) {
		if ($getidx != $idx) {
			err "Wrong entry index specified";
		}
		else {
			print "$table{$title}";
		}
	}
}


if (!$file) {
	system("ls *.hnt |sed 's/\.hnt//' |column");
	exit 0;
}

! -f $file and $file .= ".hnt";

if ($ARGV[1] eq "-a") {
	$append_mode = 1;
}
else {
	$getidx = $ARGV[1];
	$getmod = $getidx ne "";
}

if ($append_mode) {
	append_mode();
}
else {
	read_mode();
}
