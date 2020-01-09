#include "initialization.h"

extern int ACTUAL_TASK;
extern uint64_t ITERATION;
extern uint64_t EVENT_ID;

/* This will increment for every event that mapped by any callback */
static uint64_t next_event()
{
    uint64_t ret;
    ret = __sync_fetch_and_add(&EVENT_ID, 1);

    if (ret >= MAX_EVENT) {
        printf("MAX_EVENT reached, writing file in disk.\n");
        ret = 0;
        EVENT_ID = 0;
        save_file("events.out", MAX_EVENT);
    }
    return ret;
}

/* This will map the task  ID, called when a task is created */
static uint64_t next_task()
{
    static uint64_t TASK_ID = 0;
    uint64_t ret = __sync_fetch_and_add(&TASK_ID, 1);
    return ret;
}

void save_file(const char* filename, int nevents)
{
    FILE* f = fopen(filename, "a");
    for (int i = 0; i < nevents; i++)
        fprintf(f, "%s\n", EVENT_BUFF[i]);
    fclose(f);
}

/* ============ Callback definitons ============ */

static void on_ompt_callback_task_create(
    ompt_data_t* parent_task_data, /* id of parent task            */
    const ompt_frame_t* parent_frame, /* frame data for parent task   */
    ompt_data_t* new_task_data, /* id of created task           */
    int flag,
    int has_dependences,
    const void* codeptr_ra) /* pointer to outlined function */
{

    uint64_t eid = next_event();
    new_task_data->value = next_task();

    // If it is not the initial task
    if (flag != ompt_task_initial) {
        sprintf(&EVENT_BUFF[eid][0], "%d %ld task_create %s %lf %ld", omp_get_thread_num(), new_task_data->value, TASKS[ACTUAL_TASK], omp_get_wtime() - INIT_TIME, ITERATION);
    } else {
        sprintf(&EVENT_BUFF[eid][0], "%d %ld task_create NA %lf %ld", omp_get_thread_num(), new_task_data->value, omp_get_wtime() - INIT_TIME, ITERATION);
    }
}

static void on_ompt_callback_task_schedule(
    ompt_data_t* first_task_data,
    ompt_task_status_t prior_task_status,
    ompt_data_t* second_task_data)
{
    int flags, thread_num;
    ompt_data_t *task_data, *parallel_data;
    ompt_frame_t* task_frame;

    /* Get current task data */
    // ompt_get_task_info(0, &flags, &task_data, &task_frame, &parallel_data, &thread_num);
    uint64_t tid = first_task_data->value;
    uint64_t tid2 = second_task_data->value;
    uint64_t eid;

    switch (prior_task_status) {
    case ompt_task_complete:
        eid = next_event();
        sprintf(&EVENT_BUFF[eid][0], "%d %ld task_completed NA %lf NA", omp_get_thread_num(), tid, omp_get_wtime() - INIT_TIME);
        break;

    case ompt_task_yield:
        eid = next_event();
        sprintf(&EVENT_BUFF[eid][0], "%d %ld task_yield %lf NA NA", omp_get_thread_num(), tid, omp_get_wtime() - INIT_TIME);
        break;

    case ompt_task_cancel:
        eid = next_event();
        sprintf(&EVENT_BUFF[eid][0], "%d %ld task_cancel %lf NA", omp_get_thread_num(), tid, omp_get_wtime() - INIT_TIME);
        break;

    case ompt_task_others: // We assumed that this status as being when the task tid2 has started
        eid = next_event();
        sprintf(&EVENT_BUFF[eid][0], "%d %ld task_others NA %lf NA", omp_get_thread_num(), tid2, omp_get_wtime() - INIT_TIME);
        break;

        // case ompt_task_switch: // works only in newer versions of OpenMP
        //   eid = next_event();
        //   sprintf(&EVENT_BUFF[eid][0], "%d %ld  task_switch %lf", omp_get_thread_num(), tid, omp_get_wtime()-INIT_TIME);
        //   break;

        // case ompt_task_early_fulfill: // works only in newer versions of OpenMP
        //   eid = next_event();
        //   sprintf(&EVENT_BUFF[eid][0], "%d %ld  task_early_fulfill %lf", omp_get_thread_num(), tid, omp_get_wtime()-INIT_TIME);
        //   break;

        // case ompt_task_late_fulfill: // works only in newer versions of OpenMP
        //   eid = next_event();
        //   sprintf(&EVENT_BUFF[eid][0], "%d %ld  task_late_fulfill %lf", omp_get_thread_num(), tid, omp_get_wtime()-INIT_TIME);
        //   break;

    default:
        break;
    }
}

