#Merit Badge Counselor List

`MBCList` is a secure single page web application that creates a user friendly interface to the Merit Badge Counselor (MBC) information available in ScoutNET / ScoutBook.

#Table of Contents
- [Rational](#rational)
- [Usage](#usage)
- [Proximity Calculations](#proximity-calculations)
- [License](#license)
- [Dependencies](#dependencies)
- [FakeData Templates & data files](#fakedata-templates-data-files)
    - [template.tpl:](#templatetpl)
    - [template.streets.txt](#templatestreetstxt)
    - [template.cities.txt](#templatecitiestxt)
    - [template.zips.txt](#templatezipstxt)
    - [template.districts.txt](#templatedistrictstxt)
    - [template.badges.txt](#templatebadgestxt)

##Rational
ScoutBook doesn't an interface for district and council level volunteers to access the list of MBCs (e.g. Lone Scout coordinators, council advancement committee, district committee, district advancement chairs, etc.). ScoutBook has made it abundantly clear that they have no intention of supporting district or council level usage. And BSA has been equally clear about not allowing volunteers to contribute code to their systems.

Consequently, a mechanism for managing MBCs outside the BSA supplied infrastructure is necessary. That's where `MBCList` comes in.

This is not a full management system at present. This version provides a simple way for councils or districts to share their MBC information in a user friendly interface. It provides reasonable protection for the registered MBCs PII (Personally Identifiable Information). While this protection is not 100% foolproof, it should provide far more protection than a simple encrypted PDF or Excel file, for example.

##Usage
In order to generate a usable version of this program several steps need to be accomplished.

1. MBC Data from the council must be obtained and ingested
    - **TODO** add process step(s)
    - insert into the html file after `var data = [`
2. ZIP code data for the covered region can be obtained, for free, from [GeoNames](http://www.geonames.org)
    - download the data [for the US](http://download.geonames.org/export/zip/US.zip)
    - extract the data for your state(s): `perl -ne "chomp; @f=split(/\t/); print qq!"""$f[1]""": {lat: $f[9], lon: $f[10]},\n! if ($f[4] =~ /UT|WY|ID/i);" US.txt > zip.json`
    - insert it into the html file after `var zipData = {`
    - this data is updated regularly as ZIP codes change so you should consider refreshing this monthly or whenever you get new MBC data from the council if that's less frequent
3. Test the html file to make sure it works as expected
4. Encrypt the html file: `staticrypt mbclist.html trustworthy -e -o encrypted.html -t "Merit Badge Counselor Information (v20210220.1415)" -i "Password is the first point of the scout law (all lower case)"`
    - substitute an appropriate password, title, and message
5. Post the file on an appropriate hosting site
    - Note that [Guide to Advancement 7.0.2.2 Web-Based Counselor Lists](https://www.scouting.org/resources/guide-to-advancement/the-merit-badge-program/#7022) says [emphasis added]
    > Online counselor lists present a number of challenges. **They should only be placed on official council websites that conform to the National Council guidelines.** Council sites must consider the safety and privacy of their members and participants by obtaining the necessary permissions to release information about or images of any individual. Give attention to protecting counselor privacy. Limit access to those who have merit badge– related responsibilities, such as advancement committee members and chairs, or unit leaders and selected assistants. Scouts should not have access. Their interaction with the Scoutmaster in discussing work on a badge, and obtaining a counselor’s name, is an important part of the merit badge plan.

##Proximity Calculations
We use ZIP code centroids (expressed as latitude and longitude) from [GeoNames](http://www.geonames.org/) to do approximate distance calculations. These are based on [ZIP Code Tabulation Areas (ZCTAs)](https://www.census.gov/programs-surveys/geography/guidance/geo-areas/zctas.html) defined by the post office and the US Census Bureau. The results are an "as the crow flies" *approximate* distance between two ZIP codes.

Here's how the distance is calculated. At the equator 1 degree of longitude is about 69 miles (24,901 miles / 360 degrees = 69.169). At the poles 1 degree is 0 feet.

The cosign function is 0 at 90 degrees and 1 at 0 degrees. Therefore, an adequate approximation of the length of 1 degree of longitude is:
 `cos(latitude) * 69`

At the equator you can use the [Pythagorean theorem](https://en.wikipedia.org/wiki/Pythagorean_theorem) to calculate distance:

`distance = sqrt( (lat1-lat2)^2 + (long1-long2)^2 ) * 69`

*Note: You may be wondering what happens if, for example, lat2 is larger than lat1 so we end up with a negative result when we subtract. It doesn't matter because we are squaring the result so it will always be positive (-2 * -2 = 4).*

We simply need to add in the `cos(lat)` adjustment for the longitude. Using the average of the two latitudes gives the best result. The equasion is a little messy, but it works:

`distance = sqrt( (lat1-lat2)^2 + ( cos( ((lat1+lat2)/2) ) * (long1-long2) )^2 ) * 69`

This formula is used with the latitude and longitude from the ZIP code database to calculate the distance between the target ZIP code and the ZIP code of each MBC. This is only an approximation since everyone in the same ZIP code uses the same coordinates. People on the border adjoining two ZIP codes would be much closer than reported while those on opposite sides of their respective adjoining ZIP code areas would be much further away than reported.

As someone wisely said, *"ZIP codes were designed for mail delivery, not for the convenience of geo-spatial programmers, which means that they are not the best source of information. But they are ubiquitous in the US - and ubiquitous and messy beats clean and unavailable any day."*

##License
Copyright (c) 2021 by James Brown

Subject to the terms and conditions listed below, the licensor hereby grants to any person obtaining a copy of this software and associated documentation (the "Software"), free of charge, a royalty-free, worldwide, non-exclusive, non-sublicensable, irrevocable license to use, copy, modify, merge, publish, distribute, reproduce and share this software, in whole or in part, for noncommercial purposes only and to produce, reproduce and share any derivative works for noncommercial purposes only subject to the following conditions:

- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

- Any derivative works of the Software must be licensed under the same terms.

- The **National Council** of the Boy Scouts of America and it's employees, contractors, and subsidiaries are **expressly forbidden** from using any portion of the Software in any way whatsoever, including but not limited to incorporating it into other software or creating derivative works, without a specific written license from the original author, James Brown. This includes any subsidiaries or affiliates of the National Council such as, but not limited to ScoutBook, Exploring, etc.

- Notwithstanding any other provisions of this license, Councils, Districts and Units chartered by the Boy Scouts of America, other than the National Council, may use the Software free of charge without obtaining a written license, subject to all of the other terms of this license.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

##Dependencies
* [jQuery](https://jquery.com/) for basic JS access to the DOM
* [DataTables plug-in for jQuery](https://datatables.net/) to do table management, sorting, searching, and filtering
* [StatiCrypt](https://www.npmjs.com/package/staticrypt) encrypts the final webpage output (optional, but highly encouraged).
* [Strawberry Perl for Windows](https://strawberryperl.com/) for ingesting the raw CSV data from the council. Any Perl (the scripts are quite simple and generic) will do, I just recommend Strawberry for Windows.
* [GeoNames](http://www.geonames.org/) is the source for the ZIP code centroid data. Download the US.zip file from [this directory](http://download.geonames.org/export/zip/)
* [lucapette/fakedata: CLI utility for fake data generation](https://github.com/lucapette/fakedata) was used for generating fake data for testing and demo purposes. This is not necessary for production use.

##FakeData Templates & data files

For testing or demonstration purposes I created some fake data to represent the merit badge counselor information that can be exported from the BSA systems.

Below are the instructions and all the data used to generate the fake merit badge counselor information using [fakedata](https://github.com/lucapette/fakedata).

CLI to generate fake list of MBCs:

`echo var data =[ > data.js && fakedata -T template.tpl -l 10000 >> data.js && echo ]; >> data.js`

####template.tpl:
```
{
    name: "{{Name}}",
    address: "{{Int 100 9999}} {{File "template.streets.txt"}}",
    city: "{{File "template.cities.txt"}}",
    state: "{{Enum "UT" "ID" "WY"}}",
    zip: "{{File "template.zips.txt"}}",
    phone: [{{ range Loop 1 4 }}{type:"{{Enum "home" "work" "cell"}}", number:"{{Int 100 900}}-{{Int 100 900}}-{{Int 1000 9999}}"}, {{ end }}],
    email: "{{Email}}",
    district: "{{File "template.districts.txt"}}",
    bsaid: "{{Int 1000000 9999999}}",
    meritbadges: [{{ range Loop 4 16 }}"{{ File "template.badges.txt" }}", {{ end }}],
    workwith: "{{ Enum "all" "districts:Timpanogos" "units:2021"}}"
},
```
This template makes use of a number of data files. The contents of these are included here.

####template.streets.txt
```
Park Street
Magnolia Court
Ashley Court
Locust Street
Lantern Lane
Monroe Drive
Deerfield Drive
Meadow Lane
Bridle Court
Roberts Road
Oak Avenue
Morris Street
Street Road
Beech Street
Grant Street
Jackson Avenue
5th Street
Oxford Court
Route 10
Augusta Drive
5th Avenue
Forest Drive
5th Street North
Hawthorne Avenue
Forest Street
Route 64
King Street
Evergreen Drive
Division Street
Myrtle Avenue
Linden Street
Canterbury Court
13th Street
Roosevelt Avenue
Magnolia Drive
Charles Street
Route 30
Hilltop Road
River Road
Route 202
Route 41
Route 1
Route 4
Cambridge Court
Green Street
Heather Court
Wall Street
Ivy Court
Devon Road
Church Street North
Somerset Drive
Broad Street
Creekside Drive
Cambridge Road
Aspen Court
Grant Avenue
Chapel Street
Beechwood Drive
Front Street
5th Street East
Bridge Street
Hickory Lane
Madison Avenue
Devonshire Drive
Creek Road
Eagle Street
Belmont Avenue
James Street
14th Street
Laurel Drive
Church Road
Cleveland Street
Arlington Avenue
Edgewood Drive
Maple Avenue
Summit Street
Maple Lane
2nd Street East
Orchard Street
Hill Street
Elm Avenue
Laurel Street
Parker Street
Spruce Street
Broad Street West
Pleasant Street
Market Street
Madison Street
Willow Drive
4th Avenue
5th Street South
Adams Avenue
Valley View Road
11th Street
Taylor Street
Main Street
Front Street North
Cypress Court
Sycamore Street
Lawrence Street
Glenwood Avenue
9th Street West
Durham Court
Lake Avenue
Jefferson Avenue
Cleveland Avenue
Strawberry Lane
Ivy Lane
Cooper Street
Pheasant Run
Monroe Street
Amherst Street
Jefferson Court
Church Street
3rd Avenue
Elm Street
Andover Court
Ridge Street
2nd Street North
Holly Drive
Route 100
Shady Lane
Chestnut Street
Main Street South
Cherry Lane
Cambridge Drive
Harrison Street
Oak Lane
Madison Court
Harrison Avenue
Cedar Avenue
River Street
6th Street
3rd Street East
Walnut Avenue
Forest Avenue
Cedar Lane
Bayberry Drive
Orange Street
Old York Road
Edgewood Road
Railroad Avenue
Rosewood Drive
Ann Street
Route 5
Country Club Drive
Mulberry Court
Durham Road
Country Lane
Willow Lane
Brown Street
Warren Avenue
Penn Street
New Street
Orchard Avenue
School Street
State Street
Broadway
Columbia Street
Holly Court
Woodland Road
Aspen Drive
Elmwood Avenue
Summit Avenue
7th Avenue
York Road
Virginia Avenue
Colonial Drive
4th Street North
Spruce Avenue
Dogwood Drive
Surrey Lane
Union Street
Hanover Court
Garfield Avenue
John Street
Cardinal Drive
Washington Street
Washington Avenue
8th Street South
Maple Street
2nd Avenue
Park Avenue
Heather Lane
Walnut Street
Route 17
Briarwood Court
Sycamore Lane
12th Street East
Mechanic Street
Fawn Lane
Atlantic Avenue
Valley View Drive
3rd Street North
Center Street
Poplar Street
Berkshire Drive
Heritage Drive
East Street
Woodland Drive
West Street
Dogwood Lane
10th Street
Cedar Street
Mill Road
Clay Street
Pearl Street
Virginia Street
Fairway Drive
Prospect Street
Route 32
Brandywine Drive
Water Street
Jefferson Street
Fieldstone Drive
Garden Street
Canterbury Road
West Avenue
Marshall Street
Primrose Lane
Victoria Court
Linda Lane
4th Street South
Circle Drive
Ridge Road
Arch Street
Schoolhouse Lane
Fulton Street
College Avenue
Main Street North
Clark Street
3rd Street West
Vine Street
Winding Way
Front Street South
Brook Lane
North Street
Cemetery Road
Central Avenue
Tanglewood Drive
Sunset Avenue
Lincoln Avenue
Eagle Road
Sherman Street
Lexington Court
Route 70
Warren Street
Sunset Drive
Myrtle Street
Cedar Court
Hillcrest Avenue
Linden Avenue
2nd Street West
Hartford Road
Mulberry Lane
Riverside Drive
Liberty Street
Park Drive
Route 2
6th Street North
State Street East
Olive Street
Buttonwood Drive
Race Street
9th Street
Route 27
Park Place
Windsor Drive
Lake Street
Cottage Street
Delaware Avenue
North Avenue
Main Street West
Grove Avenue
Manor Drive
Fairview Avenue
6th Street West
1st Avenue
Lafayette Avenue
William Street
Wood Street
Lakeview Drive
Overlook Circle
Fawn Court
Locust Lane
Hillcrest Drive
Route 44
Lafayette Street
Williams Street
Canterbury Drive
Redwood Drive
Lilac Lane
Spring Street
Queen Street
Valley Road
Route 9
Evergreen Lane
Route 11
Hillside Drive
Court Street
Essex Court
Franklin Avenue
1st Street
Magnolia Avenue
Cross Street
4th Street
Sherwood Drive
3rd Street
Highland Avenue
2nd Street
Prospect Avenue
Henry Street
Oak Street
Summer Street
Route 6
Pennsylvania Avenue
Elizabeth Street
Cobblestone Court
8th Street
Route 20
Laurel Lane
White Street
8th Avenue
Orchard Lane
Brookside Drive
Hamilton Street
Franklin Street
12th Street
5th Street West
7th Street
Glenwood Drive
Franklin Court
Homestead Drive
Fairview Road
Colonial Avenue
Willow Street
Cherry Street
Lexington Drive
Meadow Street
Pine Street
Sheffield Drive
Mulberry Street
B Street
Main Street East
Hudson Street
Hickory Street
Jackson Street
York Street
8th Street West
Hawthorne Lane
Hillside Avenue
Buckingham Drive
Smith Street
6th Avenue
Highland Drive
Church Street South
Depot Street
Hamilton Road
Inverness Drive
Westminster Drive
Route 7
Grand Avenue
Catherine Street
4th Street West
South Street
Howard Street
Country Club Road
Carriage Drive
Windsor Court
Rose Street
George Street
Chestnut Avenue
Briarwood Drive
Jones Street
Canal Street
Maiden Lane
Route 29
College Street
Grove Street
Ridge Avenue
Woodland Avenue
High Street
Oxford Road
Railroad Street
Crescent Street
Mill Street
East Avenue
Bay Street
Devon Court
Bridle Lane
Bank Street
Adams Street
Clinton Street
Lincoln Street
Valley Drive
Euclid Avenue
Academy Street
Sycamore Drive
Willow Avenue
Pin Oak Drive
```

####template.cities.txt
```
Aberdeen
Afton
Ahsahka
Aladdin
Albin
Albion
Alcova
Almo
Alpine
Alta
Altamont
Alton
Altonah
Alva
American Falls
American Fork
Aneth
Annabella
Antimony
Arapahoe
Arbon
Arco
Arimo
Arminto
Arvada
Ashton
Athol
Atlanta
Atomic City
Auburn
Aurora
Avery
Axtell
Baggs
Bairoil
Bancroft
Banks
Banner
Basalt
Basin
Bayview
Bear River City
Beaver
Bedford
Bellevue
Bern
Beryl
Beulah
Bicknell
Big Horn
Big Piney
Bingham Canyon
Blackfoot
Blanchard
Blanding
Bliss
Bloomington
Bluebell
Bluff
Boise
Bonanza
Bondurant
Bonners Ferry
Bosler
Boulder
Bountiful
Bovill
Brian Head
Brigham City
Bruneau
Bryce
Buffalo
Buford
Buhl
Burley
Burlington
Burns
Byron
Cache Junction
Calder
Caldwell
Cambridge
Cannonville
Carey
Careywood
Carmen
Carpenter
Cascade
Casper
Castle Dale
Castleford
Cataldo
Cedar City
Cedar Valley
Centennial
Centerfield
Centerville
Central
Challis
Chester
Cheyenne
Chugwater
Circleville
Cisco
Clark Fork
Clarkia
Clarkston
Clawson
Clayton
Clearfield
Clearmont
Cleveland
Clifton
Coalville
Cobalt
Cocolalla
Cody
Coeur d'Alene
Cokeville
Colburn
Collinston
Conda
Coolin
Cora
Corinne
Cornish
Corral
Cottonwood
Council
Cowley
Craigmont
Crowheart
Croydon
Culdesac
Dammeron Valley
Daniel
Dayton
Deary
Deaver
Declo
Delta
Desmet
Devils Tower
Deweyville
Diamondville
Dietrich
Dingle
Dixon
Donnelly
Douglas
Dover
Downey
Draper
Driggs
Dubois
Duchesne
Duck Creek Village
Dugway
Dutch John
Eagle
Eagle Mountain
East Carbon
Eastport
Echo
Eden
Edgerton
Elberta
Elk City
Elk Mountain
Elk River
Ellis
Elmo
Elsinore
Emblem
Emery
Emmett
Encampment
Enterprise
Ephraim
Escalante
Etna
Eureka
Evanston
Evansville
Fairfield
Fairview
Farmington
Farson
Fayette
Fe Warren Afb
Felt
Fenn
Ferdinand
Fernwood
Ferron
Fielding
Filer
Fillmore
Firth
Fish Haven
Fort Bridger
Fort Duchesne
Fort Hall
Fort Laramie
Fort Washakie
Fountain Green
Four Corners
Franklin
Frannie
Freedom
Frontier
Fruitland
Garden City
Garden Valley
Garland
Garrett
Garrison
Genesee
Geneva
Georgetown
Gibbonsville
Gillette
Glendale
Glendo
Glenns Ferry
Glenrock
Glenwood
Gooding
Goshen
Grace
Grand View
Granger
Grangeville
Granite Canon
Grantsville
Green River
Greencreek
Greenleaf
Greenville
Greenwich
Greybull
Grouse Creek
Grover
Guernsey
Gunlock
Gunnison
Hagerman
Hailey
Hamer
Hammett
Hanksville
Hanna
Hansen
Harrison
Hartville
Harvard
Hatch
Hawk Springs
Hayden
Hazelton
Heber City
Helper
Henefer
Henrieville
Herriman
Heyburn
Hiland
Hildale
Hill Afb
Hill City
Hillsdale
Hinckley
Holbrook
Holden
Homedale
Honeyville
Hooper
Hope
Horse Creek
Horseshoe Bend
Howe
Howell
Hudson
Hulett
Huntington
Huntley
Huntsville
Hurricane
Huston
Hyattville
Hyde Park
Hyrum
Ibapah
Idaho City
Idaho Falls
Indian Valley
Inkom
Iona
Irwin
Island Park
Ivins
Jackson
Jay Em
Jeffrey City
Jelm
Jensen
Jerome
Joseph
Juliaetta
Junction
Kamas
Kamiah
Kanab
Kanarraville
Kanosh
Kaycee
Kaysville
Kellogg
Kelly
Kemmerer
Kendrick
Kenilworth
Ketchum
Kimberly
King Hill
Kingston
Kinnear
Kirby
Koosharem
Kooskia
Kootenai
Kuna
La Barge
La Sal
La Verkin
Laclede
Lagrange
Lake Fork
Lake Powell
Laketown
Lance Creek
Lander
Lapoint
Lapwai
Laramie
Lava Hot Springs
Layton
Leadore
Leamington
Leeds
Lehi
Leiter
Lemhi
Lenore
Letha
Levan
Lewiston
Lewisville
Linch
Lindon
Lingle
Little America
Loa
Logan
Lonetree
Lost Springs
Lovell
Lowman
Lucile
Lusk
Lyman
Lynndyl
Lysite
Mackay
Macks Inn
Magna
Malad City
Malta
Manderson
Manila
Manti
Mantua
Manville
Mapleton
Marsing
Marysvale
May
Mayfield
Mc Kinnon
McCall
McCammon
Meadow
Medicine Bow
Medimont
Meeteetse
Melba
Menan
Mendon
Meriden
Meridian
Mesa
Mexican Hat
Middleton
Midvale
Midway
Midwest
Milford
Mills
Millville
Minersville
Minidoka
Moab
Modena
Mona
Monroe
Monteview
Montezuma Creek
Monticello
Montpelier
Monument Valley
Moorcroft
Moore
Moose
Moran
Moreland
Morgan
Moroni
Moscow
Mount Carmel
Mount Pleasant
Mountain Home
Mountain Home Afb
Mountain View
Moyie Springs
Mullan
Murphy
Murray
Murtaugh
Myton
Nampa
Naples
Natrona
Neola
Nephi
New Harmony
New Meadows
New Plymouth
Newcastle
Newdale
Newton
Nezperce
Nordman
North Fork
North Salt Lake
Notus
Oak City
Oakley
Ogden
Ola
Oldtown
Opal
Orangeville
Orderville
Orem
Orofino
Osage
Osburn
Otto
Panguitch
Paradise
Paragonah
Paris
Park City
Park Valley
Parker
Parkman
Parma
Parowan
Paul
Pavillion
Payette
Payson
Peck
Peoa
Picabo
Pierce
Pine Bluffs
Pine Valley
Pinedale
Pinehurst
Pingree
Placerville
Pleasant Grove
Plummer
Plymouth
Pocatello
Point Of Rocks
Pollock
Ponderay
Portage
Porthill
Post Falls
Potlatch
Powder River
Powell
Preston
Price
Priest River
Princeton
Providence
Provo
Ralston
Ranchester
Randlett
Randolph
Rathdrum
Rawlins
Recluse
Redmond
Reliance
Reubens
Rexburg
Richfield
Richmond
Rigby
Riggins
Ririe
Riverside
Riverton
Roberts
Robertson
Rock River
Rock Springs
Rockland
Rockville
Rogerson
Roosevelt
Roy
Rozet
Rupert
Rush Valley
Saddlestring
Sagle
Saint Anthony
Saint Charles
Saint George
Saint Maries
Saint Stephens
Salem
Salina
Salmon
Salt Lake City
Sandpoint
Sandy
Santa
Santa Clara
Santaquin
Saratoga
Saratoga Springs
Savery
Scipio
Sevier
Shawnee
Shell
Shelley
Sheridan
Shirley Basin
Shoshone
Shoshoni
Shoup
Sigurd
Silverton
Sinclair
Smelterville
Smithfield
Smoot
Snowville
Soda Springs
South Jordan
Spanish Fork
Spencer
Spirit Lake
Spring City
Springdale
Springfield
Springville
Stanley
Star
Sterling
Stites
Stockton
Story
Sugar City
Summit
Sun Valley
Sundance
Sunnyside
Superior
Swan Valley
Swanlake
Sweet
Syracuse
Tabiona
Talmage
Teasdale
Ten Sleep
Tendoy
Tensed
Terreton
Teton
Teton Village
Tetonia
Thatcher
Thayne
Thermopolis
Thompson
Tie Siding
Tooele
Toquerville
Torrey
Torrington
Tremonton
Trenton
Tridell
Tropic
Troy
Twin Falls
Ucon
Upton
Van Tassell
Vernal
Vernon
Veteran
Veyo
Victor
Viola
Virgin
Walcott
Wales
Wallace
Wallsburg
Wamsutter
Wapiti
Warren
Washington
Wayan
Weippe
Weiser
Wellington
Wellsville
Wendell
Wendover
West Jordan
West Valley City
Weston
Wheatland
White Bird
Whiterocks
Wilder
Willard
Wilson
Winchester
Wolf
Woodruff
Woods Cross
Worland
Worley
Wright
Wyarno
Yellow Pine
Yellowstone National Park
Yoder
```

####template.zips.txt
```
82001
82002
82003
82005
82006
82007
82008
82009
82010
82050
82051
82052
82053
82054
82055
82058
82059
82060
82061
82063
82070
82071
82072
82073
82081
82082
82083
82084
82190
82201
82210
82212
82213
82214
82215
82217
82218
82219
82221
82222
82223
82224
82225
82227
82229
82240
82242
82243
82244
82301
82310
82321
82322
82323
82324
82325
82327
82329
82331
82332
82334
82335
82336
82401
82410
82411
82412
82414
82420
82421
82422
82423
82426
82428
82430
82431
82432
82433
82434
82435
82440
82441
82442
82443
82450
82501
82510
82512
82513
82514
82515
82516
82520
82523
82524
82601
82602
82604
82605
82609
82615
82620
82630
82633
82635
82636
82637
82638
82639
82640
82642
82643
82644
82646
82648
82649
82701
82710
82711
82712
82714
82715
82716
82717
82718
82720
82721
82723
82725
82727
82729
82730
82731
82732
82801
82831
82832
82833
82834
82835
82836
82837
82838
82839
82840
82842
82844
82845
82901
82902
82922
82923
82925
82929
82930
82931
82932
82933
82934
82935
82936
82937
82938
82939
82941
82942
82943
82944
82945
83001
83002
83011
83012
83013
83014
83025
83101
83110
83111
83112
83113
83114
83115
83116
83118
83119
83120
83121
83122
83123
83124
83126
83127
83128
83201
83202
83203
83204
83205
83206
83209
83210
83211
83212
83213
83214
83215
83217
83218
83220
83221
83223
83226
83227
83228
83229
83230
83232
83233
83234
83235
83236
83237
83238
83239
83241
83243
83244
83245
83246
83250
83251
83252
83253
83254
83255
83256
83261
83262
83263
83271
83272
83274
83276
83277
83278
83281
83283
83285
83286
83287
83301
83302
83303
83311
83312
83313
83314
83316
83318
83320
83321
83322
83323
83324
83325
83327
83328
83330
83332
83333
83334
83335
83336
83337
83338
83340
83341
83342
83343
83344
83346
83347
83348
83349
83350
83352
83353
83354
83355
83401
83402
83403
83404
83405
83406
83414
83415
83420
83421
83422
83423
83424
83425
83427
83428
83429
83431
83433
83434
83435
83436
83438
83440
83441
83442
83443
83444
83445
83446
83448
83449
83450
83451
83452
83454
83455
83460
83462
83463
83464
83465
83466
83467
83468
83469
83501
83520
83522
83523
83524
83525
83526
83530
83531
83533
83535
83536
83537
83539
83540
83541
83542
83543
83544
83545
83546
83547
83548
83549
83552
83553
83554
83555
83601
83602
83604
83605
83606
83607
83610
83611
83612
83615
83616
83617
83619
83622
83623
83624
83626
83627
83628
83629
83630
83631
83632
83633
83634
83635
83636
83637
83638
83639
83641
83642
83643
83644
83645
83646
83647
83648
83650
83651
83652
83653
83654
83655
83656
83657
83660
83661
83666
83669
83670
83671
83672
83676
83677
83680
83686
83687
83701
83702
83703
83704
83705
83706
83707
83708
83709
83711
83712
83713
83714
83715
83716
83717
83719
83720
83722
83724
83725
83726
83728
83729
83731
83732
83735
83756
83799
83801
83802
83803
83804
83805
83806
83808
83809
83810
83811
83812
83813
83814
83815
83816
83821
83822
83823
83824
83825
83826
83827
83830
83832
83833
83834
83835
83836
83837
83839
83840
83841
83842
83843
83844
83845
83846
83847
83848
83849
83850
83851
83852
83853
83854
83855
83856
83857
83858
83860
83861
83864
83865
83866
83867
83868
83869
83870
83871
83872
83873
83874
83876
83877
84001
84002
84003
84004
84005
84006
84007
84008
84009
84010
84011
84013
84014
84015
84016
84017
84018
84020
84021
84022
84023
84024
84025
84026
84027
84028
84029
84031
84032
84033
84034
84035
84036
84037
84038
84039
84040
84041
84042
84043
84044
84045
84046
84047
84049
84050
84051
84052
84053
84054
84055
84056
84057
84058
84059
84060
84061
84062
84063
84064
84065
84066
84067
84068
84069
84070
84071
84072
84073
84074
84075
84076
84078
84079
84080
84081
84082
84083
84084
84085
84086
84087
84088
84089
84090
84091
84092
84093
84094
84095
84096
84097
84098
84101
84102
84103
84104
84105
84106
84107
84108
84109
84110
84111
84112
84113
84114
84115
84116
84117
84118
84119
84120
84121
84122
84123
84124
84125
84126
84127
84128
84129
84130
84131
84132
84133
84134
84136
84138
84139
84141
84143
84145
84147
84148
84150
84151
84152
84157
84158
84165
84170
84171
84180
84184
84189
84190
84199
84201
84244
84301
84302
84304
84305
84306
84307
84308
84309
84310
84311
84312
84313
84314
84315
84316
84317
84318
84319
84320
84321
84322
84323
84324
84325
84326
84327
84328
84329
84330
84331
84332
84333
84334
84335
84336
84337
84338
84339
84340
84341
84401
84402
84403
84404
84405
84407
84408
84409
84412
84414
84415
84501
84510
84511
84512
84513
84515
84516
84518
84520
84521
84522
84523
84525
84526
84528
84529
84530
84531
84532
84533
84534
84535
84536
84537
84539
84540
84542
84601
84602
84603
84604
84605
84606
84620
84621
84622
84623
84624
84626
84627
84628
84629
84630
84631
84632
84633
84634
84635
84636
84637
84638
84639
84640
84642
84643
84644
84645
84646
84647
84648
84649
84651
84652
84653
84654
84655
84656
84657
84660
84662
84663
84664
84665
84667
84701
84710
84711
84712
84713
84714
84715
84716
84718
84719
84720
84721
84722
84723
84724
84725
84726
84728
84729
84730
84731
84732
84733
84734
84735
84736
84737
84738
84739
84740
84741
84742
84743
84744
84745
84746
84747
84749
84750
84751
84752
84753
84754
84755
84756
84757
84758
84759
84760
84761
84762
84763
84764
84765
84766
84767
84770
84771
84772
84773
84774
84775
84776
84779
84780
84781
84782
84783
84784
84790
84791
```

####template.districts.txt
```
Old Ephraim
Weber Rapids
Jim Bridger
Thurston Peak
Oquirrh Mountain
Wasatch Peaks
Timpanogos
Silver Sage
Spanish Trails
```

####template.badges.txt
```
Camping
Citizenship in the Community
Citizenship in the Nation
Citizenship in the World
Communication
Cooking
Cycling
Emergency Preparedness
Environmental Science
Family Life
First Aid
Hiking
Lifesaving
Personal Fitness
Personal Management
Sustainability
Swimming
American Business
American Cultures
American Heritage
American Labor
Animal Science
Animation
Archaeology
Archery
Architecture
Art
Astronomy
Athletics
Automotive Maintenance
Aviation
Backpacking
Basketry
Bird Study
Bugling
Canoeing
Chemistry
Chess
Climbing
Coin Collecting
Collections
Composite Materials
Computers
Crime Prevention
Dentistry
Digital Technology
Disabilities Awareness
Dog Care
Drafting
Electricity
Electronics
Energy
Engineering
Entrepreneurship
Farm Mechanics
Fingerprinting
Fire Safety
Fish and Wildlife Management
Fishing
Fly Fishing
Forestry
Game Design
Gardening
Genealogy
Geocaching
Geology
Golf
Graphic Arts
Home Repairs
Horsemanship
Indian Lore
Insect Study
Inventing
Journalism
Kayaking
Landscape Architecture
Law
Leatherwork
Mammal Study
Medicine
Metalwork
Mining in Society
Model Design and Building
Motorboating
Moviemaking
Music
Nature
Nuclear Science
Oceanography
Orienteering
Painting
Pets
Photography
Pioneering
Plant Science
Plumbing
Pottery
Programming
Public Health
Public Speaking
Pulp and Paper
Radio
Railroading
Reading
Reptile and Amphibian Study
Rifle Shooting
Robotics
Rowing
Safety
Salesmanship
Scholarship
Scouting Heritage
Scuba Diving
Sculpture
Search and Rescue
Shotgun Shooting
Signs, Signals, and Codes
Skating
Small Boat Sailing
Snow Sports
Soil and Water Conservation
Space Exploration
Sports
Stamp Collecting
Surveying
Textile
Theater
Traffic Safety
Truck Transportation
Veterinary Medicine
Water Sports
Weather
Welding
Whitewater
Wilderness Survival
Wood Carving
Woodwork
```
