#!/usr/bin/env perl

# script to merge ScoutNET and ScoutBook data and generate JSON data.
use Getopt::Std;

getopts('e:y:D'); # warn about excessive MB, want about YPT expiry; Debug output

Usage() unless ($#ARGV == 1);

$people = $ARGV[0];
$badges = $ARGV[1];

=comment block
# this code was commented out when they returned the address field to the scoutnet data
Don't forget to set $#ARGV==2 above!
$training = $ARGV[2];

warn "Loading training info from $training\n\n";

# these fields are required
@trainingRequired = (
	'MemberID',
    'Zip_Code'
);

open(TRAINING, '<', $training) or die $!;
while (<TRAINING>)
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
			$trainingFields{$f} = $i++;
		}

        die "Improper training file format $_\nRequired: " . join(', ', @trainingRequired) . "\n" unless (Contains(\@f, \@trainingRequired));
        next;
    }

    if ($f[$trainingFields{'MemberID'}] !~ /\d+/)
    {
        warn "Invalid training entry $_\n\n";
        $errors{"Invalid training entry"}++;
        next;
    }

    if (exists $training{$f[$trainingFields{'MemberID'}]})
    {
        warn "Duplicate training entry for $_\n\tprev: $training{$f[$trainingFields{'MemberID'}]}\n\n";
        $errors{"Duplicate training entry"}++;
    }

    $training{$f[$trainingFields{'MemberID'}]} = $_;
}
close(TRAINING);
=cut

warn "Loading badges from $badges\n\n";

# these fields are required
@badgesRequired = (
	'BSAMemberID',
    'First Name',
    'Last Name',
	'Email',
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
	'organizations',
	'memberid',
	'phone',
	'email',
	'straddress',
);

warn '=' x 20 . "\nLoading people from $people\n";
open(PEOPLE, '<', $people) or die $!;
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

    if ($f[$peopleFields{'memberid'}] !~ /\d+/)
    {
        warn "Invalid person entry $_\n\n";
        $errors{"Invalid person entry"}++;
        next;
    }

    if (exists($people{$f[$peopleFields{'memberid'}]}))
    {
        warn "Duplicate person entry for $_\n\tprev: $people{$f[$peopleFields{'memberid'}]}\n\n";
        $errors{"Duplicate person entry"}++;
        next;
    }

    $people{$f[$peopleFields{'memberid'}]} = $_;
}
close(PEOPLE);

while (<DATA>)
{
	chomp;
	s/\r|\n//g;

	@z = split(/\t/);
	$zips{$z[0]} = $_;
}

warn '=' x 20 . "\nMerging data\n";

