LuaBot Plugin API
=================

This document assumes that you are familiar with Lua 5 and
the IRC protocol (RFC 1495 and IRCv3).



Introduction
------------

Plugins consist of a directory, named by the plugin name, containing an
`init.lua` and (optionally) other files.  `init.lua` is passed it's plugin
path (and configuration) when it is called, which is usefull for loading
other files.

`init.lua` should return a table.  This table will be available as
`bot.plugins[commandName]` and can contain anything.
However, the following fields are interpreted specialy:

  * `commands` - This must be a table containing command definitions for the
	commands that the plugin adds, indexed by the commamd name.
	See [Commands](#commands).
  * `hooks` - This must be a table containing the hooks that this plugin
	adds, indexed by the hook name with the handler as it's value.
	See the [LuaIRC documentation](irc/doc/irc.luadoc) for more
	information about hooks.  The difference is that all hooks are passed
	the connection that they were called on as their first argument.
  * `on` - This must be a table containing functions to be called on events.
	Events currently sent by the core: `step(stepTime, stepTimeNoSleep)`,
	`shutdown()`, and `flush(final)`.



Variables
---------

Most of LuaBot's variables are conained in the `bot` table.  Some of these
variables are:

  * `conns`   - The active connections that the bot has, indexed by their
	network names.
  * `config`  - The configuration of the bot.
  * `plugins` - This contains the return values from all loaded plugins,
	indexed by their plugin names.
  * `kill`    - A boolean indicating whether the bot should shut down when it
	finishes it's step.



API Functions
-------------

The `bot` table contains the following API functions, which all use member
function notation (`bot:funcName()`):

  * `log(level, message)` - Logs a message.  Valid levels are `error`,
	`warning`, `action` (user-triggered actions), `info`, `debug`, and
	`important` (always logged regardless of settings).
  * `loadConfig()` - (Re)loads the bot's configuration.  This is automatically
	called on startup.
  * `saveConfig()` - Saves the bot's configuration.
  * `getCommand(name)` - Returns the command definition for the command
	specified by `name`.
  * `humanArgs(argDef)` - Returns a human-readable string describing the
	[Argument Definition](#argument-definitions) passed.
  * `replyTo(conn, msg)` - Returns the nick/channel that you should send to in
	order to reply to `msg`.
  * `getMore(name)` - Returns the next "more" line, identified by `name`, to
	be sent, and removes it from the list.
  * `call(name, ...)` - Calls all functions registered for the event `name`.
	`...` contains the arguments to pass to the functions.
  * `checkCommand(conn, msg)` - Checks if the message contains a command, and
	runs it if it does.
  * `stripCommand(line)` - Removes command characters such as prefixes from
	the line and returns the command, ready for processing.  Returns nil
	if there are no command characters.
  * `handleCommand(line, opts)` - Parses the command in `line` and runs it.
	`opts` is a table containing options for the command, it may contain
	the fields `conn`, `msg`, and `privs`.
  * `schedule(after, repeats, func, ...)` - Schedules a function `func` to be
	called after `after` seconds have passed, and every `after` seconds if
	`repeats` is true.  `...` contains arguments to be passed to the
	function when it is called.
  * `shutdown()` - Initiates an immediate clean shutdown.  Set `kill` to true
	if you can wait for the current step to finish.
  * `getPrivs(user)` - Returns a [Privilege Definition](#privilege-definitions)
	for the IRC user.
  * `checkPrivs(needs, has, ignoreOwner)` - Checks if `has` contains all of
	the privileges needed from `needs`.  If ignoreOwner is true having the
	`owner` privilege will not cause this to automatically return true.



Commands
--------

### Command Definitions

Command definitions are tables containing the following fields, all but `action`
are optional:

  * `description` - A description of what the command does.
  * `args`        - See [Argument Definitions](#argument-definitions).
  * `privs`       - See [Privilege Definitions](#privilege-definitions).
  * `IRCOnly`     - A boolean indicating whether this command can only be
	called from IRC, as opposed to being called from a terminal on the
	local machine, for example.
  * `action`      - The function that is called when the command is triggered.
	This function is passed, in order: the connection than the command was
	called from, the message that triggered the command (in the form of a
	Message object, see the LuaIRC documentation), the command's arguments
	(See [Argument Table](#argument-table)).  It must return a boolean
	indicating success, and may return some response text.


Here is an example of a command definition for a simple command that converts
it's argument to lowercase:
```Lua
{
	description = "Returns the string converted to lowercase",
	args = {{"str", "String", "text"}},
	privs = {},  -- Optional
	IRCOnly = false,  -- Optional
	action = function(conn, msg, args)
		return true, args.str:lower()
	end,
}
```

### Command Arguments

There are two parts to command arguments: the argument definition, and the
processed argument table.

#### Argument Definitions

Argument definitions consist of a list of tables, each conatining the following
fields:

  * `id` (or `1`)   - The identifier for the argument used in the
	[Argument Table](#argument-table).
  * `name` (or `2`) - A human-readable short description of the argument.
  * `type` (or `3`) - The type of the argument.
	See [Argument Types](#argument-types).

Here's an example argument definition:
```Lua
{{"x", "The X coordinate", "number"},
 {"y", "The Y coordinate", "number", default=0},
 {id="z", name="The Z coordinate", type="number", optional=true}
```

##### Argument Types

  * `boolean` - A boolean true/false value.  This supports all strings that
	[toboolean](#toboolean) supports.  All other values are invalid.
  * `number`  - A number.  This supports floating-point numbers.
  * `string`  - A string that may contain any character.
  * `text`    - This eats up all of the remaining arguments, seperated by
	spaces, and returns them as a string.  Usefull when you need a string
	value that will usually have spaces and it's the last argument, since
	quotes aren't necessary.
  * `word`    - A single word.  Like `string` but may not contain spaces.


#### Argument Table

The argument table is what is passed to command actions.  It is created based
on that command's argument definition.  For example, given the above
definition, when the command is passed the arguments `1 2 3` a table like the
following will be passed:
```Lua
{x=1, y=2, z=3}
```

And if only `1` was passed as arguments you would get the following table:
```Lua
{x=1, y=0}
```

Invalid usage, such as passing no numbers or a value that is not a number, will
be denied.

### Privilege Definitions

Privilege descriptions consist of a list of privilege names.  Either/or options
are indicated by a subtable.  For example:
```Lua
{{"admin", "manager"}, "math"}
```
The `owner` privilege is special in that having it automatically gives you all
privileges.



Utility Functions
-----------------

In adition to the API functions, LuaBot adds some general-purpose utility
functions:

  * `dump(value, indent="\t")` - Returns `value` as a string using Lua syntax.
	`indent` is the string used to indent lines.  Passing the empty string
	will cause all output to be on one line.
  * `string:isNickChar()` - Checks if the string contains a single valid IRC
	nickname character.
  * `string:isValidNick()` - Checks if the string contains a valid IRC nickname.
  * `string:max(maxLen)` - Ensures that the string is no longer than `maxLen`.
	Adds `...` to the end of the string if it had to be shortened.
	`maxLen` must be at least 3.
  * `toboolean(arg)` <a name="toboolean" /> - Converts a value to a boolean.
	When used on strings this will return nil if the string does not
	contain a boolean value.  Possible string values: true/false, yes/no,
	on/off, enable/disable, and enabled/disabled.
  * `table:maxn()` - Same as `table.maxn` in Lua 5.1.  Finds the largest
	numeric key in the table and returns it.
  * `unescape(str)` - Interprets standard escapes in the string `str`.
	Returns the unescaped string, or `nil` if the unescaping failed.

