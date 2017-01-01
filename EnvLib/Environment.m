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

#import "Environment.h"
#import "Error.h"
#import "NSFileManager+EnvLib.h"
#import "NSDictionary+EnvLib.h"

#include "Constants.h"

#include <errno.h>

#include "launch_priv.h"

@implementation Environment

static NSString* savedEnvironmentPath;

+ (void) initialize
{
    savedEnvironmentPath = [@"~/.MacOSX/environment.plist" stringByExpandingTildeInPath];
}

+ (NSString*) savedEnvironmentPath
{
    return savedEnvironmentPath;
}

/**
 * Designated initializer
 */
- initWithDictionary: (NSDictionary*) dict {
    if( self = [super init] ) {
        _dict = dict;
    }
    return self;
}

+ (Environment*) loadPlist
{
    NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile: savedEnvironmentPath];
    Environment* env = [self alloc];
    return [env initWithDictionary: dict == nil ? @{}: dict];
}

- (BOOL) savePlist: (NSError**) error
{
    return [_dict writeToFile: savedEnvironmentPath
                   atomically: YES
                 createParent: YES
              createAncestors: NO
                        error: error];
}

- (NSMutableArray*) toArrayOfEntries
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity: _dict.count];
    [_dict enumerateKeysAndObjectsUsingBlock: ^ ( NSString *key, NSString *value, BOOL *stop ) {
         if( value != nil ) [array addObject: @{ @"name": key, @"value": value }.mutableCopy];
     }];
    return array;
}

+ (Environment*) withArrayOfEntries: (NSArray*) array
{
    NSMutableDictionary *mutDict = [NSMutableDictionary dictionaryWithCapacity: [array count]];
    [array enumerateObjectsUsingBlock: ^ ( NSDictionary *entry, NSUInteger idx, BOOL *stop ) {
         NSString *key = [entry valueForKey: @"name"];
         NSString *value = [entry valueForKey: @"value"];
         if( key != nil && value != nil ) [mutDict setObject: value forKey: key];
     }];
    Environment* env = [self alloc];
    NSDictionary* dict = [NSDictionary dictionaryWithDictionary: mutDict];
    return [env initWithDictionary: dict];
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

    void envlib_setenv( const char *key, const char *value )
    {
        launch_data_t request, entry, valueData, response;

        request = launch_data_alloc( LAUNCH_DATA_DICTIONARY );
        entry = launch_data_alloc( LAUNCH_DATA_DICTIONARY );
        valueData = launch_data_new_string( value );
        launch_data_dict_insert( entry, valueData, key );
        launch_data_dict_insert( request, entry, LAUNCH_KEY_SETUSERENVIRONMENT );

        response = launch_msg( request );
        launch_data_free( request );

        if( response ) {
            launch_data_free( response );
        } else {
            NSLog( @"launch_msg( \"%s\" ): %s", LAUNCH_KEY_SETUSERENVIRONMENT, strerror( errno ) );
        }
    }

    void envlib_unsetenv( const char *key )
    {
        launch_data_t request, keyData, response;

        request = launch_data_alloc( LAUNCH_DATA_DICTIONARY );
        keyData = launch_data_new_string( key );
        launch_data_dict_insert( request, keyData, LAUNCH_KEY_UNSETUSERENVIRONMENT );

        response = launch_msg( request );
        launch_data_free( request );

        if( response ) {
            launch_data_free( response );
        } else {
            NSLog( @"launch_msg( \"%s\" ): %s", LAUNCH_KEY_UNSETUSERENVIRONMENT, strerror( errno ) );
        }
    }

#pragma GCC diagnostic pop

- (void) export
{
    /*
     * Initialize the set of variables to be deleted to the set of current
     * variables.
     */
    NSMutableSet* deletedVariables;
    const char *pcOldVariables = getenv( agentName "_vars" );
    if( pcOldVariables == NULL ) {
        deletedVariables = [NSMutableSet set];
    } else {
        NSString * oldVariables = [NSString stringWithCString: pcOldVariables
                                                     encoding: NSUTF8StringEncoding];
        deletedVariables = [NSMutableSet setWithArray: [oldVariables componentsSeparatedByString: @" "]];
        // in case oldVariables was empty or had multiple consecutive separators:
        [deletedVariables removeObject:@""];
    }
    /*
     * Initialize the set of variables to an empty array. Using an array is ok
     * in this case, as we will be filling it with the keys from the _dict which
     * are guaranteed to be unique.
     */
    NSMutableArray* variables = [NSMutableArray array];
    /*
     * Iterate over each variable in the new environment and ...
     */
    [_dict enumerateKeysAndObjectsUsingBlock: ^ ( NSString *key, NSString *value, BOOL *stop ) {
         if( value != nil ) {
             /*
              * ... export the variable, ...
              */
             NSLog( @"Setting '%@' to '%@'", key, value );
             envlib_setenv( key.UTF8String, value.UTF8String );
             /*
              * ... remove it from the variables to be deleted, ...
              */
             [deletedVariables removeObject: key];
             /*
              * ... and add it to the list of variables for book-keeping.
              */
             [variables addObject: key];
         }
     }];
    /*
     * Delete all variables that were set previously but have been removed.
     */
    [deletedVariables enumerateObjectsUsingBlock: ^ ( NSString* key, BOOL *stop ) {
         NSLog( @"Unsetting '%@'", key );
         envlib_unsetenv( key.UTF8String );
     }];
    /*
     * Export the list of variables such that the next invocation can determine
     * which variables have to be deleted.
     */
    envlib_setenv( agentName "_vars", [variables componentsJoinedByString: @" "].UTF8String );
}

- (BOOL) isEqualToEnvironment: (Environment*) other
{
    return [_dict isEqualToDictionary: other->_dict];
}

@end
