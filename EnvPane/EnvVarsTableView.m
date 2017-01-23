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

#import "EnvVarsTableView.h"


@implementation EnvVarsTableView
{

}

// We want editing to start on the first click

- (void) awakeFromNib
{
    [super awakeFromNib];
    [self setAction: @selector( singleClickEdit: )];
}

- (void) singleClickEdit: (id) sender
{
    [self editColumn: self.clickedColumn
                 row: self.clickedRow
           withEvent: nil
              select: YES];
}

// By default the Esc key triggers auto-completion. We want it to end editing instead, discarding
// any changes. I think that's how spreadsheets typically handle this.

- (void) cancelOperation: (id) sender
{
    NSInteger columnIndex = self.editedColumn, rowIndex = self.editedRow;
    if( columnIndex >= 0 && rowIndex >= 0 ) {
        NSTableColumn *column = self.tableColumns[ (NSUInteger) columnIndex ];
        NSCell *cell = [column dataCellForRow: rowIndex];
        [self.currentEditor setString: cell.stringValue];
        [[self window] makeFirstResponder: self];
    }
}

@end