// static void
// on_ompt_callback_task_dependence(
//     ompt_data_t *src_task_data,
//     ompt_data_t *sink_task_data)
// {
//   uint64_t tid1 = src_task_data->value;
//   uint64_t tid2 = sink_task_data->value;
//   uint64_t eid = next_event();
//   sprintf(&EVENT_BUFF[eid][0], "%d %ld task_dependence %ld %lf", omp_get_thread_num(), tid2, tid1, omp_get_wtime()-INIT_TIME);
// }

static void on_ompt_callback_thread_begin(
    ompt_thread_type_t thread_type,
    ompt_data_t* thread_data)
{
    uint64_t eid = next_event();
    sprintf(&EVENT_BUFF[eid][0], "%d 0 thread_begin NA %lf NA", omp_get_thread_num(), omp_get_wtime() - INIT_TIME);
}

static void
on_ompt_callback_thread_end(ompt_data_t* thread_data)
{
    uint64_t eid = next_event();
    sprintf(&EVENT_BUFF[eid][0], "%d 0 thread_end NA %lf NA", omp_get_thread_num(), omp_get_wtime() - INIT_TIME);
}

static void
on_ompt_callback_idle(ompt_scope_endpoint_t endpoint)
{
    uint64_t eid = next_event();
    char* endp = ((endpoint == ompt_scope_begin) ? "BEGIN" : "END");
    sprintf(&EVENT_BUFF[eid][0], "%d 0 thread_idle %s %lf NA", omp_get_thread_num(), endp, omp_get_wtime() - INIT_TIME);
}

// static void
// on_ompt_callback_sync_region(
//  ompt_sync_region_kind_t kind,
//  ompt_scope_endpoint_t endpoint,
//  ompt_data_t *parallel_data,
//  ompt_data_t *task_data,
//  const void *codeptr_ra )
// {
//   uint64_t eid = next_event();
//   char* endp = ((endpoint == ompt_scope_begin) ? "BEGIN" : "END");
//   sprintf(&EVENT_BUFF[eid][0], "%d 0 sync_region %s %lf",omp_get_thread_num(), endp, omp_get_wtime()-INIT_TIME);

// kind specifies the kind of synchronization
// switch (kind) {
//   case ompt_sync_region_taskwait:
//   	break;
// 	case ompt_sync_region_barrier:
//   	break;
// }
// }

/* ============ Initialization ============ */

int ompt_initialize(ompt_function_lookup_t lookup, ompt_data_t* data)
{
    /* Register when the tool started */
    INIT_TIME = omp_get_wtime();

    ompt_set_callback = (ompt_set_callback_t)lookup("ompt_set_callback");
    ompt_get_thread_data = (ompt_get_thread_data_t)lookup("ompt_get_thread_data");
    ompt_get_task_info = (ompt_get_task_info_t)lookup("ompt_get_task_info");
    ompt_get_unique_id = (ompt_get_unique_id_t)lookup("ompt_get_unique_id");
    ompt_get_state = (ompt_get_state_t)lookup("ompt_get_state");

    /* Register all the callbacks that you want to watch */
    register_callback(ompt_callback_task_create);
    register_callback(ompt_callback_task_schedule);
    register_callback(ompt_callback_thread_begin);
    register_callback(ompt_callback_thread_end);
    register_callback(ompt_callback_idle);
    // register_callback(ompt_callback_task_dependence);
    // register_callback(ompt_callback_sync_region);

    uint64_t eid = next_event();
    sprintf(&EVENT_BUFF[eid][0], "%d 0 ompt_initialize NA NA NA", omp_get_thread_num(), omp_get_wtime() - INIT_TIME);
    return 1; // success
}

void ompt_finalize(ompt_data_t* data)
{
    uint64_t eid = next_event();
    sprintf(&EVENT_BUFF[eid][0], "%d 0 ompt_finalize NA NA NA", omp_get_thread_num(), omp_get_wtime() - INIT_TIME);
    save_file("events.out", eid + 1);
}

ompt_start_tool_result_t* ompt_start_tool(unsigned int omp_version, const char* runtime_version)
{
    static double time = 0;
    time = omp_get_wtime();
    static ompt_start_tool_result_t ompt_start_tool_result = { &ompt_initialize, &ompt_finalize, { .ptr = &time } };
    return &ompt_start_tool_result;
}
