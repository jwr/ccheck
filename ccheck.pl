#!/usr/bin/perl

## ccheck.pl: Consistency checker for file archives
## Written by Jan Rychter <jan@rychter.com>
## https://jan.rychter.com/

use strict;
use warnings;

use IO::File;
use File::Find;
use Digest::SHA;
use Getopt::Long;

my $alg = qw(sha256);			# SHA-256 should be enough.

# Command-line parsing and usage information

my $force = 0;
my $verbose = 0;
my $sign = 1;

sub print_usage {
	print STDERR "ccheck.pl: Consistency checker for file archives\n\n";
	print STDERR "Usage: ccheck.pl [--force/-f] [--nosign] [--verbose/-v] directory\n";
	print STDERR "\nOptions:\n";
	print STDERR "    --force/-f: ignore existing database files and re-generate all checksums\n";
	print STDERR "    --nosign: disable signing and ignature checking (not recommended)\n";
	print STDERR "    --verbose/-v: print a line for each checksummed file to indicate progress\n";
	exit(1);
}

GetOptions('force' => \$force,
		   'verbose' => \$verbose,
		   'sign!' => \$sign)
	or print_usage();

# Directory that we will be computing checksums for
my $directory_name = $ARGV[0];
if(!$directory_name) { print_usage(); }
chomp $directory_name;

# The filename of our checksum database
my $db_filename = $directory_name;
$db_filename =~ s#/##;			# Remove possible trailing slash.
$db_filename .= ".ccheck";

# Do we have a checksum database next to the directory?
my $checksums_exist = 0;
if(-f $db_filename) {
	$checksums_exist = 1;
}

# Do we have a signature?
my $signature_filename = $db_filename . ".sig";
my $signature_exists = 0;
if($sign && -f $signature_filename) {
	# If we are forcing re-generation, we might as well remove the signature immediately. Also, in this case
	# we do not set $signature_exists, pretending it never existed in the first place.
	if($force) {
		unlink $signature_filename;
	} else {
		$signature_exists = 1;
	}
}

# Verify the signature
if($sign && $signature_exists) {
	print "Existing checksum database found, checking signature...\n";
	my $status = system("gpg --batch --verify \"$signature_filename\" \"$db_filename\"");
	if($status != 0) {
		print "WARNING: invalid signature (or unable to check signature), aborting.\n";
		exit(1);
	}
}

sub read_checksums {
	my ($checksum_filename) = @_;
	my $input = IO::File->new("<$checksum_filename");
	my %checksums;
	for my $line (<$input>) {
		chomp $line;
		my ($filename, $checksum) = ($line =~ m/^(.*)\s([^\s]+)$/);
		$checksums{$filename} = $checksum;
	}
	close $input;
	return %checksums;
}

sub compute_file_digest {
	my $sha = Digest::SHA->new($alg);
	$sha->addfile($_);
	return $sha->hexdigest;
}

my %db_checksums;				# Our existing checksum database.

## If there is a checksum file, read it, but only if re-generation isn't forced:
if($checksums_exist && !$force) {
	%db_checksums = read_checksums($db_filename);
}

my %actual_checksums;			# These will be the checksums computed from actual files.
sub checksum_file {
	return unless -f;
	if($verbose) { print "Checksumming " . $_ . "\n"; }
	my $digest = compute_file_digest($_);
	$actual_checksums{$_} = $digest;
	return;
}

print "Computing checksums for all files...\n";
find({wanted => \&checksum_file, no_chdir => 1}, $directory_name);

if(keys(%actual_checksums) == 0) {
	print STDERR "No files found, exiting!\n";
	exit(1);
}

my $mismatch_found = 0;
my $new_files_found = 0;
my $missing_files = 0;

unless($force) {
	# check if all files exist and their checksums match
	for my $f (keys %db_checksums) {
		if(!$actual_checksums{$f}) {
			print "WARNING: missing file: " . $f . " " . $db_checksums{$f} . "\n";
			$missing_files = 1;
		} else {
			if($actual_checksums{$f} ne $db_checksums{$f}) {
				print "WARNING: checksum mismatch: " . $f . "\n  stored: " . $db_checksums{$f} . "\n  actual: " . $actual_checksums{$f} . "\n";
				$mismatch_found = 1;
			}
		}
	}
}

if($checksums_exist && !$mismatch_found && !$missing_files && !$force) {
	print "All checksums OK, " . keys(%db_checksums) . " files checked.\n";
}

unless($force) {
	for my $f (keys %actual_checksums) {
		if(!$db_checksums{$f}) {
			print "New file: " . $f . "\n";
			$new_files_found = 1;
		}
	}
}

my $output_filename = $db_filename;

my $something_went_wrong = ($mismatch_found || $new_files_found || $missing_files);

if(!$force && $something_went_wrong && $checksums_exist) {
	$output_filename .= ".actual";
	print "Not overwriting " . $db_filename . ", writing actual checksums to " . $output_filename . "\n";
	print "  you might want to: diff -u " . $db_filename . " " . $output_filename . "\n";
	print "  if everything is OK: mv $output_filename $db_filename; rm $signature_filename; gpg --detach-sign $db_filename\n";
}

if($force || $something_went_wrong || !$checksums_exist) {
	my $output_fh = IO::File->new(">$output_filename");
	foreach my $f (sort keys %actual_checksums) {
		print $output_fh $f . " " . $actual_checksums{$f} . "\n";
	}
	close $output_fh;
}

# Either we didn't find any checksums when we started, or we did and everything went fine, but we found no
# signature.
if($sign && ($force || !$checksums_exist || ($checksums_exist && !$something_went_wrong && !$signature_exists))) {
	print "Signing checksums...\n";
	my $status = system("gpg --detach-sign \"$output_filename\"");
	if($status != 0) {
		print "WARNING: signing failed!\n";
		exit(1);
	}
}

if($something_went_wrong) {
	exit(1);
} else {
	exit(0);
}
