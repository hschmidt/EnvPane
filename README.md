EnvPane - An OS X preference pane for environment variables
===========================================================

EnvPane is a preference pane for Mac OS X 10.8 (Mountain Lion) that lets you set environment variables for all programs in both graphical and terminal sessions.  Not only does it restore support for `~/.MacOSX/environment.plist` in Mountain Lion, it also publishes your changes to the environment immediately, without the need to log out and back in.  This works even for changes made by manually editing `~/.MacOSX/environment.plist`, not just changes made via the preference pane.

Download
--------

[Download the signed binary from Diary Products] [8].

[8]: http://diaryproducts.net/files/EnvPane.dmg

Motivation
----------

Mac OS X releases prior to Mountain Lion (10.8) included support for `~/.MacOSX/environment.plist`, a file that contained session-global, per-user environment variables. Starting with Mountain Lion, support of this [well] [2] [documented] [1] and [popular] [3] mechanism was dropped without an official announcement or explanation by Apple. It may have been in [response] [4] to the Flashback trojan which used that file to inject itself into every process, but this is a wild guess, especially considering that there is a relatively easy workaround, as demonstrated by the existence of this utility.

[1]: http://developer.apple.com/library/mac/#/legacy/mac/library/qa/qa1067/_index.html
[2]: https://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPRuntimeConfig/Articles/EnvironmentVars.html
[3]: https://www.google.com/search?q="environment.plist"
[4]: http://support.apple.com/kb/TS4267?viewlocale=en_US

Requirements
------------

Mac OS X 10.8, Mountain Lion or higher.

Installation
------------

1. Download the binary package
2. Double-click `EnvPane.pref-pane` file
3. Choose _Install for this user only_

Do not use the _Install for all users_ option. See the [FAQ](#install_for_all_users).

Usage
-----

When you open the _Environment Variables_ preference pane, you will see a simple two-column table that lists the environment variables in your `~/.MacOSX/environment.plist`. If the file doesn't exist, the table will be empty. Add an environment variable by clicking the `+` button. Specifying the name the new variable, hit `TAB`  and specify the value. Hit Enter. To modify a variable, double-click its name or value. Make the desired changes and hit `Enter`. To delete an environment variable, 

Changes are effective immediately in all subsequently launched applications. There is no need to reboot or log out and back in. Running applications will not be affected. You need to quit and relaunch the application, in order for your changes to take effect.


Uninstallation
--------------

1. Open _System Preferences_ 
2. Right click _Environment Variables_
3. Select _Remove Environment Variables Preference Pane_

The uninstallation should be clean. I went to great lengths in ensuring that removing the preference pane doesn't leave orphaned files on the system.

Changelog
---------

### v0.1

Initial release.


Building from source
--------------------

### Build Requirements ###

* Mac OS X 10.8, Mountain Lion
* Xcode 4.5.x (I use 4.5.2)
* A copy of Apple's `launchd` source tree, available on [Apple Open Source] [1] under the Apache License 2.0. The current version of EnvPane was compiled against [launchd-442.26.2] [2]
* David Parsons' [Discount] [3] C library by for processing John Gruber's Markdown. Install the library as described on the project page. Using the default installation prefix of `/usr/local` is recommended. The current version of EnvPane was compiled against version 2.1.5a of the library.

[5]: http://www.opensource.apple.com/source/launchd/
[6]: http://www.opensource.apple.com/source/launchd/launchd-442.26.2/
[7]: http://www.pell.portland.or.us/~orc/Code/discount/

1. Open the Xcode project
2. At the project level, adjust the `launchd_source_dir` custom build setting to point to the copy of the launchd source tree.
3. Build the project

FAQ
---
<a id="install_for_all_users"></a>
### Why can't I install the preference pane for all users?
There are two reasons. The first one is a technicality: the environment variables configured via the preference pane are actually set by a launchd agent contained in the bundle. The agent uses launchd's `WatchPath` mechanism in order to be notified when the user's `~/.MacOSX/environment.plist` changes. Unfortunately, there is no way to specify a `WatchPath` that is relative to the user's home directory. By installing the EnvPane preference pane for individual users, each instance can use a separate copy of the agent configuration in `~/Library/LaunchAgents` as opposed to globally in `/Library/LaunchAgents`.
The second reason is that cleanly uninstalling the agent would be more complex for a preference pane that was installed globally for all users. Apple is eagerly deprecating privilege escalation mechanism left and right, leaving the half-baked `SMJobBless` and the rudimentary `authopen`. I'm not saying it couldn't be done, I'm just not convinced it'd be worth the effort.


License
-------

Copyright 2012 Hannes Schmidt

Licensed under the Apache License, Version 2.0 (the "License"); 
you may not use this file except in compliance with the License. 
You may obtain a copy of the License at 

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software 
distributed under the License is distributed on an "AS IS" BASIS, 
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  
See the License for the specific language governing permissions and
limitations under the License.