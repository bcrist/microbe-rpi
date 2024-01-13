pushd %~dp0src\rp2040\
regz device.svd -j -o device.json
"../../../microbe-regz/zig-out/bin/microbe-regz.exe"
popd
