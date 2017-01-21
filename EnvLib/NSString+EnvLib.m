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

#import "NSString+EnvLib.h"


@implementation NSString (EnvLib)

- (NSString *) trim
{
    NSCharacterSet *charset = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [self stringByTrimmingCharactersInSet: charset];
}

- (BOOL) matches: (NSRegularExpression *) re
{
    NSRange r = NSMakeRange( 0, self.length );
    NSTextCheckingResult *m = [re firstMatchInString: self
                                             options: NSMatchingAnchored
                                               range: r];
    return m && NSEqualRanges( m.range, r );
}

- (BOOL) prefixMatches: (NSRegularExpression *) re
{
    NSRange r = NSMakeRange( 0, self.length );
    NSTextCheckingResult *m = [re firstMatchInString: self
                                             options: NSMatchingAnchored
                                               range: r];
    return m && m.range.location == 0;
}

- (NSRegularExpression *) toRegex
{
    return [self toRegexWithOptions: (NSRegularExpressionOptions) 0];
}

- (NSRegularExpression *) toRegexWithOptions: (NSRegularExpressionOptions) options
{
    return [NSRegularExpression regularExpressionWithPattern: self
                                                     options: options
                                                       error: nil];
}



@end
