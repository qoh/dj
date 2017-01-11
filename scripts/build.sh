# Name of the game, used to name the distribution files
export GAME='dj'

# Directory where distribution is written
export BUILD='build'

# Directory where the love2d files are
export LOVE='love'

# cleanup build directory
echo Cleaning up
if [[ -e $BUILD ]]; then
  rm -rf $BUILD
fi
mkdir -p $BUILD

# create love file
echo Creating love file
cd src
zip -r -q ../$BUILD/$GAME.love *
cd ..

# create game executable
echo Building game executable
cat $LOVE/love.exe $BUILD/$GAME.love > $BUILD/$GAME.exe

# create game distribution
echo Building distribution
cd $BUILD
cp ../$LOVE/*.dll .
cp ../$LOVE/license.txt .
cp -r ../songs .
zip -r -q $GAME.zip *
cd ..

echo Done