for (values %people)
{
    @p = split(/\t/);

    if (!exists $badges{$p[$peopleFields{'memberid'}]})
    {
        warn "Missing badges entry for $_\n\n";
        $errors{"Missing badges entry"}++;
        next;
    }

    @b = split(/\t/, $badges{$p[$peopleFields{'memberid'}]});

    $b[$badgeFields{'Merit Badges'}] =~ s/"//g;    # remove surrounding quotes

    # deal with the ScoutBook braintrust using commas to separate data with embedded commas
    $b[$badgeFields{'Merit Badges'}] =~ s/Signs, Signals, and Codes/Signs Signals and Codes/ig;    # remove bogus commas
    $b[$badgeFields{'Merit Badges'}] =~ s/\s*,\s*/\t/g;    # replace comma with tab (as it should have been anyway)
    $b[$badgeFields{'Merit Badges'}] =~ s/Signs Signals and Codes/Signs, Signals, and Codes/ig;    # restore commas

    $mbs = '"' . join('","', sort split(/\t/, $b[$badgeFields{'Merit Badges'}])) . '"';

    $workwith = $b[$badgeFields{'ListingPreference'}] .
        (($b[$badgeFields{'ListingPreference'}] eq 'Unit') ? " $b[$badgeFields{'Units'}]" :
        ($b[$badgeFields{'ListingPreference'}] eq 'District') ? " $b[$badgeFields{'Districts'}]" : '');

	$district = $p[$peopleFields{'organizations'}];
	$district =~ s/"//g;	# remove any surrounding quotes (in the case of multiple districts)

	$address = $p[$peopleFields{'straddress'}];
	$address =~ s/^"?\s+//; $address =~ s/\s+"?$//; # remove leading and trailing blanks

	$zip = $city = $state = '';
	# match something like "255 W 2000 S, Orem, UT 84058"
	if ($address =~ /^(.+),\s+(.+),\s+([A-Z]{2})\s+(\d+(?:-\d+)?)$/)
	{
		$address = $1;
		$city = $2;
		$state = $3;
		$zip = $4;
	}
	else
	{
		warn "Couldn't parse address '$address' for $_\n\n";
        $errors{"Couldn't parse address"}++;
	}

	# give as much email info as we can
	$email = $b[$badgeFields{'Email'}] || $p[$peopleFields{'email'}];
	$email .= ", $p[$peopleFields{'email'}]" if (lc($email) ne lc($p[$peopleFields{'email'}]));

=comment block
	# try to find zip code
	$zip = $city = $state = '';
	if (exists $training{$p[$peopleFields{'memberid'}]})
	{
		@t = split(/\t/, $training{$p[$peopleFields{'memberid'}]});
		$zip = $t[$trainingFields{'Zip_Code'}];

		if (exists $zips{$zip})
		{
			my @f = split(/\t/, $zips{$zip});
			$city = $f[1];
			$state = $f[2];
		}
		else
		{
			warn "No city, state for ''$zip'\n\n";
			$errors{"Missing city state for zip"}++;
		}
	}
	else
	{
		warn "Missing zip entry for $_\n\n";
        $errors{"Missing zip entry"}++;
	}
=cut

    print <<EOS;
    {
        name: "$b[$badgeFields{'First Name'}] $b[$badgeFields{'Last Name'}]",
        address: "$address",
        city: "$city",
        state: "$state",
        zip: "$zip",
        phone: [{type: "A", number: "$p[$peopleFields{'phone'}]"}],
        email: "$email",
        district: "$district",
        bsaid: "$p[$peopleFields{'memberid'}]",
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

		@b = split(/\t/, $badges{$_});

	    $b[$badgeFields{'Merit Badges'}] =~ s/"//g;    # remove surrounding quotes

	    # deal with the ScoutBook braintrust using commas to separate data with embedded commas
	    $b[$badgeFields{'Merit Badges'}] =~ s/Signs, Signals, and Codes/Signs Signals and Codes/ig;    # remove bogus commas
	    $b[$badgeFields{'Merit Badges'}] =~ s/\s*,\s*/\t/g;    # replace comma with tab (as it should have been anyway)
	    $b[$badgeFields{'Merit Badges'}] =~ s/Signs Signals and Codes/Signs, Signals, and Codes/ig;    # restore commas

	    $mbs = '"' . join('","', sort split(/\t/, $b[$badgeFields{'Merit Badges'}])) . '"';

	    $workwith = $b[$badgeFields{'ListingPreference'}] .
	        (($b[$badgeFields{'ListingPreference'}] eq 'Unit') ? " $b[$badgeFields{'Units'}]" :
	        ($b[$badgeFields{'ListingPreference'}] eq 'District') ? " $b[$badgeFields{'Districts'}]" : '');

	    print <<EOS;
	    {
	        name: "$b[$badgeFields{'First Name'}] $b[$badgeFields{'Last Name'}]",
	        address: "",
	        city: "",
	        state: "",
	        zip: "",
	        phone: [{type: "", number: ""}],
	        email: "$b[$badgeFields{'Email'}]",
	        district: "UNKNOWN",
	        bsaid: "$b[$badgeFields{'BSAMemberID'}]",
	        meritbadges: [$mbs],
	        workwith: "$workwith",
	        availability: "$b[$badgeFields{'Availability'}]",
	        yptexpiry: "$b[$badgeFields{'YPTExpiryDate'}]"
	    },
EOS
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
Usage: $0 [-eyD] person.tsv mblist.tsv
    person.tsv = tab seperated list of people from ScoutNET
    mblist.tsv = tab separated list of MBCs from ScoutBook

    options:
    -e <n> : warn about excessive merit badges, more than <n>
    -y <d> : warn about YPT expiring in 'd' days (default: 45)
    -D     : turn on debug messages
EOS
}

# here is the zip code data from GeoNames
__DATA__
83616	Eagle	ID
83634	Kuna	ID
83642	Meridian	ID
83669	Star	ID
83680	Meridian	ID
83701	Boise	ID
83702	Boise	ID
83703	Boise	ID
83704	Boise	ID
83705	Boise	ID
83706	Boise	ID
83707	Boise	ID
83708	Boise	ID
83709	Boise	ID
83711	Boise	ID
83712	Boise	ID
83713	Boise	ID
83714	Garden City	ID
83715	Boise	ID
83716	Boise	ID
83717	Boise	ID
83719	Boise	ID
83720	Boise	ID
83722	Boise	ID
83724	Boise	ID
83725	Boise	ID
83726	Boise	ID
83728	Boise	ID
83729	Boise	ID
83731	Boise	ID
83732	Boise	ID
83735	Boise	ID
83756	Boise	ID
83799	Boise	ID
83612	Council	ID
83632	Indian Valley	ID
83643	Mesa	ID
83654	New Meadows	ID
83201	Pocatello	ID
83202	Pocatello	ID
83204	Pocatello	ID
83205	Pocatello	ID
83206	Pocatello	ID
83209	Pocatello	ID
83214	Arimo	ID
83234	Downey	ID
83245	Inkom	ID
83246	Lava Hot Springs	ID
83250	McCammon	ID
83281	Swanlake	ID
83220	Bern	ID
83223	Bloomington	ID
83233	Dingle	ID
83238	Geneva	ID
83239	Georgetown	ID
83254	Montpelier	ID
83261	Paris	ID
83272	Saint Charles	ID
83287	Fish Haven	ID
83824	Desmet	ID
83830	Fernwood	ID
83851	Plummer	ID
83861	Saint Maries	ID
83866	Santa	ID
83870	Tensed	ID
83203	Fort Hall	ID
83210	Aberdeen	ID
83215	Atomic City	ID
83218	Basalt	ID
83221	Blackfoot	ID
83236	Firth	ID
83256	Moreland	ID
83262	Pingree	ID
83274	Shelley	ID
83277	Springfield	ID
83313	Bellevue	ID
83320	Carey	ID
83333	Hailey	ID
83340	Ketchum	ID
83348	Picabo	ID
83353	Sun Valley	ID
83354	Sun Valley	ID
83602	Banks	ID
83622	Garden Valley	ID
83629	Horseshoe Bend	ID
83631	Idaho City	ID
83637	Lowman	ID
83646	Meridian	ID
83666	Placerville	ID
83804	Blanchard	ID
83809	Careywood	ID
83811	Clark Fork	ID
83813	Cocolalla	ID
83821	Coolin	ID
83822	Oldtown	ID
83825	Dover	ID
83836	Hope	ID
83840	Kootenai	ID
83841	Laclede	ID
83848	Nordman	ID
83852	Ponderay	ID
83856	Priest River	ID
83860	Sagle	ID
83864	Sandpoint	ID
83865	Colburn	ID
83401	Idaho Falls	ID
83402	Idaho Falls	ID
83403	Idaho Falls	ID
83404	Idaho Falls	ID
83405	Idaho Falls	ID
83406	Idaho Falls	ID
83415	Idaho Falls	ID
83427	Iona	ID
83428	Irwin	ID
83449	Swan Valley	ID
83454	Ucon	ID
83805	Bonners Ferry	ID
83826	Eastport	ID
83845	Moyie Springs	ID
83847	Naples	ID
83853	Porthill	ID
83213	Arco	ID
83244	Howe	ID
83255	Moore	ID
83322	Corral	ID
83327	Fairfield	ID
83337	Hill City	ID
83605	Caldwell	ID
83606	Caldwell	ID
83607	Caldwell	ID
83626	Greenleaf	ID
83630	Huston	ID
83641	Melba	ID
83644	Middleton	ID
83651	Nampa	ID
83652	Nampa	ID
83653	Nampa	ID
83656	Notus	ID
83660	Parma	ID
83676	Wilder	ID
83686	Nampa	ID
83687	Nampa	ID
83217	Bancroft	ID
83230	Conda	ID
83241	Grace	ID
83276	Soda Springs	ID
83285	Wayan	ID
83311	Albion	ID
83312	Almo	ID
83318	Burley	ID
83323	Declo	ID
83342	Malta	ID
83346	Oakley	ID
83423	Dubois	ID
83446	Spencer	ID
83520	Ahsahka	ID
83541	Lenore	ID
83544	Orofino	ID
83546	Pierce	ID
83553	Weippe	ID
83827	Elk River	ID
83226	Challis	ID
83227	Clayton	ID
83235	Ellis	ID
83251	Mackay	ID
83278	Stanley	ID
83601	Atlanta	ID
83623	Glenns Ferry	ID
83627	Hammett	ID
83633	King Hill	ID
83647	Mountain Home	ID
83648	Mountain Home Afb	ID
83228	Clifton	ID
83232	Dayton	ID
83237	Franklin	ID
83263	Preston	ID
83283	Thatcher	ID
83286	Weston	ID
83420	Ashton	ID
83421	Chester	ID
83429	Island Park	ID
83433	Macks Inn	ID
83436	Newdale	ID
83438	Parker	ID
83445	Saint Anthony	ID
83451	Teton	ID
83617	Emmett	ID
83636	Letha	ID
83657	Ola	ID
83670	Sweet	ID
83314	Bliss	ID
83330	Gooding	ID
83332	Hagerman	ID
83355	Wendell	ID
83522	Cottonwood	ID
83525	Elk City	ID
83526	Ferdinand	ID
83530	Grangeville	ID
83531	Fenn	ID
83533	Greencreek	ID
83539	Kooskia	ID
83542	Lucile	ID
83547	Pollock	ID
83549	Riggins	ID
83552	Stites	ID
83554	White Bird	ID
83671	Warren	ID
83425	Hamer	ID
83431	Lewisville	ID
83434	Menan	ID
83435	Monteview	ID
83442	Rigby	ID
83443	Ririe	ID
83444	Roberts	ID
83450	Terreton	ID
83325	Eden	ID
83335	Hazelton	ID
83338	Jerome	ID
83801	Athol	ID
83803	Bayview	ID
83810	Cataldo	ID
83814	Coeur d'Alene	ID
83815	Coeur d'Alene	ID
83816	Coeur d'Alene	ID
83833	Harrison	ID
83835	Hayden	ID
83842	Medimont	ID
83854	Post Falls	ID
83858	Rathdrum	ID
83869	Spirit Lake	ID
83876	Worley	ID
83877	Post Falls	ID
83535	Juliaetta	ID
83537	Kendrick	ID
83806	Bovill	ID
83823	Deary	ID
83832	Genesee	ID
83834	Harvard	ID
83843	Moscow	ID
83844	Moscow	ID
83855	Potlatch	ID
83857	Princeton	ID
83871	Troy	ID
83872	Viola	ID
83229	Cobalt	ID
83253	May	ID
83462	Carmen	ID
83463	Gibbonsville	ID
83464	Leadore	ID
83465	Lemhi	ID
83466	North Fork	ID
83467	Salmon	ID
83468	Tendoy	ID
83469	Shoup	ID
83523	Craigmont	ID
83536	Kamiah	ID
83543	Nezperce	ID
83548	Reubens	ID
83555	Winchester	ID
83324	Dietrich	ID
83349	Richfield	ID
83352	Shoshone	ID
83440	Rexburg	ID
83441	Rexburg	ID
83448	Sugar City	ID
83460	Rexburg	ID
83336	Heyburn	ID
83343	Minidoka	ID
83347	Paul	ID
83350	Rupert	ID
83501	Lewiston	ID
83524	Culdesac	ID
83540	Lapwai	ID
83545	Peck	ID
83243	Holbrook	ID
83252	Malad City	ID
83604	Bruneau	ID
83624	Grand View	ID
83628	Homedale	ID
83639	Marsing	ID
83650	Murphy	ID
83619	Fruitland	ID
83655	New Plymouth	ID
83661	Payette	ID
83211	American Falls	ID
83212	Arbon	ID
83271	Rockland	ID
83802	Avery	ID
83808	Calder	ID
83812	Clarkia	ID
83837	Kellogg	ID
83839	Kingston	ID
83846	Mullan	ID
83849	Osburn	ID
83850	Pinehurst	ID
83867	Silverton	ID
83868	Smelterville	ID
83873	Wallace	ID
83874	Murray	ID
83422	Driggs	ID
83424	Felt	ID
83452	Tetonia	ID
83455	Victor	ID
83301	Twin Falls	ID
83302	Rogerson	ID
83303	Twin Falls	ID
83316	Buhl	ID
83321	Castleford	ID
83328	Filer	ID
83334	Hansen	ID
83341	Kimberly	ID
83344	Murtaugh	ID
83611	Cascade	ID
83615	Donnelly	ID
83635	Lake Fork	ID
83638	McCall	ID
83677	Yellow Pine	ID
83610	Cambridge	ID
83645	Midvale	ID
83672	Weiser	ID
84713	Beaver	UT
84731	Greenville	UT
84751	Milford	UT
84752	Minersville	UT
84301	Bear River City	UT
84302	Brigham City	UT
84306	Collinston	UT
84307	Corinne	UT
84309	Deweyville	UT
84311	Fielding	UT
84312	Garland	UT
84313	Grouse Creek	UT
84314	Honeyville	UT
84316	Howell	UT
84324	Mantua	UT
84329	Park Valley	UT
84330	Plymouth	UT
84331	Portage	UT
84334	Riverside	UT
84336	Snowville	UT
84337	Tremonton	UT
84340	Willard	UT
84304	Cache Junction	UT
84305	Clarkston	UT
84308	Cornish	UT
84318	Hyde Park	UT
84319	Hyrum	UT
84320	Lewiston	UT
84321	Logan	UT
84322	Logan	UT
84323	Logan	UT
84325	Mendon	UT
84326	Millville	UT
84327	Newton	UT
84328	Paradise	UT
84332	Providence	UT
84333	Richmond	UT
84335	Smithfield	UT
84338	Trenton	UT
84339	Wellsville	UT
84341	Logan	UT
84501	Price	UT
84520	East Carbon	UT
84526	Helper	UT
84529	Kenilworth	UT
84539	Sunnyside	UT
84542	Wellington	UT
84023	Dutch John	UT
84046	Manila	UT
84010	Bountiful	UT
84011	Bountiful	UT
84014	Centerville	UT
84015	Clearfield	UT
84016	Clearfield	UT
84025	Farmington	UT
84037	Kaysville	UT
84040	Layton	UT
84041	Layton	UT
84054	North Salt Lake	UT
84056	Hill Afb	UT
84075	Syracuse	UT
84087	Woods Cross	UT
84089	Clearfield	UT
84001	Altamont	UT
84002	Altonah	UT
84007	Bluebell	UT
84021	Duchesne	UT
84027	Fruitland	UT
84031	Hanna	UT
84051	Mountain Home	UT
84052	Myton	UT
84053	Neola	UT
84066	Roosevelt	UT
84072	Tabiona	UT
84073	Talmage	UT
84513	Castle Dale	UT
84516	Clawson	UT
84518	Cleveland	UT
84521	Elmo	UT
84522	Emery	UT
84523	Ferron	UT
84525	Green River	UT
84528	Huntington	UT
84537	Orangeville	UT
84712	Antimony	UT
84716	Boulder	UT
84718	Cannonville	UT
84726	Escalante	UT
84735	Hatch	UT
84736	Henrieville	UT
84759	Panguitch	UT
84764	Bryce	UT
84776	Tropic	UT
84515	Cisco	UT
84532	Moab	UT
84540	Thompson	UT
84714	Beryl	UT
84719	Brian Head	UT
84720	Cedar City	UT
84721	Cedar City	UT
84742	Kanarraville	UT
84753	Modena	UT
84756	Newcastle	UT
84760	Paragonah	UT
84761	Parowan	UT
84772	Summit	UT
84628	Eureka	UT
84639	Levan	UT
84645	Mona	UT
84648	Nephi	UT
84710	Alton	UT
84729	Glendale	UT
84741	Kanab	UT
84755	Mount Carmel	UT
84758	Orderville	UT
84762	Duck Creek Village	UT
84624	Delta	UT
84631	Fillmore	UT
84635	Hinckley	UT
84636	Holden	UT
84637	Kanosh	UT
84638	Leamington	UT
84640	Lynndyl	UT
84644	Meadow	UT
84649	Oak City	UT
84656	Scipio	UT
84728	Garrison	UT
84018	Croydon	UT
84050	Morgan	UT
84723	Circleville	UT
84732	Greenwich	UT
84740	Junction	UT
84743	Kingston	UT
84750	Marysvale	UT
84028	Garden City	UT
84038	Laketown	UT
84064	Randolph	UT
84086	Woodruff	UT
84006	Bingham Canyon	UT
84009	South Jordan	UT
84020	Draper	UT
84044	Magna	UT
84047	Midvale	UT
84065	Riverton	UT
84070	Sandy	UT
84081	West Jordan	UT
84084	West Jordan	UT
84088	West Jordan	UT
84090	Sandy	UT
84091	Sandy	UT
84092	Sandy	UT
84093	Sandy	UT
84094	Sandy	UT
84095	South Jordan	UT
84096	Herriman	UT
84101	Salt Lake City	UT
84102	Salt Lake City	UT
84103	Salt Lake City	UT
84104	Salt Lake City	UT
84105	Salt Lake City	UT
84106	Salt Lake City	UT
84107	Salt Lake City	UT
84108	Salt Lake City	UT
84109	Salt Lake City	UT
84110	Salt Lake City	UT
84111	Salt Lake City	UT
84112	Salt Lake City	UT
84113	Salt Lake City	UT
84114	Salt Lake City	UT
84115	Salt Lake City	UT
84116	Salt Lake City	UT
84117	Salt Lake City	UT
84118	Salt Lake City	UT
84119	West Valley City	UT
84120	West Valley City	UT
84121	Salt Lake City	UT
84122	Salt Lake City	UT
84123	Salt Lake City	UT
84124	Salt Lake City	UT
84125	Salt Lake City	UT
84126	Salt Lake City	UT
84127	Salt Lake City	UT
84128	West Valley City	UT
84129	Salt Lake City	UT
84130	Salt Lake City	UT
84131	Salt Lake City	UT
84132	Salt Lake City	UT
84133	Salt Lake City	UT
84134	Salt Lake City	UT
84136	Salt Lake City	UT
84138	Salt Lake City	UT
84139	Salt Lake City	UT
84141	Salt Lake City	UT
84143	Salt Lake City	UT
84145	Salt Lake City	UT
84147	Salt Lake City	UT
84148	Salt Lake City	UT
84150	Salt Lake City	UT
84151	Salt Lake City	UT
84152	Salt Lake City	UT
84157	Salt Lake City	UT
84158	Salt Lake City	UT
84165	Salt Lake City	UT
84170	Salt Lake City	UT
84171	Salt Lake City	UT
84180	Salt Lake City	UT
84184	Salt Lake City	UT
84189	Salt Lake City	UT
84190	Salt Lake City	UT
84199	Salt Lake City	UT
84510	Aneth	UT
84511	Blanding	UT
84512	Bluff	UT
84530	La Sal	UT
84531	Mexican Hat	UT
84533	Lake Powell	UT
84534	Montezuma Creek	UT
84535	Monticello	UT
84536	Monument Valley	UT
84621	Axtell	UT
84622	Centerfield	UT
84623	Chester	UT
84627	Ephraim	UT
84629	Fairview	UT
84630	Fayette	UT
84632	Fountain Green	UT
84634	Gunnison	UT
84642	Manti	UT
84643	Mayfield	UT
84646	Moroni	UT
84647	Mount Pleasant	UT
84662	Spring City	UT
84665	Sterling	UT
84667	Wales	UT
84620	Aurora	UT
84652	Redmond	UT
84654	Salina	UT
84657	Sigurd	UT
84701	Richfield	UT
84711	Annabella	UT
84724	Elsinore	UT
84730	Glenwood	UT
84739	Joseph	UT
84744	Koosharem	UT
84754	Monroe	UT
84766	Sevier	UT
84017	Coalville	UT
84024	Echo	UT
84033	Henefer	UT
84036	Kamas	UT
84055	Oakley	UT
84060	Park City	UT
84061	Peoa	UT
84068	Park City	UT
84098	Park City	UT
84022	Dugway	UT
84029	Grantsville	UT
84034	Ibapah	UT
84069	Rush Valley	UT
84071	Stockton	UT
84074	Tooele	UT
84080	Vernon	UT
84083	Wendover	UT
84008	Bonanza	UT
84026	Fort Duchesne	UT
84035	Jensen	UT
84039	Lapoint	UT
84063	Randlett	UT
84076	Tridell	UT
84078	Vernal	UT
84079	Vernal	UT
84085	Whiterocks	UT
84003	American Fork	UT
84004	Alpine	UT
84005	Eagle Mountain	UT
84013	Cedar Valley	UT
84042	Lindon	UT
84043	Lehi	UT
84045	Saratoga Springs	UT
84057	Orem	UT
84058	Orem	UT
84059	Orem	UT
84062	Pleasant Grove	UT
84097	Orem	UT
84601	Provo	UT
84602	Provo	UT
84603	Provo	UT
84604	Provo	UT
84605	Provo	UT
84606	Provo	UT
84626	Elberta	UT
84633	Goshen	UT
84651	Payson	UT
84653	Salem	UT
84655	Santaquin	UT
84660	Spanish Fork	UT
84663	Springville	UT
84664	Mapleton	UT
84032	Heber City	UT
84049	Midway	UT
84082	Wallsburg	UT
84722	Central	UT
84725	Enterprise	UT
84733	Gunlock	UT
84737	Hurricane	UT
84738	Ivins	UT
84745	La Verkin	UT
84746	Leeds	UT
84757	New Harmony	UT
84763	Rockville	UT
84765	Santa Clara	UT
84767	Springdale	UT
84770	Saint George	UT
84771	Saint George	UT
84774	Toquerville	UT
84779	Virgin	UT
84780	Washington	UT
84781	Pine Valley	UT
84782	Veyo	UT
84783	Dammeron Valley	UT
84784	Hildale	UT
84790	Saint George	UT
84791	Saint George	UT
84715	Bicknell	UT
84734	Hanksville	UT
84747	Loa	UT
84749	Lyman	UT
84773	Teasdale	UT
84775	Torrey	UT
84067	Roy	UT
84201	Ogden	UT
84244	Ogden	UT
84310	Eden	UT
84315	Hooper	UT
84317	Huntsville	UT
84401	Ogden	UT
84402	Ogden	UT
84403	Ogden	UT
84404	Ogden	UT
84405	Ogden	UT
84407	Ogden	UT
84408	Ogden	UT
84409	Ogden	UT
84412	Ogden	UT
84414	Ogden	UT
84415	Ogden	UT
82051	Bosler	WY
82052	Buford	WY
82055	Centennial	WY
82058	Garrett	WY
82063	Jelm	WY
82070	Laramie	WY
82071	Laramie	WY
82072	Laramie	WY
82073	Laramie	WY
82083	Rock River	WY
82084	Tie Siding	WY
82410	Basin	WY
82411	Burlington	WY
82412	Byron	WY
82420	Cowley	WY
82421	Deaver	WY
82422	Emblem	WY
82426	Greybull	WY
82428	Hyattville	WY
82431	Lovell	WY
82432	Manderson	WY
82434	Otto	WY
82441	Shell	WY
82716	Gillette	WY
82717	Gillette	WY
82718	Gillette	WY
82725	Recluse	WY
82727	Rozet	WY
82731	Weston	WY
82732	Wright	WY
82301	Rawlins	WY
82321	Baggs	WY
82323	Dixon	WY
82324	Elk Mountain	WY
82325	Encampment	WY
82327	Hanna	WY
82329	Medicine Bow	WY
82331	Saratoga	WY
82332	Savery	WY
82334	Sinclair	WY
82335	Walcott	WY
82615	Shirley Basin	WY
82224	Lost Springs	WY
82229	Shawnee	WY
82633	Douglas	WY
82637	Glenrock	WY
82710	Aladdin	WY
82711	Alva	WY
82712	Beulah	WY
82714	Devils Tower	WY
82720	Hulett	WY
82721	Moorcroft	WY
82729	Sundance	WY
82310	Jeffrey City	WY
82501	Riverton	WY
82510	Arapahoe	WY
82512	Crowheart	WY
82513	Dubois	WY
82514	Fort Washakie	WY
82515	Hudson	WY
82516	Kinnear	WY
82520	Lander	WY
82523	Pavillion	WY
82524	Saint Stephens	WY
82642	Lysite	WY
82649	Shoshoni	WY
82212	Fort Laramie	WY
82217	Hawk Springs	WY
82218	Huntley	WY
82219	Jay Em	WY
82221	Lagrange	WY
82223	Lingle	WY
82240	Torrington	WY
82243	Veteran	WY
82244	Yoder	WY
82430	Kirby	WY
82443	Thermopolis	WY
82639	Kaycee	WY
82640	Linch	WY
82834	Buffalo	WY
82840	Saddlestring	WY
82001	Cheyenne	WY
82002	Cheyenne	WY
82003	Cheyenne	WY
82005	Fe Warren Afb	WY
82006	Cheyenne	WY
82007	Cheyenne	WY
82008	Cheyenne	WY
82009	Cheyenne	WY
82010	Cheyenne	WY
82050	Albin	WY
82053	Burns	WY
82054	Carpenter	WY
82059	Granite Canon	WY
82060	Hillsdale	WY
82061	Horse Creek	WY
82081	Meriden	WY
82082	Pine Bluffs	WY
83101	Kemmerer	WY
83110	Afton	WY
83111	Auburn	WY
83112	Bedford	WY
83114	Cokeville	WY
83116	Diamondville	WY
83118	Etna	WY
83119	Fairview	WY
83120	Freedom	WY
83121	Frontier	WY
83122	Grover	WY
83123	La Barge	WY
83124	Opal	WY
83126	Smoot	WY
83127	Thayne	WY
83128	Alpine	WY
82601	Casper	WY
82602	Casper	WY
82604	Casper	WY
82605	Casper	WY
82609	Casper	WY
82620	Alcova	WY
82630	Arminto	WY
82635	Edgerton	WY
82636	Evansville	WY
82638	Hiland	WY
82643	Midwest	WY
82644	Mills	WY
82646	Natrona	WY
82648	Powder River	WY
82222	Lance Creek	WY
82225	Lusk	WY
82227	Manville	WY
82242	Van Tassell	WY
82190	Yellowstone National Park	WY
82414	Cody	WY
82423	Frannie	WY
82433	Meeteetse	WY
82435	Powell	WY
82440	Ralston	WY
82450	Wapiti	WY
82201	Wheatland	WY
82210	Chugwater	WY
82213	Glendo	WY
82214	Guernsey	WY
82215	Hartville	WY
82801	Sheridan	WY
82831	Arvada	WY
82832	Banner	WY
82833	Big Horn	WY
82835	Clearmont	WY
82836	Dayton	WY
82837	Leiter	WY
82838	Parkman	WY
82839	Ranchester	WY
82842	Story	WY
82844	Wolf	WY
82845	Wyarno	WY
82922	Bondurant	WY
82923	Boulder	WY
82925	Cora	WY
82941	Pinedale	WY
83113	Big Piney	WY
83115	Daniel	WY
82322	Bairoil	WY
82336	Wamsutter	WY
82901	Rock Springs	WY
82902	Rock Springs	WY
82929	Little America	WY
82932	Farson	WY
82934	Granger	WY
82935	Green River	WY
82938	Mc Kinnon	WY
82942	Point Of Rocks	WY
82943	Reliance	WY
82945	Superior	WY
83001	Jackson	WY
83002	Jackson	WY
83011	Kelly	WY
83012	Moose	WY
83013	Moran	WY
83014	Wilson	WY
83025	Teton Village	WY
83414	Alta	WY
82930	Evanston	WY
82931	Evanston	WY
82933	Fort Bridger	WY
82936	Lonetree	WY
82937	Lyman	WY
82939	Mountain View	WY
82944	Robertson	WY
82401	Worland	WY
82442	Ten Sleep	WY
82701	Newcastle	WY
82715	Four Corners	WY
82723	Osage	WY
82730	Upton	WY
