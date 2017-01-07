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

#import <Foundation/Foundation.h>

@interface Environment: NSObject
{
@private
    NSDictionary *_dict;
}

/**
 * Returns the path of the file that contains the persistent environment.
 */
+ (NSString *) savedEnvironmentPath;

/**
 * Returns environment with the variables from ~/.MacOSX/environment.plist.
 */
+ (Environment *) loadPlist;

/**
 * Initialize an environment with a copy of the given dictionary.
 */
+ (Environment *) withDictionary: (NSDictionary *) dict;

/**
 * Returns an environment with copies of the entries in the given array. Each
 * array item is assumed to be a NSDictionary with entries, one for the name
 * of the environment variable (using the key 'name'), and one for its value
 * (using the key 'value'.
 */
+ (Environment *) withArrayOfEntries: (NSArray *) array;

/**
 * Saves the environment variables to ~/.MacOSX/environment.plist.
 */
- (BOOL) savePlist: (NSError **) error;

/**
 * Returns an array of the form expected by withArrayOfEntries: containing the
 * receivers environment variables.
 */
- (NSMutableArray *) toArrayOfEntries;

/**
 * Exports the receiver's environment variables to the current user session.
 */
- (void) export;

/**
 * Returns YES if the receiver contains the same variables as the argument,
 * checking both the name and the value of each variable. 
 */
- (BOOL) isEqualToEnvironment: (Environment *) other;

@end
