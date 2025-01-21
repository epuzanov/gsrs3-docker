

# This script allows you to build a local binaries file that will be used by
# the frontend, instead of pulling from git and compiling at run or package time.
# It makes sense to use this if you have to restart the frontend often.
# and you're not using angular development mode (e.g. running off port 4200).
# That is a zipped copy of the dist folder compiled by npm. 
# Before starting, make sure the git repo has the desired content/branch


# git clone https://github.com/ncats/GSRSFrontend.git

FRONTEND_DEV_DIR=$(pwd)/GSRSFrontend

# TARGET_DIR should have a subfolder named "archive" 
TARGET_DIR=$(pwd)/local/frontend-bin


mkdir -p $TARGET_DIR/archive/classes

# This is where you could put for example, static/assets/data.config.json 
# Respect the same folder structure as in the angular dist folder
# Must end with a folder named "classes" 
# this is optional and is used at run time! 
CLASSES_DIR=$TARGET_DIR/classes

TARGET_BIN_ZIP_FILE_NAME=development_3.0.zip
TARGET_BIN_ZIP_FILE_NAME_SANS_EXT=$(basename $TARGET_BIN_ZIP_FILE_NAME .zip)

NPM_BUILD_STRING='build:fda:prod'

function after_build_f() {
  npm install webpack
  npm -i --save webpack-sources --legacy-peer-deps
  npm install -f @types/ws@8.5.4
  npm install globby
  npm -i --save globby --legacy-peer-deps
}

function copy_to_target_f() {
  rm -f $TARGET_DIR/archive/$TARGET_BIN_ZIP_FILE_NAME
  zip -r $TARGET_DIR/archive/$TARGET_BIN_ZIP_FILE_NAME dist
}

export HEREDOC=$(cat <<END_HEREDOC
Now you can do this :
./mvn clean -U spring-boot:run \==
-Dspring-boot.run.folders=$CLASSES_DIR \==
-Dfrontend.repo=file://$TARGET_DIR \==
-Dfrontend.tag=$TARGET_BIN_ZIP_FILE_NAME_SANS_EXT \==
-Dnode.disable \==
-Dwithout.visualizer \==
-DskipTests
END_HEREDOC
)

cd $FRONTEND_DEV_DIR
bash build.sh 
# after_build_f
npm run $NPM_BUILD_STRING 
copy_to_target_f
perl -e 'my $text = $ENV{HEREDOC}; $text=~s/==//g; print $text;'
