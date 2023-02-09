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

#import "Interpolator.h"
#import "NSString+EnvLib.h"


@implementation Interpolator
{
@private
    // The dictionaries for the still unresolved (in) and already resolved (out) variables
    NSMutableDictionary *_dictIn, *_dictOut;
    // The key of the variable currently being resolved
    NSString *_key;
    // The value of the variable currently being resolved, split into tokens
    NSArray *_tokens;
    // The index of the token currently being parsed
    unsigned int _pos;
}

#define VARIABLE_NAME_RE @"[A-Za-z_][0-9A-Za-z_]*"

NSNull *_null;
NSString *_eof = @"";
NSRegularExpression *_variableNameRegex;


+ (void) initialize
{
    if( self == [Interpolator class] ) {
        _null = [NSNull null];
        _variableNameRegex = [VARIABLE_NAME_RE toRegex];
    }
}

+ (NSArray *) _tokenize: (NSString *) value
{
    NSRegularExpression *re = [VARIABLE_NAME_RE @"|[$(){}]" toRegex];
    NSMutableArray *tokens = [NSMutableArray array];
    __block NSUInteger i = 0, j;
    void (^addGap)(void)=^void {
        if( i < j ) {
            NSString *gap = [value substringWithRange: NSMakeRange( i, j - i )];
            [tokens addObject: gap];
        }
    };
    [re enumerateMatchesInString: value
                         options: (NSMatchingOptions) 0
                           range: NSMakeRange( 0, value.length )
                      usingBlock: ^(
                              NSTextCheckingResult *__nullable match,
                              NSMatchingFlags flags,
                              BOOL *stop ) {
                          j = match.range.location;
                          addGap();
                          [tokens addObject: [value substringWithRange: match.range]];
                          i = j + match.range.length;
                      }];
    j = value.length;
    addGap();
    NSCAssert( ![tokens containsObject: _eof], @"Tokenizer should not produce EOF tokens" );
    [tokens addObject: _eof];
    return [NSArray arrayWithArray: tokens];
}

+ (Environment *) interpolate: (Environment *) environment
                     strictly: (BOOL) strict
{
    return [self interpolate: environment
                     onError: ^BOOL( InterpolationException *e ) {
                         NSLog( @"%@", e );
                         if( strict ) @throw e; else return YES;
                     }];
}


+ (Environment *) interpolate: (Environment *) environment
                      onError: (BOOL ( ^ )( InterpolationException *e )) onError
{
    NSDictionary *dict = environment.dict;
    NSMutableDictionary *dictIn = [NSMutableDictionary dictionaryWithDictionary: dict];
    NSMutableDictionary *dictOut = [NSMutableDictionary dictionary];
    // Resolve each variable, i.e. interpolate all $() and ${} references in its value and move it
    // to the output dictionary. Moving it ensures that we memoize the resolution result,
    // preventing redundant work when a variable is referenced by more than one value.
    for( NSString *key in dict ) {
        if( [dictOut valueForKey: key] == nil ) {
            Interpolator *interpolator = [[self alloc] initWithInput: dictIn
                                                              output: dictOut
                                                                 key: key];
            @try {
                [interpolator _resolve];
            } @catch( InterpolationException *e ) {
                if( onError && !onError( e ) ) break;
            }
        }
    }
    return [Environment withDictionary: dictOut];
}

/*
 * Initialize and instance of this class for the resolution of a particular variable.
 */
- (instancetype) initWithInput: (NSMutableDictionary *) dictIn
                        output: (NSMutableDictionary *) dictOut
                           key: (NSString *) key
{
    self = [super init];
    if( self ) {
        _dictIn = dictIn;
        _dictOut = dictOut;
        _key = key;
        NSString *value = dictIn[ key ];
        _tokens = [[self class] _tokenize: value];
        _pos = 0;
    }
    return self;
}

/*
 * Resolve the interpolations in the current variable's value.
 */
- (NSString *) _resolve
{
    // Remove variable from input
    [_dictIn removeObjectForKey: _key];
    // Mark it as in process in order to detect cyclic references
    _dictOut[ _key ] = [NSNull null];
    @try {
        // Resolve, i.e. parse and interpolate
        NSMutableString *result = [self _parseUntil: _eof];
        // Place resolved value into output
        return _dictOut[ _key ] = [NSString stringWithString: result];
    } @catch( InterpolationException *e ) {
        // On errors, remove marker
        [_dictOut removeObjectForKey: _key];
        @throw;
    }
}

