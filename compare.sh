#!/bin/bash
cat 2016* | sort > ist.txt
ls /media/INTENSO1/pictures/ > soll.txt
meld soll.txt ist.txt
