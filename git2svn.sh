#!/bin/bash
BASE_DIR=`pwd`
#GIT_DIR="/Users/gc/Temp/git_repo"
GIT_DIR=$1
#SVN_DIR="/Users/gc/Temp/svn_repo"
SVN_DIR=$2

# The SVN_AUTH variable can be used in case you need credentials to commit
#SVN_AUTH="--username guilherme.chapiewski@gmail.com --password XPTO"
SVN_AUTH=""

GIT_COMMIT_HASH='GitCommitHash:'
GIT_BRANCH_NAME='master'

function svn_checkin {
	echo '... adding files'
	for file in `svn st ${SVN_DIR} | awk -F" " '{print $1 "|" $2}'`; do
		fstatus=`echo $file | cut -d"|" -f1`
		fname=`echo $file | cut -d"|" -f2`

		if [ "$fstatus" == "?" ]; then
			if [[ "$fname" == *@* ]]; then
				svn add $fname@;
			else
				svn add $fname;
			fi
		fi
		if [ "$fstatus" == "!" ]; then
			if [[ "$fname" == *@* ]]; then
				svn rm $fname@;
			else
				svn rm $fname;
			fi
		fi
		if [ "$fstatus" == "~" ]; then
			rm -rf $fname;
			svn up $fname;
		fi
	done
	echo '... finished adding files'
}

function clean_up {
	echo "... clean_up";
	cd $SVN_DIR && svn $SVN_AUTH revert . -R && svn $SVN_AUTH cleanup . --remove-unversioned && cd $BASE_DIR;
	cd $GIT_DIR && git checkout $GIT_BRANCH_NAME && cd $BASE_DIR;
	echo "... clean_up finished!";
}

function svn_last_git_commit_hash {
	echo "... check last git commit hash";
	cd $SVN_DIR && svn $SVN_AUTH update && cd $BASE_DIR;
	lastGitCommitHash=`cd ${SVN_DIR} && svn ${SVN_AUTH} log --xml -l 1 | grep ${GIT_COMMIT_HASH} | sed s/${GIT_COMMIT_HASH}//g | sed s/\<[/?]msg\>//g && cd ${BASE_DIR}`;
	hasgLength=${#lastGitCommitHash};
	if [[ "$hasgLength" != '40' ]]; then
		lastGitCommitHash='';
	fi
	echo "... check last git commit hash : [$lastGitCommitHash]";
}

function svn_commit {
	echo "... committing -> [$author]: $msg";
	cd $SVN_DIR && svn $SVN_AUTH commit -m "[$author]: $msg" && cd $BASE_DIR;
	echo '... committed!'
}

# STEP 1. clean
clean_up;

# STEP 2. check last gitCommitHash on svn
svn_last_git_commit_hash;
if [[ "$lastGitCommitHash" != '' ]]; then
	revListQuery="${lastGitCommitHash}..HEAD";
else
	revListQuery="--all";
fi

# STEP 3. commit in looping
for commit in `cd $GIT_DIR && git rev-list $GIT_BRANCH_NAME $revListQuery --reverse && cd $BASE_DIR`; do 
	echo "Committing $commit...";
	author=`cd ${GIT_DIR} && git log -n 1 --pretty=format:%an ${commit} && cd ${BASE_DIR}`;
	msg=`cd ${GIT_DIR} && git log -n 1 --pretty=format:%s ${commit} && cd ${BASE_DIR}`;
	# add msg (GitCommitHash:{commit})
	msg="${msg}"$'\n'$'\n'"${GIT_COMMIT_HASH}${commit}";
	
	# Checkout the current commit on git
	echo '... checking out commit on Git'
	cd $GIT_DIR && git checkout $commit && cd $BASE_DIR;
	
	# Delete everything from SVN and copy new files from Git
	echo '... copying files'
	rm -rf $SVN_DIR/*;
	cp -prf $GIT_DIR/* $SVN_DIR/;
	
	# Remove Git specific files from SVN
	for ignorefile in `find ${SVN_DIR} | grep .git | grep .gitignore`;
	do
		rm -rf $ignorefile;
	done
	
	# Add new files to SVN and commit
	svn_checkin && svn_commit;
done

