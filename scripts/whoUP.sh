#!/bin/bash
echo
echo "To deal with WHO updates:"
echo "manually download all the weekly updates from "
echo "https://worldhealthorg-my.sharepoint.com/personal/karamg_who_int/_layouts/15/onedrive.aspx?d=w639b050f1ff942b99c98c365a54b5dc4&csf=1&web=1&e=Gn6I58&CID=6df6789d%2Dd2ab%2D4209%2Da8b0%2D68d823dcef26&id=%2Fpersonal%2Fkaramg%5Fwho%5Fint%2FDocuments%2FICTRP%20weekly%20updates&FolderCTID=0x012000A887E56A5DBFCE40A6E2745BB6601B76&view=0"
echo "after the last bulk file and place the exported zip file in this directory."
echo "The filename is of the format OneDrive*.zip"
echo

# after manual download

ls -la
unzip OneDrive*.zip

for file in ICTRPW*.zip
do
unzip -a "$file"
rm "$file"
done


FILES=`ls -1t *.csv`
i=1
touch upd2add.csv

echo "$FILES"
echo "----------"

for file in $FILES
do
echo "$i $file":
if [ $i == 1 ]
then
cat "$file" >> up2add.csv
else
python who_dedup_and_append.py "$file" upd2add.csv --no-header
fi
echo -n "res: "
grep -c . upd2add.csv

i=$[i + 1]

done
echo "done!"

sed -E 's/\\+\"/"/g' upd2add.csv > upd2addpp.csv

grep ^NCT06607471 current_who.csv > NCT06607471.csv
grep -v ^NCT06607471 current_who.cvs > last_whobulk.csv

python who_dedup_and_append.py last_whobulk.csv upd2addpp.csv --no-header

mv upd2addpp.csv who.csv

cat NCT06607471.csv >> who.csv

echo `date`
