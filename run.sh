if command -v luajit > /dev/null 2>&1; then
	luajit src/init.lua
else
	lua src/init.lua
fi

