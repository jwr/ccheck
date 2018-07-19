# ccheck: Consistency Checker

ccheck.pl is a simple, easy to use, minimal consistency checker. It computes checksums for collections of files (a directory and all its subdirectories), and stores them with a digital signature. Afterwards, it can verify the collection, alerting the user to any changes (file modifications, additions or deletions).

ccheck tries to do as little as possible, delegating to other tools when needed.

SHA-256 is used for checksumming.

## Motivation

Computers and their storage are unreliable. Bits can get flipped, both in RAM and on various storage media, and our data can become corrupted. It's easy to notice that large amounts of data have gone missing, but much more difficult to detect a flipped bit here and there. And yet, sometimes a flipped bit or two could be the difference between a readable file and an irreversibly corrupted one.

This problem becomes even more important if you think about long-term replicated data storage. The probability of bitrot becomes higher, and you need to know which replica has the correct data.

There are tools out there that compute file checksums. There are filesystems that take data integrity into account. You could use GnuPG to produce digital signatures and keep them alongside the files. You could use tools that recursively traverse a directory tree and produce checksums for all files. However, I've found all of these tools to be lacking.

## Requirements

I needed a tool that would fulfill these requirements:

* simple and easy to use
* as few dependencies as possible
* viable in the long term (10 years at least)
* open formats, so that checksums can still be read even if the tool doesn't work anymore
* works with large collections of files
* recursively traverses all subdirectories
* stores data in one or two files alongside the scanned directory
* makes it easy to cryptographically sign the checksum database using GnuPG
* easy to regenerate checksums in case the contents changes

## Pre-requisites

* Perl with the following modules: `IO::File, File::Find, Digest::SHA, Getopt::Long`
* GnuPG for signing and verifying signatures

## Usage

```
Usage: ccheck.pl [--force/-f] [--nosign] [--verbose/-v] directory
Options:
	--force/-f: ignore existing database files and re-generate all checksums
	--nosign: disable signing and ignature checking (not recommended)
	--verbose/-v: print a line for each checksummed file to indicate progress
```
