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

#import "AboutSheetController.h"

#include "mkdio.h"

@implementation AboutSheetController


+ (AboutSheetController*) sheetControllerWithBundle: (NSBundle *) bundle
{
    /*
     * We cache the controller instance to prevent it from being released
     * too early. If we don't, the dismissReadme action will likely go
     * into a dangling reference.
     */
    static AboutSheetController* instance = nil;
    if( !instance ) {
        instance = [[self alloc] initWithNibName: @"AboutSheet"
                                          bundle: bundle];
    }
    return instance;
}


- (void) loadView
{
    [super loadView];
    NSError* error;
    NSURL* readmeUrl = [self.nibBundle URLForResource: @"README" withExtension: @"md"];
    NSString* readme = [NSString stringWithContentsOfURL: readmeUrl
                                                encoding: NSUTF8StringEncoding
                                                   error: &error];
    const char *markup = [readme cStringUsingEncoding: NSUTF8StringEncoding];
    MMIOT *markdown = mkd_string( markup, (int) strlen( markup ), 0 );
    mkd_compile( markdown, 0 );
    char *html = NULL;
    mkd_document( markdown, &html );
    NSString* nsHtml = [NSString stringWithCString: html
                                          encoding: NSUTF8StringEncoding];
    WebView *view = (WebView *) self.view;
    [view.mainFrame loadHTMLString: nsHtml
                           baseURL: readmeUrl];
    mkd_cleanup( markdown );

    [NSRunLoop.currentRunLoop
     performSelector: @selector( beginSheet )
              target: self
            argument: nil
               order: 0
               modes: @[NSDefaultRunLoopMode]];
}


- (void) beginSheet
{
    [NSApp beginSheet: self.sheet
       modalForWindow: [NSApp mainWindow]
        modalDelegate: self
       didEndSelector: @selector( didEndSheet:returnCode:contextInfo: )
          contextInfo: NULL];
}


- (IBAction) dismissReadme: (id) sender
{
    [NSApp endSheet: self.sheet];
}


- (void) didEndSheet: (NSWindow *) theSheet
          returnCode: (NSInteger) returnCode
         contextInfo: (void *) contextInfo
{
    [theSheet orderOut: self];
}


- (void)                    webView: (WebView *) webView
    decidePolicyForNavigationAction: (NSDictionary *) actionInformation
                            request: (NSURLRequest *) request frame: (WebFrame *) frame
                   decisionListener: (id < WebPolicyDecisionListener >) listener
{
    NSURL *url = request.URL;
    NSString *host = url.host;
    if( host ) {
        NSLog( @"External link: %@", url );
        [[NSWorkspace sharedWorkspace] openURL: [request URL]];
    } else {
        NSLog( @"Internal link: %@", url );
        [listener use];
    }
}

@end
