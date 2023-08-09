library=zig-out/lib/haathi.wasm
out_folder=holiday
src_folder=web
out_wasm=$out_folder/haathi.wasm
out_html=$out_folder/index.html
out_js=$out_folder/haathi.js
src_html=$src_folder/index.html
src_js=$src_folder/haathi.js

if [ -e $library ] 
then 
    rm $library 
fi
if [ -e $out_wasm ]
then 
    rm $out_wasm 
fi
if [ -e $out_html ] 
then 
    rm $out_html 
fi
if [ -e $out_js ] 
then 
    rm $out_js 
fi
time ./current_zig.sh build -Dholiday=true
if [ -e $library ] 
then 
    cp $library $out_wasm 
fi
cp $src_html $out_html
cp $src_js $out_js
