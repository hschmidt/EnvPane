/*
 * Copyright 2017 Hannes Schmidt
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
#import "Environment.h"

@interface Interpolator: NSObject

/*
 * Interpolate all $FOO $(command) and ${FOO} references in the value of each variable in the given
 * environment and return the resulting new environment with all such interpolations resolved.
 */
+ (Environment *) interpolate: (Environment *) environment
                     strictly: (BOOL) strict;
@end

@interface InterpolationException: NSException

- (instancetype) initWithName: (NSString *) name
                       forKey: (NSString *) key
                       reason: (NSString *) reason;

@property( readonly ) NSString *key;
@end
