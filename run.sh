basedir=$(dirname $0)
if command -v luajit > /dev/null 2>&1; then
	luajit $basedir/src/init.lua
else
	lua $basedir/src/init.lua
fi

