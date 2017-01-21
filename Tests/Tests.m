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

#import <XCTest/XCTest.h>
#import "Environment.h"
#import "NSString+EnvLib.h"
#import "Interpolator.h"

@interface Tests: XCTestCase

@end


@implementation Tests

- (void) setUp
{
    [super setUp];
}

- (void) tearDown
{
    [super tearDown];
}

- (void) testSimpleInterpolations
{
    NSString *home = [[NSProcessInfo processInfo] environment][ @"HOME" ];
    [self _interpolateDict: @{
                    @"empty": @"",
                    @"space": @" ",
                    @"forty-two": @"$(echo 42)", // command interpolation
                    @"also forty-two": @"${forty-two}", // variable interpolation
                    @"void": @"${does_not_exist}", // non-existent variable yields empty string
                    @"dollar": @"$$", // escaping a dollar sign
                    @"home": @"${HOME}", // interpolate from real environment
                    @"shell home": @"$(echo $$HOME)", // let the shell interpolate variable
                    @"shell void": @"$(echo $$does_not_exist)" // same for non-existent variable
            }
                 andExpect: @{
                         @"empty": @"",
                         @"space": @" ",
                         @"forty-two": @"42",
                         @"also forty-two": @"42",
                         @"void": @"",
                         @"dollar": @"$",
                         @"home": home,
                         @"shell home": home,
                         @"shell void": @""
                 }];
}

- (void) testComplexInterpolations
{
    [self _interpolateDict: @{
                    @"eff": @"f",
                    @"oh": @"o",
                    @"forty-two": @"42",
                    @"forty-two'": @"${${eff}orty-tw${oh}}", // interpolate name of interpolated variable
                    @"duh": @"$(echo '$${forty-two}' is ${f${oh}rty-two'})", // same with command
                    @"$": @"$$",
                    @"$$": @"${$$}${$$}"
            }
                 andExpect: @{
                         @"eff": @"f",
                         @"oh": @"o",
                         @"forty-two": @"42",
                         @"forty-two'": @"42",
                         @"duh": @"${forty-two} is 42",
                         @"$": @"$",
                         @"$$": @"$$"
                 }];
}

- (void) testEscapedDelimiters
{
    [self _interpolateDict: @{
                    @"a": @"()",
                    @"b": @")",
                    @"c": @"(",
                    @"d": @")(",
                    @"e": @"{}",
                    @"f": @"}",
                    @"g": @"{",
                    @"h": @"}{",
                    // normal way to escape ')'
                    @"i": @"$(echo '$()')",
                    // normal way to escape '}'
                    @"}": @"}", @"j": @"${${}}",
                    // roundabout way to escape ')'
                    @")": @")", @"k": @"$(echo '${)}')",
                    // roundabout way to escape '}'
                    @"l": @"${$(echo })}",
            }
                 andExpect: @{

                         @"a": @"()",
                         @"b": @")",
                         @"c": @"(",
                         @"d": @")(",
                         @"e": @"{}",
                         @"f": @"}",
                         @"g": @"{",
                         @"h": @"}{",
                         @")": @")", @"i": @")",
                         @"j": @"}",
                         @"k": @")",
                         @"}": @"}", @"l": @"}",
                 }];
}

- (void) testAbbreviatedVariableInterpolations
{
    [self _interpolateDict: @{
                    @"foo": @"42",
                    @"a": @"$foo",
                    @"b": @"$foo.",
                    @"c": @"$foo ",
                    @"d": @"$foo$a"
            }
                 andExpect: @{
                         @"foo": @"42",
                         @"a": @"42",
                         @"b": @"42.",
                         @"c": @"42 ",
                         @"d": @"4242"
                 }];
}

- (void) testSimpleCycles
{
    [self _interpolateDict: @{
                    @"FOO": @"${FOO}" }
        andExpectException: @"CyclicReference"];

    [self _interpolateDict: @{
                    @"FOO": @"${BAR}",
                    @"BAR": @"${FOO}"
            }
        andExpectException: @"CyclicReference"];

    [self _interpolateDict: @{
                    @"FOO": @"${BAR}",
                    @"BAR": @"${BAZ}",
                    @"BAZ": @"${FOO}"
            }
        andExpectException: @"CyclicReference"];
}

- (void) testComplexCycle
{
    [self _interpolateDict: @{
                    @"F": @"F",
                    @"O": @"O",
                    @"FOO": @"${${F}O${O}}"
            }
        andExpectException: @"CyclicReference"];
}

- (void) testCommandTimeout
{
    [self _interpolateDict: @{ @"FOO": @"$(cat)" }
        andExpectException: @"CommandTimeout"];
}

- (void) testSyntaxErrors
{
    for( NSString *value in @[
            @"$",
            @"$ ",
            @"$ BAR",
            @"$",
            @"$$$",
            @"$(echo 42}",
            @"$(echo 42",
            @"${BAR)",
            @"${BAR",
            @"${BAR",
            @"$(echo 1"
    ] ) {
        [self _interpolateDict: @{ @"FOO": value }
            andExpectException: @"SyntaxError"];
    }
}

- (void) testCommandFailure
{
    [self _interpolateDict: @{ @"FOO": @"$(does-not-exist)" }
        andExpectException: @"CommandFailure"];
    [self _interpolateDict: @{ @"FOO": @"$(false)" }
        andExpectException: @"CommandFailure"];
}


- (void) _interpolateDict: (NSDictionary *) inputDict
                andExpect: (NSDictionary *) expectDict
{
    Environment *input = [Environment withDictionary: inputDict];
    Environment *expect = [Environment withDictionary: expectDict];
    Environment *actual = [Interpolator interpolate: input
                                           strictly: YES];
    XCTAssertEqualObjects( actual, expect );
}

- (void) _interpolateDict: (NSDictionary *) dict
       andExpectException: (NSString *) name
{
    Environment *env = [Environment withDictionary: dict];
    XCTAssertThrowsSpecificNamed( [Interpolator interpolate: env
                                                   strictly: YES],
                                  InterpolationException, name, @"in\n%@", env );
}

- (void) testRegexes
{
    XCTAssert( ![@"X" matches: @"A".toRegex] );
    XCTAssert( ![@"" matches: @"A".toRegex] );
    XCTAssert( ![@"xA" matches: @"A".toRegex] );
    XCTAssert( ![@"Ax" matches: @"A".toRegex] );
    XCTAssert( [@"A" matches: @"A".toRegex] );

    XCTAssert( ![@"X" prefixMatches: @"A".toRegex] );
    XCTAssert( ![@"" prefixMatches: @"A".toRegex] );
    XCTAssert( ![@"xA" prefixMatches: @"A".toRegex] );
    XCTAssert( [@"Ax" prefixMatches: @"A".toRegex] );
    XCTAssert( [@"A" prefixMatches: @"A".toRegex] );

    XCTAssert( [@"" matches: @".*".toRegex] );
    XCTAssert( [@"" prefixMatches: @".*".toRegex] );
}

@end
