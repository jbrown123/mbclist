#!/usr/bin/env perl

# script to read sqlite output and calculate MB list deltas & fix duplicate emails
use Array::Utils qw(:all);

use Getopt::Std;

getopts('aD');

Usage() unless ($#ARGV == 0);

$input = $ARGV[0];

warn "Loading date from $input\n\n";

# these fields are required
@inputRequired = (
	'id',
    'Name',
	'email',
    'notes',
    'district',
    'mbold',
    'mbnew'
);

open(INPUT, '<', $input) or die $!;
# id    Name	email	notes	district	mbold	mbnew
# 0     1       2       3       4           5       6
while (<INPUT>)
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
			$inputFields{$f} = $i++;
		}

        die "Improper file format $_\nRequired: " . join(', ', @inputRequired) . "\n" unless (Contains(\@f, \@inputRequired));

        print join(',', qw(id name email notes district mbdelta mbnew)) . "\n";
        next;
    }

    # remove the '*' on the end of the new list elements
    $f[$inputFields{'mbnew'}] =~ s/\s+\*//g;
    $f[$inputFields{'mbnew'}] =~ s/Communication/Communications/ig;

    $f[$inputFields{'mbnew'}] =~ s/Computers/Digital Technology/ig;
    $f[$inputFields{'mbold'}] =~ s/Computers/Digital Technology/ig;

    $f[$inputFields{'mbold'}] =~ s/\s*\(troop only\)//ig;

    # force same case on both lists
    $f[$inputFields{'mbnew'}] =~ s/(\w+)/ucfirst(lc($1))/eg;
    $f[$inputFields{'mbold'}] =~ s/(\w+)/ucfirst(lc($1))/eg;

    @mbold = sort(split(/\|/, $f[$inputFields{'mbold'}]));
    @mbnew = sort(split(/\|/, $f[$inputFields{'mbnew'}]));

    # https://metacpan.org/pod/Array::Utils
    # get items from @a not in @b
    # array_minus( @a, @b );
    my @removeMBs = map {'-'.$_} array_minus( @mbold, @mbnew ); # old that are not in new
    my @addMBs = map {'+'.$_} array_minus( @mbnew, @mbold ); # new that were not in old

    # remove duplicate emails
    my $emails = join(', ', unique(split(/\s*,\s*/, lc($f[$inputFields{'email'}]))));

    print qq!"! . join(qq!","!,$f[$inputFields{'id'}], $f[$inputFields{'Name'}], $emails, $f[$inputFields{'notes'}],
            $f[$inputFields{'district'}], join(', ', @addMBs, @removeMBs),
            join(', ', @mbnew) ) . qq!"\n!;
}
close(INPUT);



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
Usage: $0 [-D] update.tsv
    update.tsv = tab seperated list of people with old and new badges

    options:
    -D     : turn on debug messages
EOS
}
