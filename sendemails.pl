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
	'BSAID',
    'First name',
    'Last name',
	'Email',
    'YPT Expiry',
    'Merit badges'
);

print scalar(localtime) . " loading email list from $toemail\n";

open(INPUT, '<', $toemail) or die $!;
# BSAID	First Name	Last Name	Email	YPTExpiryDate	Merit Badges
# 0     1           2           3       4               5
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

    if ($f[$emailFields{'BSAID'}] !~ /\d+/)
    {
        print "Invalid email entry $_\n";
        $errors{"Invalid email entry"}++;
        next;
    }

    if ($f[$emailFields{'Email'}] !~ /.+\@.+\..+/)
    {
        print "Invalid email address for $_\n";
        $errors{"Invalid email address"}++;
        next unless ($opt_s);
    }

    if (exists $emails{$f[$emailFields{'BSAID'}]})
    {
        print "Duplicate email entry for $_\n\tprev: $emails{$f[$emailFields{'BSAID'}]}\n";
        $errors{"Duplicate email entry"}++;
    }

    if ($f[$badgeFields{'Merit badges'}] =~ /^\s*$/)
    {
        print "Empty badges list for $_\n";
        $errors{"Empty badges list"}++;
    }

    $emails{$f[$emailFields{'BSAID'}]} = $_;
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

	%certsRequired = (
	    'Lifesaving' => 1,
	    'Swimming' => 1,
	    'Archery' => 1,
	    'Canoeing' => 1,
	    'Climbing' => 1,
	    'Kayaking' => 1,
	    'Motorboating' => 1,
	    'Rifle Shooting' => 1,
	    'Rowing' => 1,
	    'Scuba Diving' => 1,
	    'Shotgun Shooting' => 1,
	    'Small Boat Sailing' => 1,
	    'Snow Sports' => 1,
	    'Water Sports' => 1,
	    'Whitewater' => 1
	);

	$emailTemplate = do { local $/; <DATA> };
	$linkTemplate='https://docs.google.com/forms/d/e/1FAIpQLSep7ScbZh_nFI-HdlAGD5b1trmPjfJsD6q2WICAa7lSsZqlSg/viewform?usp=pp_url&entry.647734746=[name]&entry.2105575394=[bsaid]';
	$linkMBTemplate='&entry.1953878036=[mb]';

	$loopCount = scalar(values %emails);
	for (values %emails)
	{
	    @e = split(/\t/);

	    $bsaid = $e[$emailFields{'BSAID'}];

	    $fname = $e[$emailFields{'First name'}];
	    $lname = $e[$emailFields{'Last name'}];
	    $email = $e[$emailFields{'Email'}];
	    $ypt = $e[$emailFields{'YPT Expiry'}];
	    $mbs = $e[$emailFields{'Merit badges'}];

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

	    # generate the link for the google form
	    $link = $linkTemplate;
	    $name = "$fname $lname";
	    $name =~ s/\s+/+/g;
	    $link =~ s/\[name\]/$name/i;

	    $link =~ s/\[bsaid\]/$bsaid/i;

	    # add all the mbs to the link
	    for $mb (split(/\|/, $mbs))
	    {
	        $mb =~ s/Computers/Digital Technology/i;

	        my $mbField = $linkMBTemplate;

	        $mb .= ' *' if (exists $certsRequired{$mb});

	        $mbField =~ s/\[mb\]/$mb/;
	        $mbField =~ s/\s+/+/g;

	        $link .= $mbField;
	    }

	    $emailBody =~ s/\[link\]/$link/ig;

	    open(OUTPUT, '>body.txt') or die $!;
	    print OUTPUT $emailBody;
	    close(OUTPUT);

	    $from = 'mbc-renew@hmpg.net';

	    if ($opt_n)
	    {
	        print "COMMAND: blat body.txt -to $email -subject \"BSA Merit Badge Counselor reregistration\" -replyto $from -from $from -sender $from\n";
	        print "body.txt:\n";
	        $emailBody =~ s/\n/\n\t/g;
	        print "\t$emailBody\n";
	    }
	    else
	    {
	        print `blat body.txt -to $email -subject "BSA Merit Badge Counselor reregistration" -replyto $from -from $from -sender $from`;
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

Just a reminder that we haven't heard from you. If you no longer wish to be a counselor, please click the link below and select 'no' so we don't continue to try to contact you.

Thank you for serving as a merit badge counselor for the Boy Scouts of America. Merit badge counselors are required to reregister each year. There is no fee to register, but you must indicate whether or not you want to continue to serve annually. If you've already been contacted this year, you don't need to respond again.

In order to accomplish this in an efficient manner, we invite you to click the customized link below and complete this online form. You must complete this form by April 30 or you may be dropped as a merit badge counselor.

This form is prefilled with your name and BSA member ID. We ask that you indicate if you would be willing to continue serving as a counselor, or if you would prefer not to continue to serve.

If you choose to continue (and we hope you do), the next page will ask you to select your district and update your contact info if necessary. Next is a list of all the merit badges with checks by those for which you are approved to counsel. Please uncheck any badges you no longer wish to be a counselor for. You may also add any new badges by checking their boxes.

Please note that some badges require specific certifications or qualifications. For any new badges you select, you may be contacted to discuss your qualifications prior to being approved.

If any badges require certifications (for example shooting sports), we must have current copies of your certifications. Please scan and send any updates to your certifications directly to the council registrar, Annette Sholly, Annette.Sholly@scouting.org.

Be sure to scroll all the way to the bottom to submit the form once completed.

You must keep your Youth Protection Training (YPT) current. It must be renewed every two years.
Your YPT expires [ypt].

You also need to complete merit badge counselor training if you have not already done so. You can take the training online at https://training.scouting.org/learning-plans/1188. Note that you must ALREADY be logged in to my.scouting.org for this link to work.

Click the following link to reregister:

[link]

Sincerely,

James Brown
Merit Badge Counselor Coordinator
Council Advancement Committee
Crossroads of the West Council
