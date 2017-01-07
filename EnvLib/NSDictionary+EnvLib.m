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

#import "NSDictionary+EnvLib.h"
#import "NSFileManager+EnvLib.h"
#import "Error.h"

@implementation NSDictionary (EnvLib)

- (BOOL) writeToFile: (NSString *) path
          atomically: (BOOL) atomically
        createParent: (BOOL) createParent
     createAncestors: (BOOL) createAncestors
               error: (NSError **) error
{
    if( createAncestors && !createParent ) {
        @throw [NSException exceptionWithName: @"IllegalArgumentException"
                                       reason: @"createAncestors implies createParent"
                                     userInfo: nil];
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    if( createParent && ![manager ensureParentDirectoryExistsOf: path
                                    withIntermediateDirectories: createAncestors
                                                          error: error] ) {
        return NO;
    }
    if( [self writeToFile: path atomically: atomically] ) return YES;

    return NO_AssignError( error, NewError( [NSString stringWithFormat: @"Can't write to '%@'", path] ) );
}

@end
