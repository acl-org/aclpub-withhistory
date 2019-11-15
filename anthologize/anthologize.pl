#!/usr/bin/perl

# Usage: anthologize.pl proceedings anthology
#
# - <proceedings> is the input directory generated by ACLPUB,
#   containing meta and cdrom/.
# - <anthology> is the output directory (which will be created if
#   necessary)
#
# This script creates copies in the output directory for all
# content that will be exported to the ACL Anthology.
#
# Everything is built entirely from meta and cdrom/, using no other
# files. So if the meta and bib files have been hand-edited, then the
# Anthology will follow those edits.

use strict 'vars';

use File::Spec;
use File::Copy;
use File::Path qw(make_path);

die "usage: anthologize.pl <proceedings> <anthology>"
    unless (@ARGV == 2);
my ($proceedings,$anthology) = @ARGV;

my $verbose = 0;

my ($abbrev, $year, $bib_url);
open(META, "$proceedings/meta") || die "couldn't read meta file";
while (<META>) {
    chomp;
    # clean up after windows users
    $_ =~ s/\R//g;
    $abbrev = $1 if (/^abbrev\s+(.*)/);
    $year = $1 if (/^year\s+(.*)/);
    $bib_url = $1 if (/^bib_url\s+(.*)/);
}
close(META);

$bib_url =~ m{^https?://www.aclweb.org/anthology/([A-Z])(\d\d)-(\d+)%0(\d+)d} ||
    die "couldn't extract volume id and number from bib_url: $bib_url";
my $venue = $1;
my $yr = $2;
my $volume_no = $3;
my $digits = $4;
my $volume_id = $venue . $yr;
my $volume_idno = "$volume_id-$volume_no";

my $dir = File::Spec->catdir($proceedings, "cdrom");

# anth_dir is the new location, e.g., anthology/N/N18
my $anth_dir = File::Spec->catdir($anthology, $venue, $volume_id);
make_path($anth_dir);

###################################
# Create the volume-level files in this directory,
# e.g., N18-1.bib, a bib database of all papers in the volume
#       N18-1.pdf for the entire volume

my $bib = "$dir/$abbrev-$year.bib";
-f $bib || die "couldn't find $bib\n";
my $bibdst = "$anth_dir/$volume_idno.bib";
copy($bib, $bibdst) || die "couldn't copy $bib to $bibdst";
print STDERR "cp $bib $bibdst\n" if $verbose;

my $pdf = "$dir/$abbrev-$year.pdf";
-f $bib || die "couldn't find $pdf";
my $pdfdst = "$anth_dir/$volume_idno.pdf";
copy($pdf, $pdfdst) || die "couldn't copy $pdf to $pdfdst";
print STDERR "cp $pdf $pdfdst\n" if $verbose;

# iterate through the bib files
for my $bib (glob("$dir/bib/*.bib")) {   # bib entry files in numerically sorted order
    $bib =~ m{.*/([A-Z]\d\d-\d\d\d\d).bib};
    my $src_id = $1;
    substr($1, 0, length($src_id)-$digits) eq $volume_idno || warn "  overriding volume id and number";
    my $paper_no = substr($src_id, length($src_id)-$digits);
    my $dst_id = $volume_idno . $paper_no;
    
    print STDERR "paper ${dst_id}\n" if $verbose;
    
    ###################################
    # Create the paper-level files in this directory
    # i.e., ${anth_prefix}${paper_no}.bib for a bib database of each individual paper in the volume (N18-1000.bib)
    #       ${anth_prefix}${paper_no}.pdf for the individual paper (e.g., N18-1000.pdf)

    # Copy the current .bib file and its corresponding .pdf file into
    # the anthology.

    $bibdst = "$anth_dir/$dst_id.bib";
    copy($bib, $bibdst) || die "couldn't copy $bib to $bibdst";
    print STDERR "  cp $bib $bibdst\n" if $verbose;
    
    my $pdf = "$dir/pdf/$src_id.pdf";
    $pdfdst = "$anth_dir/$dst_id.pdf";
    copy($pdf, $pdfdst) || die "couldn't copy $pdf to $pdfdst";
    print STDERR "  cp $pdf $pdfdst\n" if $verbose;

    for my $att (glob("$dir/additional/${abbrev}${paper_no}_*")) {
        $att =~ m{.*/${abbrev}${paper_no}_(.*)\.(.*)};
        my ($type, $ext) = ($1, $2);
        my $attdst = "$anth_dir/$dst_id.$type.$ext";
        copy($att, $attdst) || die "couldn't copy $att to $attdst";
        print STDERR "  cp $att $attdst\n" if $verbose;
    }
}