- (NSMutableString *) _parseUntil: (NSString *) follow
{
    NSMutableString *result = [NSMutableString string];
    for( ;; ) {
        id token = _tokens[ _pos ];
        if( [token isEqualTo: follow] ) {
            break;
        } else if( [token isEqualTo: @"$"] ) {
            _pos++;
            [result appendString: [self _parseInterpolation]];
        } else if( [token isEqualTo: _eof] ) {
            @throw [self _exception: @"SyntaxError"
                             format: @"Unexpected end of string"];
        } else {
            _pos++;
            [result appendString: token];
        }
    }
    return result;
}

- (NSString *) _parseInterpolation
{
    NSString *token = _tokens[ _pos++ ];
    if( [token isEqualTo: @"$"] ) {
        return @"$";
    } else if( [token isEqualTo: @"{"] ) {
        return [self _parseVariableInterpolation];
    } else if( [token isEqualTo: @"("] ) {
        return [self _parseProgramOutputInterpolation];
    } else if( [token matches: _variableNameRegex] ) {
        return [self _resolveVariableInterpolation: token];
    }
    @throw [self _exception: @"SyntaxError"
                     format: @"Invalid token '%@'", token];
}

- (InterpolationException *) _exception: (NSString *) name
                                 format: (NSString *) format, ...
{
    va_list args;
    va_start( args, format );
    NSString *reason = [[NSString alloc] initWithFormat: format
                                              arguments: args];
    return [[InterpolationException alloc] initWithName: name
                                                 forKey: _key
                                                 reason: reason];
    va_end( args );
}

- (NSString *) _parseVariableInterpolation
{
    NSString *key = [[self _parseUntil: @"}"] trim];
    id token = _tokens[ _pos++ ];
    if( [token isEqualTo: @"}"] ) {
        if( key.length < 1 ) return @"}"; // ${} becomes }
        return [self _resolveVariableInterpolation: key];
    } else {
        @throw [self _exception: @"SyntaxError"
                         format: @"Expected token '}' but got '%@'", token];
    }
}

- (NSString *) _resolveVariableInterpolation: (NSString *) key
{
    id value = [_dictOut valueForKey: key];
    if( value == nil ) {
        value = [_dictIn valueForKey: key];
        if( value != nil ) {
            // Recursively resolve the referenced variable and memoize the result
            Interpolator *other = [[Interpolator alloc] initWithInput: _dictIn
                                                               output: _dictOut
                                                                  key: key];
            value = [other _resolve];
        } else {
            value = [[[NSProcessInfo processInfo] environment] valueForKey: key];
            if( value == nil ) value = @"";
        }
    } else if( value == _null ) {
        @throw [self _exception: @"CyclicReference"
                         format: @"Detected a circular reference"];
    }
    return value;
}

- (NSString *) _parseProgramOutputInterpolation
{
    NSString *command = [[self _parseUntil: @")"] trim];
    id token = _tokens[ _pos++ ];
    if( [token isEqualTo: @")"] ) {
        if( command.length < 1 ) return @")"; // $() becomes )
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: @"/bin/sh"];
        [task setArguments: @[ @"-c", command ]];
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput: pipe];
        dispatch_semaphore_t sema = dispatch_semaphore_create( 0 );
        __block NSData *data;
        dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
            data = [pipe.fileHandleForReading readDataToEndOfFile];
            dispatch_semaphore_signal( sema );
        } );
        [task launch];
        if( dispatch_semaphore_wait( sema, dispatch_time( DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC ) ) ) {
            @throw [self _exception: @"CommandTimeout"
                             format: @"Running time of command '%@' exceeded 1s", command];
        }
        [task waitUntilExit];
        if( task.terminationStatus == 0 ) {
            return [[[NSString alloc] initWithData: data
                                          encoding: NSUTF8StringEncoding] trim];
        } else {
            @throw [self _exception: @"CommandFailure"
                             format: @"Command '%@' failed with status %i",
                                     command, task.terminationStatus];
        }
    } else {
        @throw [self _exception: @"SyntaxError"
                         format: @"Expected ')' but got '%@'", token];
    }
}

@end

@implementation InterpolationException
{
    NSString *_key;
}
- (instancetype) initWithName: (NSString *) name
                       forKey: (NSString *) key
                       reason: (NSString *) reason
{
    self = [super initWithName: name reason: reason userInfo: nil];
    if( self ) {
        _key = key;
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"%@: %@ in variable '%@'.", self.name, self.reason, self.key];
}


@end
