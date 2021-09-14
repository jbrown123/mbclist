#!/usr/bin/env perl

# script to insert files into a source file

$source = 'maptest.html';
$output = 'maplive.html';

open(SOURCE, '<', $source) or die $!;
open(OUTPUT, '>', $output) or die $!;

print "Reading $source -> $output\n";

while (<SOURCE>)
{
    print OUTPUT $_;

    if (/\{\{\s*include:\s*(\S+)\s*(?:filter:\s*(\S+)\s*)?\}\}/)
    {
        my $filename = $1;
        my $filter = $2;
        print "Inserting $filename" . ($filter ? " with filter $filter" : '') . "\n";
        open(INSERT, '<', $filename) or die $!;
        while (<INSERT>)
        {
            next if ($filter && !/$filter/);
            print OUTPUT $_;
        }
        close(INSERT);
    }
}

close(OUTPUT) || die $!;

close(SOURCE);

print "$output complete\n";
