.mode csv
.separator \t
.import scoutbook.tsv sb
.import scoutnet.tsv sn
.separator ,
CREATE VIEW mbc as select sb.BSAMemberID as MID, sb.Districts, sb.'Merit Badges' as mbs, sn.organizations from sb left join sn on sb.BSAMemberID=sn.memberid;
update sb set "Merit Badges"=replace("Merit Badges",'Signs, Signals, and Codes', 'Signs Signals and Codes');
update sb set "Merit Badges"=replace("Merit Badges",', ', '|');
update sb set "Merit Badges"=replace("Merit Badges",'Signs Signals and Codes','Signs, Signals, and Codes');
.mode list

select '| District | Merit Badge | Count |';
select '| --- | --- | ---: |';

WITH RECURSIVE splitdistrict(district, mbs, rest) AS (
  SELECT '', mbs, organizations || ',' FROM mbc
   UNION ALL
  SELECT ltrim(substr(rest, 0, instr(rest, ','))),
         mbs,
         substr(rest, instr(rest, ',')+1)
    FROM splitdistrict
   WHERE rest <> ''),

splitmb(district, mb, rest) AS (
  SELECT district, '', mbs || '|' FROM splitdistrict
   UNION ALL
  SELECT district, 
         substr(rest, 0, instr(rest, '|')),
         substr(rest, instr(rest, '|')+1)
    FROM splitmb
   WHERE rest <> '')
SELECT '',district, mb, count(*),''
  FROM splitmb 
 WHERE mb <> '' AND district <> ''
 GROUP BY district, mb
 ORDER BY district, mb;
 