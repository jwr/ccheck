#!/usr/bin/perl

# Consistency checker

use strict;
use warnings;
use Digest::SHA;
use File::Find;
use IO::File;

my $alg = qw(sha256);			# SHA-256 should be enough
my $db_filename = $ARGV[0];
chomp $db_filename;
# Remove possible trailing slash:
$db_filename =~ s#/##;
$db_filename .= ".ccheck";
my $signature_filename = $db_filename . ".sig";
my $existing_checksums = 0;
my $signature_exists = 0;

if(-f $db_filename) {
	$existing_checksums = 1;
}

if(-f $signature_filename) {
	$signature_exists = 1;
}

if($signature_exists) {
	print "Checking signature...\n";
	my $status = system("gpg --batch --verify $signature_filename $db_filename");
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
		# print $filename . " -> " . $checksum . "\n";
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

## if there is a checksum file, read it
my %db_checksums;

if($existing_checksums) {
	%db_checksums = read_checksums($db_filename);
}

#print Dumper($checksums);
#print "cs: " . $checksums->{"secrets/notes.md.gpg"} . "\n";

my %actual_checksums;

sub checksum_file {
	return unless -f;
	my $digest = compute_file_digest($_);
	$actual_checksums{$_} = $digest;
	#	if($digest) {

	#		print $output_fh $_ . " " . $digest . "\n";
	#	} else {
	#		print "no digest for " . $_ . "\n";
	#	}
}

print "Checksumming files...\n";
find({wanted => \&checksum_file, no_chdir => 1}, @ARGV);
my $mismatch_found = 0;
my $new_files_found = 0;
my $missing_files = 0;

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

if($existing_checksums && !$mismatch_found && !$missing_files) {
	print "All checksums OK, " . keys(%db_checksums) . " files checked.\n";
}

for my $f (keys %actual_checksums) {
	if(!$db_checksums{$f}) {
		print "New file: " . $f . "\n";
		$new_files_found = 1;
	}
}

my $output_filename = $db_filename;

my $something_wrong = ($mismatch_found || $new_files_found || $missing_files);

if($something_wrong && $existing_checksums) {
	$output_filename .= ".actual";
	print "Not overwriting " . $db_filename . ", writing actual checksums to " . $output_filename . "\n";
	print "  you might want to do: diff -u " . $db_filename . " " . $output_filename . "\n";
}

if($something_wrong || !$existing_checksums) {
	my $output_fh = IO::File->new(">$output_filename");
	foreach my $f (sort keys %actual_checksums) {
		print $output_fh $f . " " . $actual_checksums{$f} . "\n";
	}
	close $output_fh;
}

if(!$existing_checksums || ($existing_checksums && !$something_wrong && !$signature_exists)) {
	print "Signing checksums...\n";
	`gpg --detach-sign $output_filename`;
}

if($mismatch_found || $new_files_found || $missing_files) {
	exit(1);
} else {
	exit(0);
}
