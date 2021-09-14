#!/usr/bin/env perl

# generate a random password from a word list & numbers

open(WORDS, '<', 'passwords.txt') or die $!;
while (<WORDS>)
{
    chomp;
    next if (/^\s*$/); # skip blank lines
    push(@words, $_);
}
close(WORDS);

print randomWord() . int(rand(99)+1) . randomWord() . int(rand(99)+1) . randomWord();

sub randomWord
{
    my $i = int(rand(scalar(@words)));

    my $word = $words[$i];
    splice @words, $i, 1;

    return $word;
}
