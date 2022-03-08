#!/usr/bin/env perl

# send emails, slowly, via blat
use Getopt::Std;

getopts('snD');

Usage() unless ($#ARGV == 1);

print '*' x 50 . "\nStarting " . scalar(localtime()) . "\n";


$toemail = $ARGV[0];
$skip = $ARGV[1];

# these fields are required
@emailRequired = (
	'Member_ID',
	'First_Name',
	'Last_Name',
	'sn_email',
	'ypt_email',
	'sb_email',
	'Y01_Expires'
);

print scalar(localtime) . " loading email list from $toemail\n";

open(INPUT, '<', $toemail) or die $!;
# Member_ID	First_Name	Last_Name	sn_email	ypt_email	sb_email	Y01_Expires	continue
# 0     	1           2           3       	4			5			6			7
while (<INPUT>)
{
    chomp;	s/\r|\n//g;
    next if (/^\s*$/); # skip blank lines

    @f = split(/\t/);
    if ($. == 1)
    {
        # map field names to offsets
		$i = 0;
		for $f (@f)
		{
			$emailFields{$f} = $i++;
		}

        die "Improper email file format $_\nRequired: " . join(', ', @emailRequired) . "\n" unless (Contains(\@f, \@emailRequired));
        next;
    }

    if ($f[$emailFields{'Member_ID'}] !~ /\d+/)
    {
        print "Invalid email entry $_\n";
        $errors{"Invalid email entry"}++;
        next;
    }

    if (exists $emails{$f[$emailFields{'Member_ID'}]})
    {
        print "Duplicate email entry for $_\n\tprev: $emails{$f[$emailFields{'Member_ID'}]}\n";
        $errors{"Duplicate email entry"}++;
    }

    $emails{$f[$emailFields{'Member_ID'}]} = $_;
}
close(INPUT);



# these fields are required
@skipRequired = (
	'BSAID',
);

print scalar(localtime) . " loading email list from $skip\n";
open(INPUT, '<', $skip) or die $!;
# BSAID	Notes
# 0     1
while (<INPUT>)
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
			$skipFields{$f} = $i++;
		}

        die "Improper skip file format $_\nRequired: " . join(', ', @skipRequired) . "\n" unless (Contains(\@f, \@skipRequired));
        next;
    }

    if ($f[$skipFields{'BSAID'}] !~ /\d+/)
    {
        print "Invalid skip entry $_\n";
        $errors{"Invalid skip entry"}++;
        next;
    }

    if (exists $skips{$f[$skipFields{'BSAID'}]})
    {
        print "Duplicate skip entry for $_\n\tprev: $skips{$f[$skipFields{'BSAID'}]}\n";
        $errors{"Duplicate skip entry"}++;
    }

    $skips{$f[$skipFields{'BSAID'}]} = $_;
}
close(INPUT);


if ($opt_s)
{
	for (sort keys %emails)
	{
		$bsaid = $_;
		next if (exists($skips{$bsaid}));

		print "$emails{$bsaid}\n";
		$outputCount++;
	}
}
else
{
	$emailTemplate = do { local $/; <DATA> };

	$loopCount = scalar(values %emails);
	for (values %emails)
	{
	    @e = split(/\t/);

	    $bsaid = $e[$emailFields{'Member_ID'}];

	    $fname = $e[$emailFields{'First_Name'}];
	    $lname = $e[$emailFields{'Last_Name'}];
	    $ypt = $e[$emailFields{'Y01_Expires'}];

		%emailList = ();
		foreach (qw(sn_email ypt_email sb_email))
		{
			$emailList{lc($e[$emailFields{$_}])} = 1 if ($e[$emailFields{$_}] =~ /.+\@.+\..+/);
		}
		$email = join(',', keys(%emailList));

	    if (exists $skips{$bsaid})
	    {
	        print scalar(localtime) . " SKIP $bsaid, $fname $lname, $email\n";
	        $errors{"Skip entry"}++;
	        next;
	    }

	    print scalar(localtime) . " processing $bsaid, $fname $lname, $email\n";

	    # substitute values in the email body
	    $emailBody = $emailTemplate;
	    # name, ypt, link
	    $emailBody =~ s/\[name\]/$fname/ig;
	    $emailBody =~ s/\[ypt\]/$ypt/ig;

	    open(OUTPUT, '>body.txt') or die $!;
	    print OUTPUT $emailBody;
	    close(OUTPUT);

	    $from = 'mbc-renew@hmpg.net';
		$subject = "BSA YPT expired for merit badge counselor";

	    if ($opt_n)
	    {
	        print "COMMAND: blat body.txt -to $email -subject \"$subject\" -replyto $from -from $from -sender $from\n";
	        print "body.txt:\n";
	        $emailBody =~ s/\n/\n\t/g;
	        print "\t$emailBody\n";
	    }
	    else
	    {
	        print `blat body.txt -to $email -subject "$subject" -replyto $from -from $from -sender $from`;
	    }
	    unlink('body.txt');

	    $outputCount++;

	    sleep(10) if (--$loopCount && !$opt_n);  # seconds
	}
}


print '=' x 20 . "\nTotal records: $outputCount\nError counts\n";
for (sort keys %errors)
{
    print "\t$_: $errors{$_}\n";
}



print "Finished " . scalar(localtime()) . "\n\n";





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
Usage: $0 [-nD] email.tsv skip.tsv
    email.tsv = tab seperated list of people to send to
    skip.tsv = tab separated list of those to be skipped

    options:
    -s     : just do the skip list processing and output the remaining records
    -n     : don't actually send, just show what would be done
    -D     : turn on debug messages
EOS
}


__DATA__
[name],

Thank you for renewing your merit badge counselor registration. One of the requirements for a merit badge counselor is to maintain current BSA Youth Protection Training (YPT).

According to our records, your YPT will expire before the end of June of this year. In order to renew as a merit badge counselor, you will need to complete YPT before the end of this month.

Your YPT expires [ypt].

Visit https://www.utahscouts.org/ypt to take the training.

If you have recently completed YPT, or you believe your YPT date is in error, please email a copy of your YPT completion certificate to Annette Sholly at Annette.Sholly@scouting.org

Sincerely,

James Brown
Merit Badge Counselor Coordinator
Council Advancement Committee
Crossroads of the West Council
