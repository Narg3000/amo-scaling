#!/bin/bash
# Script to automatically create a new test directory of specified name from current directory

if [[ -z $1 ]]; then 
	echo "Missing required argument";
	exit 3;
fi

echo $(pwd)

if ! [[ -e inputs ]]; then 
	echo "No Inputs Directory ";
	exit 1;
elif ! [[ -d inputs ]]; then
	echo "Inputs is not a directory!";
	exit 1;
else
	echo "Found inputs...";
fi

TESTPATH=$(pwd)
mkdir $TESTPATH/$1
cd $TESTPATH/$1
ln -s $TESTPATH/inputs/* . 

if [[ -e $TESTPATH/submission ]]; then
	cp $TESTPATH/submission submission
fi	
