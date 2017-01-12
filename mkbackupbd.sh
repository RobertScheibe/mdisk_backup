#!/bin/bash
backupDBDir=/home/robert/Documents/backupDatabase
udbDataDir=/home/robert/data

echo "Bluray Disk Backup"
echo "==================="
echo "Generate 25GB udf filesystem on" $udbDataDir 
rm $udbDataDir/bd.udf
truncate --size=25GB $udbDataDir/bd.udf
if [ $? -ne 0 ]; then
	echo "cannot create udf file"
	exit 1
fi
mkudffs $udbDataDir/bd.udf
if [ $? -ne 0 ]; then
	echo "cannot create udf file system"
	exit 1
fi

echo "mount bd.udf on /media/loop0 device"
mount $udbDataDir/bd.udf
sudo chown robert:users /media/loop0/ -R
rm /media/loop0/lost+found/ -rf
echo "25GB bd.udf prepared and mounted to /media/loop0. After copying all files insert disk and enter 'y' to go on:"
read answer

#unmount loop device, check md5 and write to disk
ret=1
if [ "$answer" == "y" ]; then
	content=`ls /media/loop0`
	while [ $ret -ne 0 ] 
	do
		umount /media/loop0
		ret=$?
		sleep 2
	done

	echo "The md5 calculation will take some time..."
	md5sum $udbDataDir/bd.udf > $udbDataDir/bd_udf.md5
	#maybe use e2label or tune2fs to label the udf with the md5 sum?
	echo "Now the .udf image will be written to bluray disk"
	#to suppress dvd ejection:
	#-use-the-force-luke=notray 
	growisofs -use-the-force-luke=spare:none -speed=4 -Z /dev/sr0=$udbDataDir/bd.udf
else 
	umount /media/loop0
	exit 1;
fi

#check for md5sum 
echo "Please reinsert the BD to check the md5sum. Enter 'y' to go on!"
read answer
ret=1
if [ "$answer" == "y" ]; then
	echo "check the md5sum of written bluray disk..."
	while [ $ret -ne 0 ] 
	do
		dd_rescue /dev/sr0 - | head -c `stat --format=%s $udbDataDir/bd.udf` | md5sum > $udbDataDir/bd_disk.md5
		ret=$?
		sleep 2
	done
	md5_udf=`cat $udbDataDir/bd_udf.md5 | awk '{print $1}'`
	md5_disk=`cat $udbDataDir/bd_disk.md5 | awk '{print $1}'`
	echo "md5sums: duf-> " $md5_udf  " and disk -> " $md5_disk
	if [ "$md5_udf" != "$md5_disk" ]; then
		echo "error: md5 error, disk may be corrupt!"
		exit 1;
	else
		echo "Success! md5 sums of .udf and disk are matching. Writing disk content to database in $backupDBDir."
	fi

	#write db content (directory listing of disk)
	db_name=`date +"%Y%m%d"`_$(printf '%03d' "$((`cat $backupDBDir/bd_count.txt`+1))")_`cat $udbDataDir/bd_disk.md5 | awk '{print $1}'`.txt
	echo "$content"  > $backupDBDir/$db_name
	echo $((`cat $backupDBDir/bd_count.txt`+1)) > $backupDBDir/bd_count.txt
	eject;
	exit 0;
else
	exit 1;
fi 
