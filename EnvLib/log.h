/*
 * Copyright 2012, 2016 Hannes Schmidt
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

#ifndef log_h
#define log_h

// http://stackoverflow.com/questions/3060121/core-foundation-equivalent-for-nslog

#include <CoreFoundation/CFString.h>

void NSLog(CFStringRef format, ...);

#endif /* log_h */
