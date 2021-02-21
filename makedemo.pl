#!/usr/bin/env perl

# script to insert demo files into mbclist.html to produce the demo version for GH pages

open(MBCLIST, '<', 'mbclist.html') or die $!;
open(INDEX, '>', 'demo.html') or die $!;

print "Reading mbclist.html -> demo.html\n";

while (<MBCLIST>)
{
    print INDEX $_;

    if (/\{\{\s*include:\s*(\S+)\s*\}\}/)
    {
        my $filename = $1;
        print "Inserting $filename\n";
        open(INSERT, '<', $filename) or die $!;
        print INDEX $_ while (<INSERT>);
        close(INSERT);
    }
}

close(INDEX) || die $!;

close(MBCLIST);

print "demo.html complete\n";

@t = localtime();

$t[4]++;    # month 0-11
$t[5] += 1900;  # year since 1900

$dateString = sprintf("%4d%02d%02d.%02d%02d", $t[5], $t[4], $t[3], $t[2], $t[1]);

print "Date string: $dateString\n";

print "Encrypting demo.html -> index.html\n";

print `staticrypt demo.html trustworthy -e -o index.html -t "Merit Badge Counselor List Demo (v$dateString)" -i "Password is the first point of the Scout law (all lower case)"`;

print "index.html complete\n";
