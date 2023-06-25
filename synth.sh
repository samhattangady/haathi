# set the paths
library=zig-out/lib/synthelligence.wasm
wasm=web/synthelligence.wasm
# delete the wasm files that already exist. We don't want to accidentally
# run files that exist if the build fails.
if [ -e $library ]
then
    rm $library
fi
if [ -e $wasm ]
then
    rm $wasm
fi

# build the new wasm file
time ./current_zig.sh build -Dsynthelligence=true

# copy the new wasm file to the web directory.
if [ -e $library ]
then
    cp $library $wasm
fi
