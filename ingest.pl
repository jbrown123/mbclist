#!/usr/bin/env perl

# script to merge ScoutNET and ScoutBook data and generate JSON data.
use Getopt::Std;

getopts('e:y:D'); # warn about excessive MB, want about YPT expiry; Debug output

Usage() unless ($#ARGV == 1);

$people = $ARGV[0];
$badges = $ARGV[1];

warn "Loading badges from $badges\n\n";

# these fields are required
@badgesRequired = (
	'BSAMemberID',
    'First Name',
    'Last Name',
    'YPTExpiryDate',
    'Units',
    'Districts',
    'ListingPreference',
    'Availability',
    'Merit Badges'
);

open(BADGES, '<', $badges) or die $!;
# UserID	BSAMemberID	First Name	Last Name	Email	YPTExpiryDate	Units	Districts	ListingPreference	Availability	Merit Badges
# 0         1           2           3           4       5               6       7           8                   9               10
while (<BADGES>)
{
    chomp;
    next if (/^\s*$/); # skip blank lines

    s/"//g; # remove redundant quotes from all fields

    @f = split(/\t/);
    if ($. == 1)
    {
        # map field names to offsets
		$i = 0;
		for $f (@f)
		{
			$badgeFields{$f} = $i++;
		}

        die "Improper badges file format $_\nRequired: " . join(', ', @badgesRequired) . "\n" unless (Contains(\@f, \@badgesRequired));
        next;
    }

    if ($f[$badgeFields{'BSAMemberID'}] !~ /\d+/)
    {
        warn "Invalid badges entry $_\n\n";
        $errors{"Invalid badges entry"}++;
        next;
    }

    if (exists $badges{$f[$badgeFields{'BSAMemberID'}]})
    {
        warn "Duplicate badges entry for $_\n\tprev: $badges{$f[$badgeFields{'BSAMemberID'}]}\n\n";
        $errors{"Duplicate badges entry"}++;
    }

    if ($f[$badgeFields{'Merit Badges'}] =~ /^\s*$/)
    {
        warn "Empty badges list for $_\n\n";
        $errors{"Empty badges list"}++;
    }

    $badges{$f[$badgeFields{'BSAMemberID'}]} = $_;

    if ($opt_e && scalar(split(/\s*,\s*/, $f[$badgeFields{'Merit Badges'}])) > $opt_e)
    {
        warn "Excessive badges for $_\n\n";
        $errors{"Excessive badges"}++;
    }


    if ($opt_y && $f[$badgeFields['YPTExpiryDate']])
    {
        my $expiry = DateToDays($f[$badgeFields{'YPTExpiryDate'}]);

        my $now = DateToDays();

        if ($expiry < $now)
        {
            warn "YPT expired $_\n\n";
            $errors{"YPT expired"}++;
        }
        elsif ($expiry - $now <= $opt_y)
        {
            warn "YPT expiring $_\n\n";
            $errors{"YPT expiring"}++;
        }
    }
}
close(BADGES);


@peopleRequired = (
    'Person ID',
    'First Name',
    'Middle Name',
    'Last Name',
    'Address 1',
    'City',
    'State',
    'Zip Code',
    'Other Reg  District Name',
    'Phone Type',
    'Phone No',
    'Registrant Home E-Mail'
);

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
        # map field names to offsets
		$i = 0;
		for $f (@f)
		{
            $f =~ s/\s*$//;
			$peopleFields{$f} = $i++;
		}

        die "Improper people file format $_\nRequired: " . join(', ', @peopleRequired) . "\n" unless (Contains(\@f, \@peopleRequired));
        next;
    }

    if ($f[$peopleFields{'Person ID'}] !~ /\d+/)
    {
        warn "Invalid person entry $_\n\n";
        $errors{"Invalid person entry"}++;
        next;
    }

    if (exists($people{$f[$peopleFields{'Person ID'}]}))
    {
        warn "Duplicate person entry for $_\n\tprev: $people{$f[$peopleFields{'Person ID'}]}\n\n";
        $errors{"Duplicate person entry"}++;
        next;
    }

    $people{$f[$peopleFields{'Person ID'}]} = $_;
}
close(PEOPLE);

warn '=' x 20 . "\nMerging data\n";

