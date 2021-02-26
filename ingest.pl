#!/usr/bin/env perl

# script to merge ScoutNET and ScoutBook data and generate JSON data.
use Getopt::Std;

getopts('e:D'); # warn about excessive MB, Debug output

Usage() unless ($#ARGV == 1);

$people = $ARGV[0];
$badges = $ARGV[1];

warn "Loading badges from $badges\n\n";

open(BADGES, '<', $badges) or die $!;
# BSA Member ID     First Name  Last Name   Merit Badges
# 0                 1           2           3
while (<BADGES>)
{
    chomp;
    next if (/^\s*$/); # skip blank lines

    @f = split(/\t/);
    if ($. == 1)
    {
        die "Improper badges file format $_\n\n" if ($#f != 3 || $f[0] !~ /BSA Member ID/i || $f[3] !~ /Merit Badges/i);
        next;
    }

    if ($f[0] !~ /\d+/)
    {
        warn "Invalid badges entry $_\n\n";
        $errors{"Invalid badges entry"}++;
        next;
    }

    if (exists $badges{$f[0]})
    {
        warn "Duplicate badges entry for $_\n\tprev: $badges{$f[0]}\n\n";
        $errors{"Duplicate badges entry"}++;
    }

    $badges{$f[0]} = $_;

    if ($opt_e && scalar(split(/\t/, $f[3])) > $opt_e)
    {
        warn "Excessive badges for $_\n\n";
        $errors{"Excessive badges"}++;
    }
}
close(BADGES);



warn '=' x 20 . "\nLoading people from $people\n";
open(PEOPLE, '<', $people) or die $!;
# Person ID  	First Name	Middle Name	Last Name	Address 1 	City	State	Zip Code	County	Other Reg  District No 	Other Reg  District Name	Other Reg  Position	Phone Type 	Phone No 	Registrant Home E-Mail
# 0             1           2           3           4           5       6       7           8       9                       10                          11                  12          13          14
while (<PEOPLE>)
{
    chomp;
    next if (/^\s*$/); # skip blank lines

    @f = split(/\t/);
    if ($. == 1)
    {
        die "Improper people file format $_\n\n" if ($#f != 14 || $f[0] !~ /Person ID/i);
        next;
    }

    if ($f[0] !~ /\d+/)
    {
        warn "Invalid person entry $_\n\n";
        $errors{"Invalid person entry"}++;
        next;
    }

    if (exists($people{$f[0]}))
    {
        warn "Duplicate person entry for $_\n\tprev: $people{$f[0]}\n\n";
        $errors{"Duplicate person entry"}++;
        next;
    }

    $people{$f[0]} = $_;
}
close(PEOPLE);

warn '=' x 20 . "\nMerging data\n";

for (values %people)
{
    @f = split(/\t/);

    if (!exists $badges{$f[0]})
    {
        warn "Missing badges entry for $_\n\n";
        $errors{"Missing badges entry"}++;
        next;
    }

    @b = split(/\t/, $badges{$f[0]});

    $b[3] =~ s/"//g;    # remove surrounding quotes

    # deal with the ScoutBook braintrust using commas to separate data with embedded commas
    $b[3] =~ s/Signs, Signals, and Codes/Signs Signals and Codes/ig;    # remove bogus commas
    $b[3] =~ s/\s*,\s*/\t/g;    # replace comma with tab (as it should have been anyway)
    $b[3] =~ s/Signs Signals and Codes/Signs, Signals, and Codes/ig;    # restore commas

    $mbs = '"' . join('","', split(/\t/, $b[3])) . '"';

    print <<EOS;
    {
        name: "${\( ($f[2] =~ /^\s*$/) ? "$f[1] $f[3]" : "$f[1] $f[2] $f[3]" )}",
        address: "$f[4]",
        city: "$f[5]",
        state: "$f[6]",
        zip: "$f[7]",
        phone: [{type: "$f[12]", number: "$f[13]"}],
        email: "$f[14]",
        district: "$f[10]",
        bsaid: "$f[0]",
        meritbadges: [$mbs],
        workwith: "unknown"
    },
EOS
}

# check for badges entry without a corresponding people entry
for (keys %badges)
{
    if (! exists $people{$_})
    {
        warn "Missing person entry for $badges{$_}\n\n";
        $errors{"Missing person entry"}++;
    }
}

warn '=' x 20 . "\nError counts\n";
for (sort keys %errors)
{
    warn "\t$_: $errors{$_}\n";
}

sub Usage
{
    die <<EOS;
Usage: $0 [-eD] person.tsv mblist.tsv
    person.tsv = tab seperated list of people from ScoutNET
    mblist.tsv = tab separated list of MBCs from ScoutBook

    options:
    -e <n> : warn about excessive merit badges, more than <n>
    -D     : turn on debug messages
EOS
}
