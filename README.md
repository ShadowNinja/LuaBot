LuaBot
======

Introduction
------------

LuaBot is a general-purpose IRC bot written in Lua 5.2.


Installation
------------

LuaBot depends on the following Lua modules:

  * LuaSocket
  * Penlight (included in a submodule)
  * LuaIRC (included in a submodule)
  * LuaPosix (optional, used for setting a signal handler)


Usage
-----

The first step after installing LuaBot is configuring your installation.
LuaBot stores it's configuration in `settings.lua` in it's root directory.
This file uses the syntax of a regular Lua file, except that it contains
(or should contain) only a table and no return statement is needed.
An example configuration file, `settings.lua.example`, is provided.

LuaBot must be run with it's root directory as the current working directory.
The shell script `run.sh` is provided to start LuaBot on POSIX operating
systems.

In order to ensure a clean shutdown you should use the `shutdown` command.
However, if you install LuaPosix you will also be able to cleanly shut down
LuaBot with Control + C or SIGINT.

