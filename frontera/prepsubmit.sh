#!/bin/bash

#----------------------------------------------------
# This is a program which takes job name, inputs directory, number 
# of nodes, number of mpi tasks, partition, and runtime as positional 
# arguments and creates a directory with inputs and job submission 
# script with directory name jobname_[TIME]
# 
# DESIGNED FOR FRONTERA
# Author: Autumn Bauman 
# 
# Exit codes: 2 = invalid arguments, 3 = SLURM error


#Input arguments:
args=($1 $2 $3 $4 $5 $6 $7 $8)
#echo "$args"
NODECORES=56
DEFRMTPT="$WORK/rmt/build/bin/rmt.x"

# This handels the help menu 
printhelp() {
    echo "  This is the prepjob command help menu"
    echo "  USEAGE:"
    echo "  prepjob [--help -h] | Print this menu" 
    echo "  prepjob [-j=jobname] [-i=inputs_dir] [-N=n_nodes] [-n=n_tasks] [-p=default_partition] [-r=00:30:00] [-e=EMAIL] [-R=path_to_rmt.x]"
    echo "  the [-j, -i, -N, -n] are required for it to run"
    return 0
}


pos1=$1
# if the first argument exists and is help...
if ([[ ${pos1,,} = "--help" ]] || [[ ${pos1,,} = '-h' ]]); then
    printhelp
    exit 0
# if there are no arguments...
elif [[ -z $pos1 ]]; then
    printhelp
    echo "You need to have *some* arguments silly billy"
    exit 2
fi

# Parse the args
JOBNAME=""
INDIR=""
NODES=""
TASKS=""
PARTT=""
RNTME=""
EMAIL=""
RMTPT=""
SENDMAIL="1"

for i in "${args[@]}"; do
    
    if [[ ${i:0:2} = "-j" ]]; then
        JOBNAME=${i:3}
    elif [[ ${i:0:2} = "-i" ]]; then
        INDIR=${i:3}
    elif [[ ${i:0:2} = "-N" ]]; then
        NODES=${i:3}
    elif [[ ${i:0:2} = "-n" ]]; then
        TASKS=${i:3}
    elif [[ ${i:0:2} = "-p" ]]; then
        PARTT=${i:3}
    elif [[ ${i:0:2} = "-r" ]]; then
        RNTME=${i:3}
    elif [[ ${i:0:2} = "-e" ]]; then
        EMAIL=$i:3}
    elif [[ ${i:0:2} = "-R" ]]; then
        RMTPT=${i:3}
    fi
done
# Make sure all required args are met
if ([[ -z $JOBNAME ]] || [[ -z $INDIR ]] || [[ -z $NODES ]] || [[ -z $TASKS ]]); then
    echo "Missing required argument but hell if I'm telling you which"
    exit 2
fi 
# Make sure slurm isn't going to bitch at me
if [[ $(echo "$NODES*$NODECORES" | bc) -le $TASKS ]]; then 
    echo "We're gonna need a bigger boat... (request more nodes)"
    exit 3
fi

# Make sure I didn't do an oopsie
if ! [[ -e $INDIR ]]; then 
	echo "No Inputs Directory ";
	exit 2;
elif ! [[ -d $INDIR ]]; then
	echo "Inputs is not a directory!";
	exit 2;
fi

# Set the default partition 
if [[ -z $PARTT ]]; then
    if [[ $NODES -lt 3 ]]; then
        PARTT="small"
    elif [[ $NODES -ge 3 ]]; then
        PARTT="normal"
    fi 
fi

# Do some email stuff 
if [[ -n $EMAIL ]]; then
    SENDMAIL="0"
fi

# Find the RMT executable 
if [[ -z $RMTPT ]]; then 
    RMTPT=$DEFRMTPT
fi

# Jobtime default
if [[ -z $RNTME ]]; then 
    RNTME="01:00:00"
fi

# Prepare Files
TIME=$(date +"%s")
WORKPATH="$WORK/$JOBNAME$TIME"
mkdir $WORKPATH
#cd $INDIR
cp -r $INDIR/. $WORKPATH/

RMTPT=$(realpath $RMTPT)
MVRMT="1"
if [[ ${RMTPT:0:${#HOME}} = $HOME ]]; then
    cp -a $RMTPT $WORKPATH/rmt.x
    RMTPT=$WORKPATH/rmt.x
    MVRMT="0"
fi

# Directory to put all of the outputs to 
WRITEOUT="$PWD/$JOBNAME$TIME.out"

cd $WORKPATH

# This is the job submission script generating code
echo '#!/bin/bash' >> submission
echo "#SBATCH -J $JOBNAME" >> submission
echo "#SBATCH -o $JOBNAME.o%j" >> submission
echo "#SBATCH -e $JOBNAME.e%j" >> submission
echo "#SBATCH -p $PARTT" >> submission
echo "#SBATCH -N $NODES" >> submission
echo "#SBATCH -n $TASKS" >> submission
echo "#SBATCH -t $RNTME" >> submission
if [[ $SENDMAIL -eq 1 ]]; then
    echo "#SBATCH --mail-type=all" >> submission
    echo "#SBATCH --mail-user=$EMAIL" >> submission
fi

echo "cd $WORKPATH" >> submission
echo 'STARTTIME=$(date +"%s")' >> submission 
echo "ibrun $RMTPT >> $JOBNAME.log" >> submission
echo 'TOTALTIME=$(expr $(date +"%s") - $STARTTIME)' >> submission
echo "NEWLINE=$'\n'" >> submission
echo 'echo $"$NEWLINE --------------------"' >> submission
echo "echo \"Run took \$TOTALTIME s\" >> $JOBNAME.out" >> submission
if [[ $MVRMT -eq 0 ]]; then
    echo "rm rmt.x" >> submission
fi 
echo "cp -rf . $WRITEOUT" >> submission
echo "cd .. && rm -rf $WORKPATH" >> submission

# This will queue the job

echo $(sbatch submission)
