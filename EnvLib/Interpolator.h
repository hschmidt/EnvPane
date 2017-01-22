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

@class InterpolationException;

@interface Interpolator: NSObject

/*
 * Interpolate all $FOO $(command) and ${FOO} references in the value of each variable in the given
 * environment and return the resulting new environment with all such interpolations resolved. In
 * strict mode, an exception will be raised for the first interpolation error encountered, syntax
 * or otherwise. In non-strict mode, any offending entry in the input will be missing from the
 * output.
 */
+ (Environment *) interpolate: (Environment *) environment
                     strictly: (BOOL) strict;


/*
 * Interpolate all $FOO $(command) and ${FOO} references in the value of each variable in the given
 * environment and return the resulting new environment with all such interpolations resolved. The
 * given block will be invoked with an exception corresponding to every interpolation problem
 * encountered, syntax or otherwise. The block may throw the given exception, any other exception
 * or return a boolean indicating whether to continue interpolation of other entries.
 */
+ (Environment *) interpolate: (Environment *) environment
                      onError: (BOOL ( ^ )( InterpolationException *error )) onError;
@end

@interface InterpolationException: NSException

- (instancetype) initWithName: (NSString *) name
                       forKey: (NSString *) key
                       reason: (NSString *) reason;

@property( readonly ) NSString *key;
@end
