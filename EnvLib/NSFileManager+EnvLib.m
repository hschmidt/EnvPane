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

#import "NSFileManager+EnvLib.h"
#import "Error.h"

@implementation NSFileManager (EnvLib)

- (BOOL) ensureParentDirectoryExistsOf: (NSString *) childPath
           withIntermediateDirectories: (BOOL) withIntermediateDirectories
                                 error: (NSError * __autoreleasing *) error
{
    NSString *parentPath = [childPath stringByDeletingLastPathComponent];
    BOOL isDir = NO;
    if( ![self fileExistsAtPath: parentPath isDirectory: &isDir] ) {
        if( ![self createDirectoryAtPath: parentPath
             withIntermediateDirectories: withIntermediateDirectories
                              attributes: nil
                                   error: error] ) {
            return NO;
        }
    } else {
        if( !isDir ) {
            return NO_AssignError( error, NewError( [NSString stringWithFormat: @"Expected directory at '%@'",
                                                                                parentPath] ) );
        }
    }
    return YES;
}

@end
