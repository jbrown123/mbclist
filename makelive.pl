#!/usr/bin/env perl

# script to insert demo files into mbclist.html to produce the demo version for GH pages

open(MBCLIST, '<', 'mbclist.html') or die $!;
open(INDEX, '>', 'live.html') or die $!;

print "Reading mbclist.html -> live.html\n";

while (<MBCLIST>)
{
    print INDEX $_;

    if (/\{\{\s*include:\s*(\S+)\s*\}\}/)
    {
        my $filename = $1;
        $filename =~ s/demo-mbc.json/live-mbc.json/i;

        print "Inserting $filename\n";
        open(INSERT, '<', $filename) or die $!;
        print INDEX $_ while (<INSERT>);
        close(INSERT);
    }
}

close(INDEX) || die $!;

close(MBCLIST);

print "live.html complete\n";

@t = localtime();

$t[4]++;    # month 0-11
$t[5] += 1900;  # year since 1900

$dateString = sprintf("%4d%02d%02d.%02d%02d", $t[5], $t[4], $t[3], $t[2], $t[1]);

print "Date string: $dateString\n";

print "Encrypting live.html -> live-index.html\n";

$password = `perl passgen.pl`;

print `staticrypt live.html $password -e -o live-index.html -t "Merit Badge Counselor List" -i "Enter the password for v$dateString"`;

print "live-index.html complete (v$dateString pw:$password)\n";
