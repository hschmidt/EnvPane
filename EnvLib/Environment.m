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

#import "Environment.h"
#import "NSDictionary+EnvLib.h"

#include "Constants.h"

#include "launchd_xpc.h"
#include "launchd_legacy.h"

@implementation Environment

static NSString *savedEnvironmentPath;

+ (void) initialize
{
    savedEnvironmentPath = [@"~/.MacOSX/environment.plist" stringByExpandingTildeInPath];
}

+ (NSString *) savedEnvironmentPath
{
    return savedEnvironmentPath;
}

/**
 * Designated initializer
 */
- initWithDictionary: (NSDictionary *) dict
{
    if( self = [super init] ) {
        _dict = dict;
    }
    return self;
}

+ (Environment *) withDictionary: (NSDictionary *) dict
{
    NSDictionary *copy = [NSDictionary dictionaryWithDictionary: dict];
    Environment *env = [self alloc];
    return [env initWithDictionary: copy];
}

+ (Environment *) loadPlist
{
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: savedEnvironmentPath];
    NSMutableDictionary *mutDict = [NSMutableDictionary dictionary];
    if( dict == nil ) {
        NSLog( @"Could not read environment from plist at %@.", savedEnvironmentPath );
    }
    [dict enumerateKeysAndObjectsUsingBlock: ^( id key, id value, BOOL *stop ) {
        if( [key isKindOfClass: [NSString class]] && [value isKindOfClass: [NSString class]] ) {
            mutDict[ key ] = value;
        } else {
            NSLog( @"Ignoring plist entry with non-string key or value in %@.", savedEnvironmentPath );
        }
    }];
    return [self withDictionary: mutDict];
}

- (BOOL) savePlist: (NSError **) error
{
    NSLog( @"Saving environment to %@", savedEnvironmentPath );
    return [_dict writeToFile: savedEnvironmentPath
                   atomically: YES
                 createParent: YES
              createAncestors: NO
                        error: error];
}

- (NSMutableArray *) toArrayOfEntries
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity: _dict.count];
    [_dict enumerateKeysAndObjectsUsingBlock: ^( NSString *key, NSString *value, BOOL *stop ) {
        [array addObject: @{ @"name": key, @"value": value }.mutableCopy];
    }];
    return array;
}

+ (Environment *) withArrayOfEntries: (NSArray *) array
{
    NSMutableDictionary *mutDict = [NSMutableDictionary dictionaryWithCapacity: [array count]];
    [array enumerateObjectsUsingBlock: ^( NSDictionary *entry, NSUInteger idx, BOOL *stop ) {
        NSString *name = [entry valueForKey: @"name"];
        NSString *value = [entry valueForKey: @"value"];
        if( name != nil ) mutDict[ name ] = value == nil ? @"" : value;
    }];
    return [self withDictionary: mutDict];
}


- (void) export
{
    NSMutableSet *oldVariables;
    const char *pcOldVariables = getenv( agentName "_vars" );
    if( pcOldVariables == NULL ) {
        oldVariables = [NSMutableSet set];
    } else {
        NSString *oldVariablesStr = [NSString stringWithCString: pcOldVariables
                                                       encoding: NSUTF8StringEncoding];
        oldVariables = [NSMutableSet setWithArray: [oldVariablesStr componentsSeparatedByString: @" "]];
        // in case oldVariables was empty or had multiple consecutive separators:
        [oldVariables removeObject: @""];
    }
    if( kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber10_10 ) {
        NSSet *newVariables = [NSMutableSet set];
        [_dict enumerateKeysAndObjectsUsingBlock:
                ^( NSString *key, NSString *value, BOOL *stop ) {
                    if( value != nil ) {
                        NSLog( @"Setting '%@' to '%@' using legacy launchd API.", key, value );
                        envlib_setenv( key.UTF8String, value.UTF8String );
                        [oldVariables removeObject: key];
                        [(NSMutableSet *) newVariables addObject: key];
                    }
                }];
        [oldVariables enumerateObjectsUsingBlock: ^( NSString *key, BOOL *stop ) {
            NSLog( @"Unsetting '%@' using legacy launchd API.", key );
            envlib_unsetenv( key.UTF8String );
        }];
        if( newVariables.count ) {
            NSString *newVariablesStr = [[newVariables allObjects] componentsJoinedByString: @" "];
            envlib_setenv( agentName "_vars", newVariablesStr.UTF8String );
        } else {
            envlib_unsetenv( agentName "_vars" );
        }
    } else {
        NSSet *newVariables = [_dict keysOfEntriesPassingTest:
                ^BOOL( NSString *key, NSString *value, BOOL *stop ) {
                    return value != nil;
                }];
        [oldVariables minusSet: newVariables];
        EnvEntry env[[newVariables count] + [oldVariables count] + 2];
        EnvEntry *entry = env;
        for( NSString *name in newVariables ) {
            NSString *value = _dict[ name ];
            NSLog( @"Setting '%@' to '%@' using XPC launchd API.", name, value );
            entry->name = name.UTF8String;
            entry->value = value.UTF8String;
            entry++;
        }
        for( NSString *name in oldVariables ) {
            NSLog( @"Unsetting '%@' using XPC launchd API.", name );
            entry->name = name.UTF8String;
            entry->value = NULL;
            entry++;
        }
        // Add tracking variable
        entry->name = agentName "_vars";
        if( newVariables.count ) {
            NSString *newVariablesStr = [[newVariables allObjects] componentsJoinedByString: @" "];
            entry->value = newVariablesStr.UTF8String;
        } else {
            entry->value = NULL;
        }
        entry++;
        // Add sentinel
        entry->name = NULL;
        entry->value = NULL;
        envlib_setenv_xpc( env );
    }
}

- (BOOL) isEqualToEnvironment: (Environment *) other
{
    return [_dict isEqualToDictionary: other->_dict];
}

@end
