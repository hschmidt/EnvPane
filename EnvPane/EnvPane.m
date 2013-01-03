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

#import "EnvPane.h"
#import "Constants.h"
#import "AboutSheetController.h"

#import <SecurityFoundation/SFAuthorization.h>
#import <ServiceManagement/ServiceManagement.h>

@implementation EnvPane

- (void) awakeFromNib
{
    self.agentInstalled = NO;
}

- (void) mainViewDidLoad
{
    savedEnvironment = [Environment loadPlist];
    self.editableEnvironment = [savedEnvironment toArrayOfEntries];
    NSError* error = [self installAgent];
    if( error ) [self presentError: error];
}

- (void) didSelect
{
    applyChangesTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0
                                                         target: self
                                                       selector: @selector( timerTarget: )
                                                       userInfo: NULL
                                                        repeats: YES];
}

- (void) didUnselect
{
    [self applyChanges];
    [applyChangesTimer invalidate];
}

- (void) timerTarget: (NSTimer*) timer
{
    [self applyChanges];
}

- (void) applyChanges
{
    Environment* environment = [Environment withArrayOfEntries: self.editableEnvironment];
    if( ![environment isEqualToEnvironment: savedEnvironment] ) {
        [environment savePlist];
        savedEnvironment = environment;
    }
}

- (NSError*) installAgent
{
    NSError* error = nil;
    NSBundle* bundle = self.bundle;
    NSURL* bundleUrl = bundle.bundleURL;
    NSFileManager* fileManager = NSFileManager.defaultManager;
    NSURL* prefPanesUrl = [fileManager URLForDirectory: NSPreferencePanesDirectory
                                              inDomain: NSUserDomainMask
                                     appropriateForURL: nil
                                                create: NO
                                                 error: &error];
    if( !prefPanesUrl ) return error;

    if( ![bundleUrl.absoluteString hasPrefix: prefPanesUrl.absoluteString] ) {
        return MakeError(
            @"This preference pane must be installed for each user individually. "
            "Installation for all users is currently not supported. Remove this preference pane "
            "and then reinstall it, this time for the current user only." );
    }

    /*
     * Prepare hard link outside the bundle pointing to agent inside the bundle.
     * The hardlink will create prevent the agent from becoming inaccessible if
     * the preference pane is deleted, enabling the agent to self-destruct
     * itself in that case.
     */
    NSURL* agentExcutableUrl = [bundle URLForAuxiliaryExecutable: agentExecutableName];
    if( agentExcutableUrl == nil ) return MakeError( @"Can't find agent executable" );

    NSURL* appSupportUrl = [fileManager URLForDirectory: NSApplicationSupportDirectory
                                               inDomain: NSUserDomainMask
                                      appropriateForURL: nil
                                                 create: NO
                                                  error: &error];
    if( !appSupportUrl ) return error;

    NSURL* agentAppSupportUrl = [appSupportUrl URLByAppendingPathComponent: agentLabel
                                                               isDirectory: YES];

    NSURL* agentExecutableLinkUrl = [agentAppSupportUrl URLByAppendingPathComponent: agentExecutableName];

    if( ![fileManager createDirectoryAtURL: agentAppSupportUrl
               withIntermediateDirectories: YES
                                attributes: nil
                                     error: &error] ) return error;

    if( [fileManager fileExistsAtPath: agentExecutableLinkUrl.path] ) {
        if( ![fileManager removeItemAtURL: agentExecutableLinkUrl error: &error] ) return error;
    }

    if( ![fileManager linkItemAtURL: agentExcutableUrl
                              toURL: agentExecutableLinkUrl
                              error: &error] ) return error;

    /*
     * Read current agent configuration, if possible.
     */
    NSURL* libraryUrl = [fileManager URLForDirectory: NSLibraryDirectory
                                            inDomain: NSUserDomainMask
                                   appropriateForURL: nil
                                              create: NO
                                               error: &error];
    if( !libraryUrl ) return error;

    NSURL* agentConfsUrl = [libraryUrl URLByAppendingPathComponent: @"LaunchAgents"
                                                       isDirectory: YES];

    NSString* agentConfName = [agentLabel stringByAppendingString: @".plist"];

    NSURL* agentConfUrl = [agentConfsUrl URLByAppendingPathComponent: agentConfName];

    NSDictionary* curAgentConf = nil;
    if( [fileManager fileExistsAtPath: agentConfUrl.path isDirectory: NO] ) {
        curAgentConf = [NSDictionary dictionaryWithContentsOfURL: agentConfUrl];
    }

    /*
     * Prepare new agent configuration
     */
    NSURL* agentConfTemplateUrl = [bundle.sharedSupportURL URLByAppendingPathComponent: agentConfName];
    NSDictionary* newAgentConf = [NSDictionary dictionaryWithContentsOfURL: agentConfTemplateUrl];
    if( newAgentConf == nil ) return MakeError( @"Can't load job description template" );

    [newAgentConf setValue: @[ agentExecutableLinkUrl.path ]
                    forKey: @"ProgramArguments"];
    [newAgentConf setValue: @[ bundleUrl.path, [Environment savedEnvironmentPath]]
                    forKey: @"WatchPaths"];

    /*
     * If new agent configuration is different to currently installed one, ...
     */
    NSTask* task;
    if( ![newAgentConf isEqualToDictionary: curAgentConf] ) {
        /*
         * ... install and load it into launchd.
         */
        if( curAgentConf ) {
            task = [NSTask launchedTaskWithLaunchPath: launchctlPath
                                            arguments: @[ @"unload", agentConfUrl.path ]];
            [task waitUntilExit];
        }

        if( ![newAgentConf writeToFile: agentConfUrl.path
                            atomically: YES] ) {
            return MakeError( @"Failed to write agent's launchd job description." );
        }
        task = [NSTask launchedTaskWithLaunchPath: launchctlPath
                                        arguments: @[ @"load", agentConfUrl.path ]];
    } else {
        /*
         * ... otherwise start agent.
         */
        task = [NSTask launchedTaskWithLaunchPath: launchctlPath
                                        arguments: @[ @"start", agentLabel ]];
    }
    [task waitUntilExit];
    if( task.terminationStatus != 0 ) return MakeError( @"Failed to load/start agent" );

    self.agentInstalled = YES;
    return nil;
}

- (void) presentError: (NSError*) error
{
    [[NSApplication sharedApplication] presentError: error];
}

NSError* MakeError( NSString* message )
{
    NSLog( @"Preparing error object for '%@'", message );
    return [NSError errorWithDomain: message
                               code: 0
                           userInfo: @{NSLocalizedDescriptionKey : message}];
}

- (IBAction) showReadme: (id) sender
{
    [[AboutSheetController sheetControllerWithBundle: self.bundle] loadView];
}

@end
