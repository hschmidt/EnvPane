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

#import "Error.h"


NSError *LogError( NSError *error )
{
    NSLog( @"Error: %@", error );
    return error;
}

NSError *NewError( NSString *message )
{
    return [NSError errorWithDomain: @"EnvLib"
                               code: 0
                           userInfo: @{ NSLocalizedDescriptionKey: message }];
}

BOOL NO_AssignError( NSError **dst, NSError *src )
{
    if( dst ) *dst = src;
    return NO;
}

BOOL NO_LogError( NSError **error )
{
    if( error ) LogError( *error );
    return NO;
}
