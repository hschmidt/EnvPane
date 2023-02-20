/*
 * Copyright 2012, 2017 Hannes Schmidt
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
#import "Error.h"
#import "NSDictionary+EnvLib.h"
#import "NSMutableAttributedString+EnvLib.h"
#import "Interpolator.h"

@implementation EnvPane
{
@private
    Environment *_savedEnvironment;
    NSTimer *_applyChangesTimer;
}

- (void) awakeFromNib
{
    CGFloat fontSize = [NSFont systemFontSizeForControlSize: NSControlSizeSmall];
    NSFont *font = [NSFont userFixedPitchFontOfSize: fontSize];
    NSDictionary *code = @{
            NSFontAttributeName: font,
    };
    NSDictionary *plain = @{};
    NSAttributedString *text = [NSMutableAttributedString
            withString: @"Use "
            attributes: plain,
                        @"$(command)", code, @" for output of shell command, ", plain,
                        @"${VAR}", code, @" or ", plain, @"$VAR", code,
                        @" for a variable value and ", plain, @"$$", code,
                        @" for dollar sign.", plain, nil];
    [self.helpLabel setAttributedStringValue: text];
    [self.helpLabel setAllowsEditingTextAttributes: NO];
    self.agentInstalled = NO;
}

- (void) mainViewDidLoad
{
    _savedEnvironment = [Environment loadPlist];
    self.editableEnvironment = [_savedEnvironment toArrayOfEntries];
    NSError *error = nil;
    if( ![self installAgent: &error] ) {
        LogError( error );
        [self presentError: error];
    };
}

- (void) didSelect
{
    _applyChangesTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0
                                                          target: self
                                                        selector: @selector( timerTarget: )
                                                        userInfo: NULL
                                                         repeats: YES];
}

- (void) didUnselect
{
    [self applyChanges];
    [_applyChangesTimer invalidate];
}

- (void) timerTarget: (NSTimer *) timer
{
    [self applyChanges];
}

- (void) applyChanges
{
    Environment *environment = [Environment withArrayOfEntries: self.editableEnvironment];
    NSMutableDictionary *errors = [NSMutableDictionary dictionary];
    [Interpolator interpolate: environment
                      onError: ^BOOL( InterpolationException *error ) {
                          errors[ error.key ] = error;
                          return YES;
                      }];
    [self.editableEnvironment enumerateObjectsUsingBlock:
            ^( NSMutableDictionary *entry, NSUInteger idx, BOOL *stop ) {
                if( [@"PATH" isEqualToString: entry[ @"name" ]] ) {
                    entry[ @"error" ] = @"The PATH environment variable is not supported. "
                            "See About EnvPane below for an explanation.";
                } else {
                    InterpolationException *error = [errors valueForKey: entry[ @"name" ]];
                    entry[ @"error" ] = error ? error.reason : nil;
                }
            }];
    if( errors.count == 0 && ![environment isEqualToEnvironment: _savedEnvironment] ) {
        NSError *error = nil;
        if( [environment savePlist: &error] ) {
            _savedEnvironment = environment;
        } else {
            LogError( error );
            // revert
            self.editableEnvironment = [_savedEnvironment toArrayOfEntries];
            [self presentError: error];
        }
    }
}

- (BOOL) installAgent: (NSError *__autoreleasing *) error
{
    NSBundle *bundle = self.bundle;
    NSURL *bundleUrl = bundle.bundleURL;
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *prefPanesUrl = [fileManager URLForDirectory: NSPreferencePanesDirectory
                                              inDomain: NSUserDomainMask
                                     appropriateForURL: nil
                                                create: NO
                                                 error: error];
    if( !prefPanesUrl ) return NO;

    prefPanesUrl = [prefPanesUrl URLByResolvingSymlinksInPath];
    bundleUrl = [bundleUrl URLByResolvingSymlinksInPath];

    if( ![bundleUrl.absoluteString hasPrefix: prefPanesUrl.absoluteString] ) {
        return NO_AssignError( error, NewError(
                @"This preference pane must be installed for each user individually. "
                        "Installation for all users is currently not supported. Remove this preference pane "
                        "and then reinstall it, this time for the current user only." ) );
    }

    /*
     * Prepare hard link outside the bundle pointing to agent inside the bundle.
     * The hardlink will create prevent the agent from becoming inaccessible if
     * the preference pane is deleted, enabling the agent to self-destruct
     * itself in that case.
     */
    NSURL *agentExecutableUrl = [bundle URLForAuxiliaryExecutable: agentExecutableName];
    if( agentExecutableUrl == nil ) {
        return NO_AssignError( error, NewError( @"Can't find agent executable" ) );
    }

    NSURL *appSupportUrl = [fileManager URLForDirectory: NSApplicationSupportDirectory
                                               inDomain: NSUserDomainMask
                                      appropriateForURL: nil
                                                 create: NO
                                                  error: error];
    if( !appSupportUrl ) return NO;

    NSURL *agentAppSupportUrl = [appSupportUrl URLByAppendingPathComponent: agentLabel
                                                               isDirectory: YES];

    NSURL *agentExecutableLinkUrl = [agentAppSupportUrl URLByAppendingPathComponent: agentExecutableName];

    if( ![fileManager createDirectoryAtURL: agentAppSupportUrl
               withIntermediateDirectories: YES
                                attributes: nil
                                     error: error] ) {
        return NO;
    }

    if( [fileManager fileExistsAtPath: agentExecutableLinkUrl.path] ) {
        if( ![fileManager removeItemAtURL: agentExecutableLinkUrl
                                    error: error] ) {
            return NO;
        }
    }

    if( ![fileManager linkItemAtURL: agentExecutableUrl
                              toURL: agentExecutableLinkUrl
                              error: error] ) {
        return NO;
    }

    /*
     * Read current agent configuration, if possible.
     */
    NSURL *libraryUrl = [fileManager URLForDirectory: NSLibraryDirectory
                                            inDomain: NSUserDomainMask
                                   appropriateForURL: nil
                                              create: NO
                                               error: error];
    if( !libraryUrl ) return NO;

    NSURL *agentConfDirUrl = [libraryUrl URLByAppendingPathComponent: @"LaunchAgents"
                                                         isDirectory: YES];

    NSString *agentConfName = [agentLabel stringByAppendingString: @".plist"];

    NSURL *agentConfUrl = [agentConfDirUrl URLByAppendingPathComponent: agentConfName];

    NSDictionary *curAgentConf = nil;
    if( [fileManager fileExistsAtPath: agentConfUrl.path] ) {
        curAgentConf = [NSDictionary dictionaryWithContentsOfURL: agentConfUrl];
    }

    /*
     * Prepare new agent configuration
     */
    NSURL *agentConfTemplateUrl = [bundle.sharedSupportURL URLByAppendingPathComponent: agentConfName];
    NSDictionary *newAgentConf = [NSDictionary dictionaryWithContentsOfURL: agentConfTemplateUrl];
    if( newAgentConf == nil ) {
        return NO_AssignError( error, NewError( @"Can't load job description template" ) );
    }

    [newAgentConf setValue: @[ agentExecutableLinkUrl.path ]
                    forKey: @"ProgramArguments"];
    [newAgentConf setValue: @[ bundleUrl.path, [Environment savedEnvironmentPath] ]
                    forKey: @"WatchPaths"];

    /*
     * If new agent configuration is different to currently installed one, ...
     */
    NSTask *task;
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
                            atomically: YES
                          createParent: YES
                       createAncestors: NO error: error] ) {
            return NO_AssignError( error, NewError( @"Failed to write agent's launchd job description." ) );
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
    if( task.terminationStatus != 0 ) {
        return NO_AssignError( error, NewError( @"Failed to load/start agent" ) );
    }

    self.agentInstalled = YES;
    return YES;
}

- (void) presentError: (NSError *) error
{
    NSApplication *app = [NSApplication sharedApplication];
    [app presentError: error];
}

- (IBAction) showReadme: (id) sender
{
    [[AboutSheetController sheetControllerWithBundle: self.bundle] loadView];
}

@end
