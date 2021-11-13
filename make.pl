#!/usr/bin/env perl

# script to process all the downloaded data and generate the output files for the site
use Getopt::Std;

getopts("D");

Usage() unless ($#ARGV == 0);

$date = $ARGV[0];

# these file are required
@fileRequired = (
    "CouncilMeritBadgeCounselorListing_$date.csv",
#	"YPT_$date.csv",
#	"TrainedLeader_$date.csv",
	"PinDataReport_$date.csv",
	"590_Detailmbc_download_$date.csv"
);

# make sure all the files we need are present
for (@fileRequired)
{
	die "FATAL: File $_ not found!\n" if (-s $_ < 1);
}

# now execute the commands
@commands = (
	"sed 1,10d CouncilMeritBadgeCounselorListing_$date.csv | CSVFileView /load stdin: /stab scoutnet.tsv",
#	"sed 1d YPT_$date.csv | CSVFileView /load stdin: /stab YPT.tsv",
#	"sed 1,8d TrainedLeader_$date.csv | CSVFileView /load stdin: /stab TrainedLeader.tsv",
	"CSVFileView /load PinDataReport_$date.csv /stab PinDataReport.tsv",
	"CSVFileView /load 590_Detailmbc_download_$date.csv /stab scoutbook.tsv",

#    "perl ingest.pl scoutnet.tsv scoutbook.tsv TrainedLeader.tsv > live-mbc.json",
    "perl ingest.pl scoutnet.tsv scoutbook.tsv > live-mbc.json",

	"perl pin2units.pl PinDataReport.tsv >units.json",
	"perl makemap.pl",
	"perl makelive.pl",

	"copy live-index.html site",
	"copy maplive.html site",
);

for (@commands)
{
	print "$_\n";
	print `$_` . "\n";
}

sub Usage
{
    die <<EOS;
Usage: $0 [options] date
    date = formatted date in file names (e.g. 20210914)

    options:
    -D     : turn on debug messages
EOS
}
