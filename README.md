# EnvPane - A macOS preference pane for environment variables

<img src="http://diaryproducts.net/files/EnvPane.png" style="float:left"/>

EnvPane is a preference pane for Mac OS X (10.8 or newer) that lets you set
environment variables for all applications, both GUI and terminal. Not only
does it restore support for `~/.MacOSX/environment.plist` (see
[Background](#background)), it also publishes your changes to the environment
immediately, without the need to log out and back in. This works for changes
made by manually editing `~/.MacOSX/environment.plist` as well via the
preference pane UI.

EnvPane was tested on OS X 10.09 "Mavericks", OS X 10.11 "El Capitan" and macOS
Sierra (10.12). It should also work on 10.10 "Yosemite". Apple
[reimplemented][new_launchd] launchd in 10.10 and in the course of doing so
deprecated the APIs used by EnvPane and even [broke][issue_11] some of them.
EnvPane v0.6 adds support for the new but undocumented APIs, addressing the
deprecation and broken APIs.

[new_launchd]: http://newosxbook.com/articles/jlaunchctl.html
[issue_11]: https://github.com/hschmidt/EnvPane/issues/11

EnvPane does *not* work for setting the PATH environment variable. See the [FAQ
on that topic](#why-cant-I-set-path-with-envpane).


## Download

For convenience, the code-signed binary of EnvPane can be
[downloaded][envpane_release] from GitHub. Alternatively you might want to grab
the [source][envpane_repo] and [build it yourself](#building-from-source).

[envpane_release]: https://github.com/hschmidt/EnvPane/releases/tag/releases%2F0.6
[envpane_repo]: https://github.com/hschmidt/EnvPane

<!-- break -->


<a id="background"></a>
## Background

Mac OS X releases prior to Mountain Lion (10.8) included support for
`~/.MacOSX/environment.plist`, a file that contained session-global, per-user
environment variables. Starting with Mountain Lion, support of this
well-documented and popular mechanism was dropped without an official
announcement or explanation by Apple. It may have been in [response]
[flashback] to the Flashback trojan which used that file to inject itself into
every process, but this is a wild guess, especially considering that there is a
relatively easy workaround, as demonstrated by the existence of this very
utility.

EnvPane includes (and automatically installs) a `launchd` agent that runs 1)
early after login and 2) whenever the `~/.MacOSX/environment.plist` changes.
The agent reads `~/.MacOSX/environment.plist` and exports the environment
variables from that file to the current user's `launchd` instance via the same
API that is used by `launchctl setenv` and `launchctl unsetenv`.

TODO: Mention /etc/launchd.conf and ~/.launchd.conf

[flashback]: http://support.apple.com/kb/TS4267?viewlocale=en_US


## Requirements

Mac OS X 10.9 "Mavericks" or higher.


## Installation

1. Download [EnvPane.dmg][envpane_release]
2. Open EnvPane.dmg, a Finder window opens
3. Double-click the `EnvPane.pref-pane` file
4. Choose _Install for this user only_

Do *not* use the _Install for all users_ option. See the
[FAQ](#why-cant-i-install-the-preference-pane-for-all-users).


## Usage

When you open the _Environment Variables_ preference pane, you will see a
simple two-column table that lists the environment variables from your
`~/.MacOSX/environment.plist`. If that file doesn't exist, the table will be
empty but the file will be created as soon as you you add an entry to the
table. To add an environment variable click the `+` button. Specify the name of
the new variable, hit `tab` and specify its value. Hit `enter`. To modify a
variable, click its name or value, make the desired changes and hit `enter`. To
delete an environment variable, click a row in the table and click the `-`
button.

Changes are effective immediately (after a delay of a few seconds) in all
subsequently launched applications. There is no need to reboot or log out.
However, running applications will [not be affected]
(#why-arent-running-applications-affected). You need to quit and relaunch the
application, in order for your changes to take effect.

The `$` character in a value has special meaning. It induces the interpolation
of other environment variables or the output of shell commands. If the `$`
character is followed by the name of another variable, e.g. `$FOO` the value of
that variable will be inserted in place. The referenced variable can be one
explicitly defined in the preference pane or it can be one from the default
environment that launchd sets up. The variable name following `$` must contain
only letters, digits or underscore and may not start with a digit. To
interpolate a variable whose name does not meet those requirements, place the
variable name between curly braces, e.g. `${F-O-O}`. You can also interpolate
the name of an interpolated variable: assuming the variable `EFF` is set to the
value `F`, `${${EFF}OO}` would reference the variabe FOO. Don't worry if this
looks confusing, this is an esoteric feature.

To interpolate the output of a shell command, enclose it in parentheses.
`$(date)`, for example, is replaced with the current date, because that's what
the `date` program prints to standard output. The command is subject to shell
expansion–because it is invoked via `/bin/sh -c`–but also to immediate variable
interpolation by EnvPane as described above. In other words, `$(BAR=bar ; echo
$BAR)` will not evaluate to `bar` because the `$BAR` reference will be
interpolated by EnvPane, at a time when BAR is not yet defined. To prevent
EnvPane from evaluating the reference, you must escape the dollar sign:
`$(BAR=bar; echo $$BAR)`.

Again, whenever you need a literal dollar sign in a variable value, you need do
write two dollar signs: `$$`. If you need a closing parentheses inside a
command interpolation, or a closing curly brace inside a variable
interpolation, you need to write `$()` or `${}` respectively. I now realize
that `$)` and $`}` would have been a better choice but it is what it is.


## Uninstallation

1. Open _System Preferences_ 

2. Right click _Environment Variables_

3. Select _Remove Environment Variables Preference Pane_

The uninstallation should be clean. I went to great lengths in ensuring that
removing the preference pane doesn't leave orphaned files on the system. The
`~/.MacOSX/environment.plist` will not be removed.


## Changelog

### v0.6

* Support for interpolation of other variables and shell command output

* Support for macOS Sierra

* Minor UI changes and a few bug fixes

* Fix: Projects doesn't build with XCode 7 on OS X El Capitan (10.11)

* Fix: envlib_unsetenv() is invoked unnecessarily with empty string if
  environment is empty ([issue #3][issue_3])

### v0.5 and v0.4

Ignore. They are releases made from a fork of this repository, not by the
original author and inauspiciously using the EnvPane name.

### v0.3

Fix: Preference pane fails to load if ~/Library/LaunchAgents is missing 
([issue #2][issue_2])

### v0.2

Fix: Preference pane fails to load if ~/.MacOSX or ~/.MacOSX/environment.plist
are missing ([issue #1][issue_1]).

### v0.1.1

Improved documentation.

### v0.1

Initial release.

[issue_1]: https://github.com/hschmidt/EnvPane/issues/1
[issue_2]: https://github.com/hschmidt/EnvPane/issues/2
[issue_3]: https://github.com/hschmidt/EnvPane/issues/3

<a id="building-from-source"></a>
Building from source 
--------------------


## Build Requirements

* Mac OS X 10.8, Mountain Lion

* Xcode 4.5.x (I use 4.5.2)

* A copy of Apple's `launchd` source tree, available on [Apple Open Source]
  [apple_open_source] under the Apache License 2.0. The current version of
  EnvPane was compiled against [launchd-442.26.2][launchd_source]

* David Parsons' [Discount][discount] C library by for processing John
  Gruber's Markdown. Install the library as described on the project page.
  Using the default installation prefix of `/usr/local` is recommended. The
  current version of EnvPane was statically linked against version 2.2.1 of
  that library. HomeBrew users can use `brew install discount` to install it.

[apple_open_source]: https://opensource.apple.com/
[launchd_source]: https://opensource.apple.com/source/launchd/launchd-442.26.2/
[discount]: http://www.pell.portland.or.us/~orc/Code/discount/


## Building

1. Clone the [EnvPane repository][envpane_repo] on Github

2. Open the Xcode project

3. At the project level, adjust the `launchd_source_dir` custom build setting
   to point to the copy of the launchd source tree

4. Build the project

Linker complaints about libmarkdown. e.g.

```
ld: warning: object file (/usr/local/lib/libmarkdown.a(markdown.o)) was built for newer OSX version (10.11) than being linked (10.9)
```

are to be expected when linking against a HomeBrew-ed installation of that
library on 10.10 or newer.

The `-load_all` linker flag is needed to prevent errors like

```
exception:-[__NSCFDictionary writeToFile:atomically:createParent:createAncestors:error:]: unrecognized selector sent to instance
```


## FAQ

<a id="why-cant-i-install-the-preference-pane-for-all-users"></a>
### Why can't I install the preference pane for all users?

There are two reasons. The first one is a technicality: the environment
variables configured via the preference pane are actually set by a launchd
agent contained in the bundle. The agent uses launchd's `WatchPath` mechanism
in order to be notified when the user's `~/.MacOSX/environment.plist` changes.
Unfortunately, there is no way to specify a `WatchPath` that is relative to the
user's home directory. By installing the EnvPane preference pane for individual
users, each instance can use a separate copy of the agent configuration in
`~/Library/LaunchAgents` as opposed to globally in `/Library/LaunchAgents`. The
second reason is that cleanly uninstalling the agent would be more complex for
a preference pane that was installed globally for all users. Apple is eagerly
deprecating privilege escalation mechanism left and right, leaving the
half-baked `SMJobBless` and the rudimentary `authopen`. I'm not saying it
couldn't be done, I'm just not convinced it'd be worth the effort.

<a id="why-arent-running-applications-affected"></a>
### Why aren't running applications affected?

Say, you have a shell session running in the Terminal application. You might
wonder why changes to the environment made with EnvPane don't show up in the
shell's environment. The answer to this question lies in Unix' process model.
When a process is forked, it inherits a copy of the environment from its parent
process. The copy is independent, so changes in the parent aren't visible in
the child and vice versa. Doing anything else would undoubtedly fling open
Pandora's box of concurrency.

Applications launched via Finder are in fact forked by the per-user instance of
`launchd`, and thus inherit their environment from it. EnvPane uses `launchd`'s
API to modify the environment of the user's `launchd` instance which will then
pass a copy of its modified environment to subsequently launched applications.
The environment of running applications has already been copied and will _not_
be affected.

For applications other than Terminal the only workaround is to restart the
application. In Terminal on OS X 10.09 and older, you can update the shell's
environment by running

	eval `launchctl export`

This will update the shell's environment, not Terminal's. Terminal's
environment is still unchanged and will be passed on to each new shell window
or tab. This means you will have to run the above command in each subsequently
opened Terminal tab or window. Ultimately it might be better to just restart
Terminal. Unfortunately, 10.10 removed the `export` functionality.

<a id="why-cant-I-set-path-with-envpane"></a>
### Why can't I set PATH with EnvPane?

That's because OS X treats PATH differently to other environment variables, I
suspect for security reasons. The special treatment differs from version to
version of OS X but in a nutshell there are two issues: Firstly, launchd will
forcefully set PATH to a fixed value, overriding a value set using the standard
launchd APIs used by EnvPane. Secondly, a login shell launched in Terminal will
mangle the value by placing entries from `/etc/paths` and `/etc/paths.d` at the
beginning of the PATH variable. There are workarounds for both issues but
EnvPane doesn't currently implement those, mainly because they involve root
privileges, something I've shyed away from so far. You will have to perform
them manually. The launchd override for PATH can be configured using `launchctl
config user path` or `launchctl config system path`. See the `man launchctl`
for details. I *think* the `user` form of that command is broken on El Capitan,
so you'll have to resort to `system` there. Amusingly, there is no documented
way revert to the defaults. You'll have to delete
`/private/var/db/com.apple.xpc.launchd/config/system.plist` and/or
`/private/var/db/com.apple.xpc.launchd/config/user.plist` and reboot. The
`/etc/paths` issue can be worked around by duplicating the additional entries
from `launchctl config … path` in `/etc/paths`. See `man path_helper` for
details.

My personal opinion is that the hardcoding of PATH by launchd is misguided.
PATH was meant to be a mere convenience for interactive shell use. If a
security-sensitive system component needs to ensure that a particular binary is
executed, it should specify that binary using an absolute PATH.

Another rant: the fact that `launchtl config user path` has system-wide scope
and therefore needs sudo privileges is also amusing. If it's called "user" then
it should be user-specific, not global.


## License

    Copyright 2012, 2016, 2017 Hannes Schmidt
    
    Licensed under the Apache License, Version 2.0 (the "License"); 
    you may not use this file except in compliance with the License. 
    You may obtain a copy of the License at 
    
    http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software 
    distributed under the License is distributed on an "AS IS" BASIS, 
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  
    See the License for the specific language governing permissions and
    limitations under the License.


## Copyright Notices


### Green Leaf icon by Bruno Maia

    Copyright 2008 IconTexto
    http://www.icontexto.com
    Released under CC License Attribution-Noncommercial 3.0
    http://creativecommons.org/licenses/by-nc/3.0/


### Launchd by Apple Computer, Inc.

    Copyright (c) 2005 Apple Computer, Inc. All rights reserved.


### Discount by David Loren Parsons

    This product includes software developed by
    David Loren Parsons <http://www.pell.portland.or.us/~orc>


## Acknowledgements

Kudos to Jonathan Levin for his [reversing][new_launchd] of the new launchd and
launchctl. I used the trial version of the [Hopper Disassembler/debugger for OS
X][hopper] to figure out the rest.

[hopper]: https://www.hopperapp.com/
