/* 
 * Copyright 2012 Hannes Schmidt
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stddef.h>
#include <stdlib.h>

#import <Foundation/Foundation.h>

#import "Environment.h"
#import "Constants.h"
#import "Interpolator.h"

static int _try_main( int argc, const char **argv )
{
    NSLog( @"Started agent %s (%u)", argv[ 0 ], getpid() );
    /*
     * Work around weird issue with launchd starting the agent a second time if it finishes within
     * 10 seconds, the default ThrottleInterval. We reduce the ThrottleInterval to 1s in the plist
     * and wait a little longer here to avoid hitting that condition. We wait first, before doing
     * any real work in order to consolidate potential bursts of changes to the environment plist.
     *
     * But let's not kid ourselves, this is still racy (a flaw inherent to launchd's WatchPaths
     * mechanism) and we could miss updates if they happen after the plist is read and before
     * launchd recognizes the agent's termination.
     */
    [NSThread sleepForTimeInterval: 1.1];

    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    /*
     * Read current agent configuration.
     */
    NSURL *libraryUrl = [fileManager URLForDirectory: NSLibraryDirectory
                                            inDomain: NSUserDomainMask
                                   appropriateForURL: nil
                                              create: NO
                                               error: &error];
    if( !libraryUrl ) {
        NSLog( @"Can't find current user's library directory: %@", error );
        return 1;
    };
    NSURL *agentConfsUrl = [libraryUrl URLByAppendingPathComponent: @"LaunchAgents"
                                                       isDirectory: YES];
    NSString *agentConfName = [agentLabel stringByAppendingString: @".plist"];
    NSURL *agentConfUrl = [agentConfsUrl URLByAppendingPathComponent: agentConfName];
    NSDictionary *curAgentConf = [NSDictionary dictionaryWithContentsOfURL: agentConfUrl];
    /*
     * As per convention, the path to the preference pane is the first entry in WatchPaths.
     * Normally, the preference pane bundle still exists and we simply export the environment.
     * Otherwise, we uninstall the agent by removing the files created outside the bundle during
     * installation.
     */
    NSString *envPanePath = curAgentConf[ @"WatchPaths" ][ 0 ];
    BOOL isDir;
    if( [fileManager fileExistsAtPath: envPanePath
                          isDirectory: &isDir] && isDir ) {
        NSLog( @"Setting environment" );
        Environment *environment = [Environment loadPlist];
        environment = [Interpolator interpolate: environment
                                       strictly: YES];
        [environment export];
    } else {
        NSLog( @"Uninstalling agent" );
        /*
         * Remove agent binary
         */
        NSString *agentExecutablePath = curAgentConf[ @"ProgramArguments" ][ 0 ];
        if( ![fileManager removeItemAtPath: agentExecutablePath error: &error] ) {
            NSLog( @"Failed to remove agent executable (%@): %@", agentExecutablePath, error );
        }
        /*
         * Remove agent plist ...
         */
        if( ![fileManager removeItemAtURL: agentConfUrl error: &error] ) {
            NSLog( @"Failed to remove agent configuration (%@): %@", agentConfUrl, error );
        }
        /*
         * ... and its parent directory.
         */
        NSString *envAgentAppSupport = [agentExecutablePath stringByDeletingLastPathComponent];
        if( ![fileManager removeItemAtPath: envAgentAppSupport
                                     error: &error] ) {
            NSLog( @"Failed to remove agent configuration (%@): %@", agentConfUrl, error );
        }
        /*
         * Remove the job from launchd. This seems to have the same effect as 'unload' except it
         * doesn't cause the running instance of the agent to be terminated and it works without
         * the presence of agent executable or plist.
         */
        NSTask *task = [NSTask launchedTaskWithLaunchPath: launchctlPath
                                                arguments: @[ @"remove", agentLabel ]];
        [task waitUntilExit];
        if( [task terminationStatus] != 0 ) {
            NSLog( @"Failed to unload agent (%@)", agentLabel );
        }
    }
    NSLog( @"Exiting agent %s (PID %u)", argv[ 0 ], getpid() );
    return 0;
}

int main( int argc, const char **argv )
{
    @try {
        return _try_main( argc, argv );
    } @catch( NSException *e ) {
        NSLog( @"Terminating agent due to exception: %@", e );
        return 2;
    }
}
