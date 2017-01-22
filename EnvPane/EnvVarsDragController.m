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

#import "EnvVarsDragController.h"

@implementation EnvVarsDragController

NSString *EnvVarsNodeType = @"EnvVarsNodeType";

- (void) awakeFromNib
{
    [super awakeFromNib];
    [_view registerForDraggedTypes: @[ EnvVarsNodeType ]];
}

- (BOOL)
           tableView: (NSTableView *) tableView
writeRowsWithIndexes: (NSIndexSet *) rowIndexes
        toPasteboard: (NSPasteboard *) pasteboard
{
    [pasteboard declareTypes: @[ EnvVarsNodeType ] owner: self];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject: rowIndexes];
    [pasteboard setData: data forType: EnvVarsNodeType];
    return YES;
}

- (NSDragOperation)
            tableView: (NSTableView *) tableView
         validateDrop: (id <NSDraggingInfo>) info
          proposedRow: (NSInteger) row
proposedDropOperation: (NSTableViewDropOperation) operation
{
    return operation == NSTableViewDropAbove ? NSDragOperationMove : NSDragOperationNone;
}

- (BOOL)
    tableView: (NSTableView *) tableView
   acceptDrop: (id <NSDraggingInfo>) info
          row: (NSInteger) _row
dropOperation: (NSTableViewDropOperation) dropOperation
{
    // Signature is messed up, work around it.
    NSAssert( _row >= 0, @"Negative row index: %li", _row );
    NSUInteger row = (NSUInteger) _row;

    NSData *data = [[info draggingPasteboard] dataForType: EnvVarsNodeType];
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData: data];
    NSArray *rows = [[_controller arrangedObjects] objectsAtIndexes: rowIndexes];
    __block NSUInteger offset = 0;
    [rowIndexes enumerateIndexesUsingBlock: ^( NSUInteger rowIndex, BOOL *stop ) {
        if( rowIndex < row ) offset++;
    }];
    [_controller removeObjectsAtArrangedObjectIndexes: rowIndexes];
    [_controller insertObjects: rows atArrangedObjectIndexes: [NSIndexSet indexSetWithIndex: row - offset]];
    return YES;
}


- (NSString *) tableView: (NSTableView *) tableView
          toolTipForCell: (NSCell *) cell
                    rect: (NSRectPointer) rect
             tableColumn: (NSTableColumn *) tableColumn
                     row: (NSInteger) row
           mouseLocation: (NSPoint) mouseLocation
{
    return _controller.arrangedObjects[ (NSUInteger) row ][@"error"];
}

@end
