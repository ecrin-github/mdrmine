#!/bin/bash
echo
echo "To deal with WHO updates"
echo

# after manual download

ls -la
unzip OneDrive*2026.zip

for file in ICTRPW*.zip 
do
unzip -a "$file"
rm "$file"
done


FILES=`ls -1t *.csv`
i=1
touch res.csv

echo "$FILES"
echo "----------"

for file in $FILES
do
echo "$i $file":
if [ $i == 1 ]
then
cat "$file" >> res.csv
else
python who_dedup_and_append.py "$file" res.csv --no-header
fi
echo -n "res: " 
grep -c . res.csv

i=$[i + 1]

done
echo "done!"

echo `date`
