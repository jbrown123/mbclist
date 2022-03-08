#!/usr/bin/env perl

# script to merge ScoutNET and ScoutBook data and generate email dataset
use Getopt::Std;

getopts('aD');

Usage() unless ($#ARGV == 1);

$people = $ARGV[0];
$badges = $ARGV[1];

warn "Loading badges from $badges\n\n";

# these fields are required
@badgesRequired = (
	'BSAMemberID',
    'First Name',
    'Last Name',
	'Email',
    'YPTExpiryDate',
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
}
close(BADGES);


@peopleRequired = (
    'Person ID',
    'First Name',
    'Last Name',
    'Other Reg  District Name',
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

print "BSAID\tFirst name\tLast name\tEmail\tPhone\tYPT Expiry\tDistrict\tMerit badges\n";

for (values %people)
{
    @p = split(/\t/);

    if (!exists $badges{$p[$peopleFields{'Person ID'}]})
    {
        warn "Missing badges entry for $_\n\n";
        $errors{"Missing badges entry"}++;

		$mbs = '';
		$ypt = 'unknown';
		$email = '';
		$district = '';
		$phone = '';
    }
	else
	{
		@b = split(/\t/, $badges{$p[$peopleFields{'Person ID'}]});

	    $b[$badgeFields{'Merit Badges'}] =~ s/"//g;    # remove surrounding quotes

	    # deal with the ScoutBook braintrust using commas to separate data with embedded commas
	    $b[$badgeFields{'Merit Badges'}] =~ s/Signs, Signals, and Codes/Signs Signals and Codes/ig;    # remove bogus commas
	    $b[$badgeFields{'Merit Badges'}] =~ s/\s*,\s*/|/g;    # replace comma with vertical bar (as it should have been anyway)
	    $b[$badgeFields{'Merit Badges'}] =~ s/Signs Signals and Codes/Signs, Signals, and Codes/ig;    # restore commas

	    $mbs = $b[$badgeFields{'Merit Badges'}];

		$ypt = $b[$badgeFields{'YPTExpiryDate'}];
		$ypt = $ypt =~ /^\s*$/ ? 'unknown' : $ypt;

		$district = $p[$peopleFields{'Other Reg  District Name'}];
		$district = $district =~ /^\s*$/ ? 'unknown' : $district;

		$phone = $p[$peopleFields{'Phone No'}];

		$email = $b[$badgeFields{'Email'}];
		$email =~ s/\s+//g;
		$pemail = $p[$peopleFields{'Registrant Home E-Mail'}];
		$pemail =~ s/\s+//g;

		$email = '' if ($email =~ /\@scoutbook.com/i);	# scoutbook puts some form of changeme@scoutbook.com sometimes

		if ($email ne '' && $pemail ne '' && lc($email) ne lc($pemail))
		{
			warn "Email mismatch ($email vs $pemail) for $_\n\n";
			$errors{"Email mismatch"}++;
			$email = "$email,$pemail";	# send to both
		}
	}

	$bsaid = $p[$peopleFields{'Person ID'}];
    $fname = $p[$peopleFields{'First Name'}];
	$lname = $p[$peopleFields{'Last Name'}];
	$email = $email ne '' ? $email : $p[$peopleFields{'Registrant Home E-Mail'}];

	if ($email =~ /^\s*$/)
	{
		warn "Missing email for $_\n\n";
		$errors{"Missing email"}++;
		next unless ($opt_a);
	}

	print "$bsaid\t$fname\t$lname\t$email\t$phone\t$ypt\t$district\t$mbs\n";
    $outputCount++;
}

# check for badges entry without a corresponding people entry
for (keys %badges)
{
    if (! exists $people{$_})
    {
        warn "Missing person entry for $badges{$_}\n\n";
        $errors{"Missing person entry"}++;

		@b = split(/\t/, $badges{$_});

	    $b[$badgeFields{'Merit Badges'}] =~ s/"//g;    # remove surrounding quotes

	    # deal with the ScoutBook braintrust using commas to separate data with embedded commas
	    $b[$badgeFields{'Merit Badges'}] =~ s/Signs, Signals, and Codes/Signs Signals and Codes/ig;    # remove bogus commas
	    $b[$badgeFields{'Merit Badges'}] =~ s/\s*,\s*/|/g;    # replace comma with vertical bar (as it should have been anyway)
	    $b[$badgeFields{'Merit Badges'}] =~ s/Signs Signals and Codes/Signs, Signals, and Codes/ig;    # restore commas

	    $mbs = $b[$badgeFields{'Merit Badges'}];
		$ypt = $b[$badgeFields{'YPTExpiryDate'}];
		$ypt = $ypt =~ /^\s*$/ ? 'unknown' : $ypt;

		$district = 'unknown';
		$phone = '';

		$bsaid = $b[$badgeFields{'BSAMemberID'}];
	    $fname = $b[$badgeFields{'First Name'}];
		$lname = $b[$badgeFields{'Last Name'}];
		$email = $b[$badgeFields{'Email'}];
		$email = '' if ($email =~ /\@scoutbook.com/i);

		if ($email =~ /^\s*$/)
		{
			warn "Missing email for $badges{$_}\n\n";
			$errors{"Missing email"}++;
			next unless ($opt_a);
		}

		print "$bsaid\t$fname\t$lname\t$email\t$phone\t$ypt\t$district\t$mbs\n";
	    $outputCount++;
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

sub Usage
{
    die <<EOS;
Usage: $0 [-D] person.tsv mblist.tsv
    person.tsv = tab seperated list of people from ScoutNET
    mblist.tsv = tab separated list of MBCs from ScoutBook

    options:
	-a     : return all entries, even ones without an email address
    -D     : turn on debug messages
EOS
}
