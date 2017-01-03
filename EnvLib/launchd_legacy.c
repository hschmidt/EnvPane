/*
 * Copyright 2012, 2017 Hannes Schmidt
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

#include "launchd_legacy.h"

#include <errno.h>
#include <stdio.h>

#include "launch_priv.h"
#include "log.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"


void envlib_setenv( const char *key, const char *value )
{
    launch_data_t request, entry, valueData, response;

    request = launch_data_alloc( LAUNCH_DATA_DICTIONARY );
    entry = launch_data_alloc( LAUNCH_DATA_DICTIONARY );
    valueData = launch_data_new_string( value );
    launch_data_dict_insert( entry, valueData, key );
    launch_data_dict_insert( request, entry, LAUNCH_KEY_SETUSERENVIRONMENT );

    response = launch_msg( request );
    launch_data_free( request );

    if( response ) {
        launch_data_free( response );
    } else {
        NSLog( CFSTR( "launch_msg( '%s' ): %s" ), LAUNCH_KEY_SETUSERENVIRONMENT, strerror( errno ) );
    }
}

void envlib_unsetenv( const char *key )
{
    launch_data_t request, keys, keyData, response;

    request = launch_data_alloc( LAUNCH_DATA_DICTIONARY );
    keyData = launch_data_new_string( key );
    keys = launch_data_alloc( LAUNCH_DATA_ARRAY );
    launch_data_array_set_index(keys, keyData, 0);
    launch_data_dict_insert( request, keys, LAUNCH_KEY_UNSETUSERENVIRONMENT );

    response = launch_msg( request );
    launch_data_free( request );
    if( response ) {
        launch_data_free( response );
    } else {
        NSLog( CFSTR( "launch_msg( '%s' ): %s" ), LAUNCH_KEY_UNSETUSERENVIRONMENT, strerror( errno ) );
    }
}

#pragma GCC diagnostic pop
