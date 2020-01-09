#include <assert.h>
#include <execinfo.h>
#include <inttypes.h>
#include <omp.h>
#include <ompt.h>
#include <stdio.h>
#include <sys/resource.h>

static ompt_set_callback_t ompt_set_callback;
static ompt_get_thread_data_t ompt_get_thread_data;
static ompt_get_unique_id_t ompt_get_unique_id;
static ompt_get_task_info_t ompt_get_task_info;
static ompt_get_state_t ompt_get_state;

#define MAX_EVENT 10000000
static char EVENT_BUFF[MAX_EVENT][64];
static char* TASKS[] = { "lapack_dgeqrt", "lapack_dlarfb", "lapack_dtpqrt", "lapack_dtpmqrt" };
int ACTUAL_TASK;
uint64_t ITERATION = 0;
uint64_t EVENT_ID = 0;
static double INIT_TIME;

/* ============ Initialization ============ */

/* Convinient way to call ompt_set_callback with error check */
#define register_callback_t(name, type)                                           \
    do {                                                                          \
        type f_##name = &on_##name;                                               \
        if (ompt_set_callback(name, (ompt_callback_t)f_##name) == ompt_set_never) \
            printf("0: Could not register callback '" #name "'\n");               \
    } while (0)

#define register_callback(name) register_callback_t(name, name##_t)

/* Used register the tool in the OpenMP runtime specifying the callbacks
   with ompt_set_callback() via register_callback() defined above */
int ompt_initialize(ompt_function_lookup_t lookup, ompt_data_t* data);

/* Finalize the tool use of OMPT interface*/
void ompt_finalize(ompt_data_t* data);

/* To initialize the tool along with OpenMP */
ompt_start_tool_result_t* ompt_start_tool(unsigned int omp_version, const char* runtime_version);

/* This will increment TASK_ID for every task created event */
static uint64_t next_task();

/* This will increment EVENT_ID for every event mapped by a callback */
static uint64_t next_event();

void save_file(const char* filename, int nevents);
