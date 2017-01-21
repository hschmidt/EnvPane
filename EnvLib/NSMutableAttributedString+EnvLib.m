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

#import "NSMutableAttributedString+EnvLib.h"


@implementation NSMutableAttributedString (EnvLib)

+ (NSMutableAttributedString *) withString: (NSString *) string
                                attributes: (NSDictionary<NSString *, id> *) attributes, ...
NS_REQUIRES_NIL_TERMINATION
{
    va_list args;
    va_start( args, attributes );
    NSMutableAttributedString *result = [[self alloc] init];
    for( ;; ) {
        [result appendAttributedString: [[NSAttributedString alloc] initWithString: string
                                                                        attributes: attributes]];
        string = va_arg( args, NSString* );
        if( string == nil ) break;
        attributes = va_arg( args, NSDictionary * );
    }
    va_end( args );
    return result;
}


@end
