#!/usr/bin/env perl

# Extract county maps for the council

print <<EOS;
{
"type": "FeatureCollection",
"features": [
EOS

while(<>)
{
    chomp;
    print "$_,\n" if (/"State":\s*"49"/i
        || (/"State":\s*"16"/i && /"NAME":\s*"(Bear Lake|Franklin)"/i)
        || (/"State":\s*"56"/i && /"NAME":\s*"(Uinta|Sweetwater|Lincoln|Sublette)"/i));
}

print <<EOS;
]};
EOS
