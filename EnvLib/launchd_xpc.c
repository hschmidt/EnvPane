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

#include "launchd_xpc.h"
#include <xpc/xpc.h>
#include <mach/mach_init.h>
#include "log.h"

// Much of this is taken from http://newosxbook.com/articles/jlaunchctl.html by Jonathan Levin.

struct xpc_global_data {
    uint64_t	a;
    uint64_t	xpc_flags;
    mach_port_t	task_bootstrap_port;
    xpc_object_t	xpc_bootstrap_pipe;
};

struct _os_alloc_once_s {
    long once;
    void *ptr;
};

extern struct _os_alloc_once_s _os_alloc_once_table[];

#define OS_ALLOC_ONCE_KEY_LIBXPC	1 // from libSystem's alloc_once_private.h

extern int xpc_pipe_routine(xpc_object_t *pipe, xpc_object_t *request, xpc_object_t **response);
extern int xpc_dictionary_set_mach_send(xpc_object_t xdict, const char *key, mach_port_t);
extern char *xpc_strerror(int64_t);

bool envlib_setenv_xpc( EnvEntry env[] ) {
    // TODO: We really ought to figure out how to do this os_alloc_once stuff properly.
    // We should be looking at the `flag` member of the struct and do sth if it's not set.
    struct xpc_global_data *xpc_gd = (struct xpc_global_data *) _os_alloc_once_table[OS_ALLOC_ONCE_KEY_LIBXPC].ptr;

    xpc_object_t envvars = xpc_dictionary_create( NULL, NULL, 0 );
    for( EnvEntry* entry = env; entry->name; entry++ ) {
        if( entry->value ) {
            xpc_dictionary_set_string( envvars, entry->name, entry->value);
        } else {
            xpc_dictionary_set_value( envvars, entry->name, xpc_null_create());
        }
    }
    xpc_object_t dict = xpc_dictionary_create( NULL, NULL, 0 );
    xpc_dictionary_set_uint64( dict, "subsystem", 3 );
    xpc_dictionary_set_uint64( dict, "routine", 0x333 );
    xpc_dictionary_set_value( dict, "envvars", envvars );
    xpc_dictionary_set_uint64( dict, "type", 7 );
    xpc_dictionary_set_uint64( dict, "handle", 0 );
    xpc_dictionary_set_bool( dict, "legacy", 1 );
    xpc_dictionary_set_bool( dict, "legacy", 1 );
    xpc_dictionary_set_mach_send( dict, "domain-port", bootstrap_port );

    xpc_object_t *outDict = NULL;

    int rc = xpc_pipe_routine( xpc_gd->xpc_bootstrap_pipe, dict, &outDict );
    if( rc == 0 && outDict ) {
        int64_t err = xpc_dictionary_get_int64( outDict, "error" );
        if( err ) {
            NSLog( CFSTR( "Error:  %lld - %s\n" ), err, xpc_strerror(err) );
        } else {
            return true;
        }
    } else {
        NSLog( CFSTR( "Error: xpc_pipe_routine() failed\n" ) );
    }
    return false;
}