for (values %people)
{
    @p = split(/\t/);

    if (!exists $badges{$p[$peopleFields{'Person ID'}]})
    {
        warn "Missing badges entry for $_\n\n";
        $errors{"Missing badges entry"}++;
        next;
    }

    @b = split(/\t/, $badges{$p[$peopleFields{'Person ID'}]});

    $b[$badgeFields{'Merit Badges'}] =~ s/"//g;    # remove surrounding quotes

    # deal with the ScoutBook braintrust using commas to separate data with embedded commas
    $b[$badgeFields{'Merit Badges'}] =~ s/Signs, Signals, and Codes/Signs Signals and Codes/ig;    # remove bogus commas
    $b[$badgeFields{'Merit Badges'}] =~ s/\s*,\s*/\t/g;    # replace comma with tab (as it should have been anyway)
    $b[$badgeFields{'Merit Badges'}] =~ s/Signs Signals and Codes/Signs, Signals, and Codes/ig;    # restore commas

    $mbs = '"' . join('","', split(/\t/, $b[$badgeFields{'Merit Badges'}])) . '"';

    $name = ($p[$peopleFields{'Middle Name'}] =~ /^\s*$/) ?
        "$p[$peopleFields{'First Name'}] $p[$peopleFields{'Last Name'}]" :
        "$p[$peopleFields{'First Name'}] $p[$peopleFields{'Middle Name'}] $p[$peopleFields{'Last Name'}]";

    $workwith = $b[$badgeFields{'ListingPreference'}] .
        (($b[$badgeFields{'ListingPreference'}] eq 'Unit') ? " $b[$badgeFields{'Units'}]" :
        ($b[$badgeFields{'ListingPreference'}] eq 'District') ? " $b[$badgeFields{'Districts'}]" : '');

    print <<EOS;
    {
        name: "$b[$badgeFields{'First Name'}] $b[$badgeFields{'Last Name'}]",
        address: "$p[$peopleFields{'Address 1'}]",
        city: "$p[$peopleFields{'City'}]",
        state: "$p[$peopleFields{'State'}]",
        zip: "$p[$peopleFields{'Zip Code'}]",
        phone: [{type: "$p[$peopleFields{'Phone Type'}]", number: "$p[$peopleFields{'Phone No'}]"}],
        email: "$p[$peopleFields{'Registrant Home E-Mail'}]",
        district: "$p[$peopleFields{'Other Reg  District Name'}]",
        bsaid: "$p[$peopleFields{'Person ID'}]",
        meritbadges: [$mbs],
        workwith: "$workwith",
        availability: "$b[$badgeFields{'Availability'}]",
        yptexpiry: "$b[$badgeFields{'YPTExpiryDate'}]"
    },
EOS
    $outputCount++;
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

warn '=' x 20 . "\nTotal records: $outputCount\nError counts\n";
for (sort keys %errors)
{
    warn "\t$_: $errors{$_}\n";
}



# usage Contains (\@haystack, \@needle)
# think of it as @haystack contains @needle
sub Contains
{
    my ($haystack, $needle) = @_;

    my %haystackHash = map {$_ => 1} @{$haystack};

    for (@{$needle})
    {
        return 0 if (!exists($haystackHash{$_}));
    }
    return 1;
}

# a highly simplistic date parser
# expects m/d/yyyy format
# returns (approx) days since 1/1/1970
sub DateToDays
{
    my ($date) = @_;

    # no params = now / today
    if ($date == undef)
    {
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime;
        $date = ($mon+1) . '/' . $mday . '/' . ($year+1900);
    }
                        # 0 J F  M  A  M   J   J   A   S   O   N   D
    my @daysByMonth = qw/0 0 31 59 90 120 151 181 212 243 273 304 334 /;

    my @f = split(/[\/\-\\]/, $date);

    die "Can't understand date $date as @f" if ($#f < 2 || $f[2] < 100 || $f[0] > 12 || $f[1] > 31);

    my ($m, $d, $y) = @f;

    return (($y-1970) * 365 + $daysByMonth[$m] + $d-1);
}

sub Usage
{
    die <<EOS;
Usage: $0 [-eD] person.tsv mblist.tsv
    person.tsv = tab seperated list of people from ScoutNET
    mblist.tsv = tab separated list of MBCs from ScoutBook

    options:
    -e <n> : warn about excessive merit badges, more than <n>
    -y <d> : warn about YPT expiring in 'd' days (default: 45)
    -D     : turn on debug messages
EOS
}
