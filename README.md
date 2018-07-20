# ccheck: Consistency Checker

ccheck is a simple, easy to use, minimal consistency checker. It computes checksums for collections of files (a directory and all its subdirectories), and stores them with a digital signature. Afterwards, it can verify the collection, alerting the user to any changes (file modifications, additions or deletions).

ccheck tries to do as little as possible, delegating to other tools when needed.

SHA-256 is used for checksumming.

## Rationale

Computers and their storage are unreliable. Bits can get flipped, both in RAM and on various storage media, and our data can become corrupted. It's easy to notice that large amounts of data have gone missing, but much more difficult to detect a flipped bit here and there. And yet, sometimes a flipped bit or two could be the difference between a readable file and an irreversibly corrupted one.

This problem becomes even more important if you think about long-term replicated data storage. The probability of bitrot becomes higher, and you need to know which replica has the correct data.

There are tools out there that compute file checksums. There are filesystems that take data integrity into account. You could use GnuPG to produce digital signatures and keep them alongside the files. You could use tools that recursively traverse a directory tree and produce checksums for all files. However, I've found all of these tools to be lacking, and I wanted an independent tool to verify the consistency of my archives.

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

## License

MIT. I believe in freedom, which means I believe in letting you do whatever you want with this code.

## Prerequisites

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

The options are pretty much self-explanatory.

## Examples

Let's say we want to checksum a directory containing a single file:

```
> ccheck.pl Photos
Computing checksums for all files...
New file: Photos/IMG_6439.jpg
Signing checksums...
gpg: using "0x49248F8CF128664B" as default secret key for signing
>
```

This will create two additional files next to our directory:

```
drwxr-xr-x   3 jwr  jwr   96 Jul 20 19:23 Photos
-rw-r--r--   1 jwr  jwr   85 Jul 20 19:23 Photos.ccheck
-rw-r--r--   1 jwr  jwr  566 Jul 20 19:24 Photos.ccheck.sig
```

`Photos.ccheck` contains the checksums:

```
Photos/IMG_6439.jpg 8e0f493d2c1a37d62a780f7418d9f95c1334982eb573dd2984d9dbf729b13108
```

while Photos.ccheck.sig is a signature of `Photos.ccheck` produced by GnuPG.

To check the integrity of your data, just run ccheck again with the directory name as argument. This will check the signature, compute all checksums and produce this output if everything is OK:

```
All checksums OK, 1 files checked.
```

Note that checksumming might take a long time in case of large file collections.

If files are modified in anyway, this is what will happen upon the next check:

```
> ccheck.pl Photos
Existing checksum database found, checking signature...
gpg: Signature made Fri Jul 20 19:23:36 2018 CEST
gpg:                using RSA key 2CA499D999976465AD4342909110F66870F631E0
gpg: Good signature from "Jan Rychter <jan@rychter.com>" [ultimate]
Primary key fingerprint: E9BE DD37 5BBB 250F CE65  866F 4924 8F8C F128 664B
	 Subkey fingerprint: 2CA4 99D9 9997 6465 AD43  4290 9110 F668 70F6 31E0
Computing checksums for all files...
WARNING: checksum mismatch: Photos/IMG_6439.jpg
  stored: 8e0f493d2c1a37d62a780f7418d9f95c1334982eb573dd2984d9dbf729b13108
  actual: 8ad6e14d51c0be2190927ff6645b44a60f8d501fb7bf58584b43c5ef58d5f7d9
Not overwriting Photos.ccheck, writing actual checksums to Photos.ccheck.actual
  you might want to: diff -u Photos.ccheck Photos.ccheck.actual
  if everything is OK: mv Photos.ccheck.actual Photos.ccheck; rm Photos.ccheck.sig; gpg --detach-sign Photos.ccheck
>
```

ccheck will also tell you about new files:

```
> ccheck.pl Photos
Existing checksum database found, checking signature...
gpg: Signature made Fri Jul 20 19:23:36 2018 CEST
gpg:                using RSA key 2CA499D999976465AD4342909110F66870F631E0
gpg: Good signature from "Jan Rychter <jan@rychter.com>" [ultimate]
Primary key fingerprint: E9BE DD37 5BBB 250F CE65  866F 4924 8F8C F128 664B
	 Subkey fingerprint: 2CA4 99D9 9997 6465 AD43  4290 9110 F668 70F6 31E0
Computing checksums for all files...
All checksums OK, 1 files checked.
New file: Photos/new-file
Not overwriting Photos.ccheck, writing actual checksums to Photos.ccheck.actual
  you might want to: diff -u Photos.ccheck Photos.ccheck.actual
  if everything is OK: mv Photos.ccheck.actual Photos.ccheck; rm Photos.ccheck.sig; gpg --detach-sign Photos.ccheck
>
```

if the new files were added on purpose, just perform the steps in the instructions printed on screen.

## Limitations

ccheck expects the world to be in UTF-8. If your filenames are not UTF-8, things will likely break.

ccheck needs to compute the checksums for all files before telling you anything about the integrity of your data. This could take a long time for large archives, especially if they are network-mounted. Use the `--verbose` option to see progress, but remember that each line printed does not indicate that the checksum matches, just that the checksum was computed. Actual comparison takes place at the end, once ccheck has the checksums for all files.
