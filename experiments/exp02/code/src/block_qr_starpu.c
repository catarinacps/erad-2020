#include "mutils/mutils.h"
#include <lapacke.h>
#include <starpu.h>
#include <time.h>

/* Struct that will hold the input parameters for a block QR operation */
typedef struct
{
    int nb; // Block size
    int ldt; // Reflector leading dimension
    int lda; // Leading dimension of matrix A
    int m, n; // Rows and cols of A
} block_mtx;

block_mtx* block_mtx_new(int nb, int ldt, int lda, int m, int n)
{
    block_mtx* block = (block_mtx*)malloc(sizeof(block_mtx));
    block->nb = nb;
    block->ldt = ldt;
    block->lda = lda;
    block->m = m;
    block->n = n;
}

/* ============= DGEQRT ============= */

void cpu_dgeqrt(void* buffers[], void* cl_arg)
{
    /* Get data handles */
    struct starpu_vector_interface* handle_A = buffers[0];
    struct starpu_vector_interface* handle_A2 = buffers[1];
    struct starpu_vector_interface* handle_T = buffers[2];

    /* Point to handle data */
    double* A = (double*)STARPU_VECTOR_GET_PTR(handle_A);
    double* T = (double*)STARPU_VECTOR_GET_PTR(handle_T);

    /* Unpack cl_args which contains block_mtx */
    starpu_codelet_unpack_args(cl_arg);
    block_mtx* params = cl_arg;

    /* Call Lapack routine */
    LAPACKE_dgeqrt(LAPACK_ROW_MAJOR, params->m, params->n, params->nb,
        A, params->lda, T, params->ldt);
}

/* DGEQRT writes on 2 blocks diagonal A and T */
struct starpu_codelet dgeqrt_cl = {
    .cpu_funcs = { cpu_dgeqrt },
    .cpu_funcs_name = { "cpu_dgeqrt" },
    .name = "lapack_dgeqrt",
    .modes = { STARPU_RW, STARPU_RW, STARPU_W },
    .nbuffers = 3
};

/* ============= DLARFB ============= */

void cpu_dlarfb(void* buffers[], void* cl_arg)
{
    /* Get data handles */
    struct starpu_vector_interface* handle_A = buffers[0];
    struct starpu_vector_interface* handle_T = buffers[1];
    struct starpu_vector_interface* handle_J = buffers[2];

    /* Point to handle data */
    double* A = (double*)STARPU_VECTOR_GET_PTR(handle_A);
    double* T = (double*)STARPU_VECTOR_GET_PTR(handle_T);
    double* JTH = (double*)STARPU_VECTOR_GET_PTR(handle_J);

    /* Unpack cl_args which contains block_mtx */
    starpu_codelet_unpack_args(cl_arg);
    block_mtx* params = cl_arg;

    /* Call Lapack routine */
    LAPACKE_dlarfb(LAPACK_ROW_MAJOR, 'L', 'T', 'F', 'C',
        params->m, params->n, params->nb,
        A, params->lda, T, params->ldt, JTH, params->lda);
}

/* DLARFB writes on 2 blocks diagonal A and T */
struct starpu_codelet dlarfb_cl = {
    .cpu_funcs = { cpu_dlarfb },
    .cpu_funcs_name = { "cpu_dlarfb" },
    .name = "lapack_dlarfb",
    .modes = { STARPU_R, STARPU_R, STARPU_RW },
    .nbuffers = 3,
};

/* ============= DTPQRT ============= */

void cpu_dtpqrt(void* buffers[], void* cl_arg)
{
    /* Get data handles */
    struct starpu_vector_interface* handle_A = buffers[0];
    struct starpu_vector_interface* handle_T = buffers[1];
    struct starpu_vector_interface* handle_I = buffers[2];

    /* Point to handle data */
    double* A = (double*)STARPU_VECTOR_GET_PTR(handle_A);
    double* T2 = (double*)STARPU_VECTOR_GET_PTR(handle_T);
    double* ITH = (double*)STARPU_VECTOR_GET_PTR(handle_I);

    /* Unpack cl_args which contains block_mtx */
    starpu_codelet_unpack_args(cl_arg);
    block_mtx* params = cl_arg;

    /* Call Lapack routine */
    LAPACKE_dtpqrt(LAPACK_ROW_MAJOR, params->nb, params->nb, 0, params->nb,
        A, params->lda, ITH, params->lda, T2, params->ldt);
}

/* DTPQRT writes on 2 blocks diagonal ITH and T */
struct starpu_codelet dtpqrt_cl = {
    .cpu_funcs = { cpu_dtpqrt },
    .cpu_funcs_name = { "cpu_dtpqrt" },
    .name = "lapack_dtpqrt",
    .modes = { STARPU_R, STARPU_W, STARPU_RW },
    .nbuffers = 3,
};

/* ============= DTPMQRT ============= */

void cpu_dtpmqrt(void* buffers[], void* cl_arg)
{
    /* Get data handles */
    struct starpu_vector_interface* handle_A = buffers[0];
    struct starpu_vector_interface* handle_T = buffers[1];
    struct starpu_vector_interface* handle_J = buffers[2];
    struct starpu_vector_interface* handle_I = buffers[3];

    /* Point to handle data */
    double* ITH = (double*)STARPU_VECTOR_GET_PTR(handle_A);
    double* T2 = (double*)STARPU_VECTOR_GET_PTR(handle_T);
    double* ITH2 = (double*)STARPU_VECTOR_GET_PTR(handle_I);
    double* JTH = (double*)STARPU_VECTOR_GET_PTR(handle_J);

    /* Unpack cl_args which contains block_mtx */
    starpu_codelet_unpack_args(cl_arg);
    block_mtx* params = cl_arg;

    /* Call Lapack routine */
    LAPACKE_dtpmqrt(LAPACK_ROW_MAJOR, 'L', 'T',
        params->nb, params->nb, params->nb, 0, params->nb,
        ITH, params->lda,
        T2, params->ldt,
        JTH, params->lda,
        ITH2, params->lda);
}

/* DTPMQRT writes on 2 blocks diagonal ITH and JTH and reads I and T2*/
struct starpu_codelet dtpmqrt_cl = {
    .cpu_funcs = { cpu_dtpmqrt },
    .cpu_funcs_name = { "cpu_dtpmqrt" },
    .name = "lapack_dtpmqrt",
    .modes = { STARPU_R, STARPU_R, STARPU_RW, STARPU_RW },
    .nbuffers = 4,
};

/*
    Given a matrix A that have elements = [0,1,2,3,4,5,6,7, ...]
    have the first two blocks of size 2x2  B1=[0,1,4,5] and B2=[2,3,6,7]
    This routine sets A = [0,1,4,5,2,3,6,7]
    NOT USED, this may be usefull for a better memory access patterm
*/
double* reorder_matrix_by_block_line(double* A, int m, int n, int nb, int b, int mb, int lda)
{
    int k, i, j, ib, jb, p = 0;
    double* newA = (double*)malloc(m * n * sizeof(double));

    for (i = 0; i < mb; i++) { // for each row block
        for (j = 0; j < b; j++) { // for each column block
            k = i * lda * nb + j * nb; // get actual block
            for (ib = 0; ib < nb; ib++) { // for each line of block
                for (jb = 0; jb < nb; jb++) { // copy elements of one line sequentially to newA
                    newA[p] = A[k + ib * lda + jb];
                    p++;
                }
            }
        }
    }
    // Copy newA to A
    memcpy(A, newA, m * n * sizeof(double));
    free(newA);
    return A;
}

/* Register block data into a vector of data_handle */
void create_block_handles(starpu_data_handle_t* blocks, double* A, int m, int n, int nb, int b, int mb, int lda)
{
    unsigned long int k, i, j, block = 0;

    for (i = 0; i < mb; i++) { // for each row block
        for (j = 0; j < b; j++) { // for each column block
            k = i * lda * nb + j * nb; // get actual block
            // LOWER part of A[k] = blockcs[k]
            starpu_vector_data_register(&blocks[block], STARPU_MAIN_RAM, (uintptr_t)&A[k], 1, sizeof(A[0]));
            block++;
            // UPPER part of A[k] = blocks[k+1]
            starpu_vector_data_register(&blocks[block], STARPU_MAIN_RAM, (uintptr_t)&A[k], 1, sizeof(A[0]));
            block++;
        }
    }
}

int main(int argc, char const** argv)
{
    struct timeval start, end, start_compute, end_compute;
    double time, compute_time;
    gettimeofday(&start, NULL);

    check_params(argc, argv);

    unsigned long int m, n; // base dimensions
    int min_max, seed; // parameter for amtrix generation
    int nb = atoi(argv[2]); // block size

    // read or generate the matrix
    double* A;
    if (argc == 3) {
        A = read_mat(argv[1], &m, &n);
    } else {
        m = n = (unsigned long int)atoi(argv[1]);
        seed = atoi(argv[3]);
        min_max = atoi(argv[4]);
        srand(seed);
        A = gen_random_mat(m, min_max);
    }

    int b = ceil(n / nb); // number of col blocks
    int mb = ceil(m / nb); // number of row blocks
    int lb = n - (b - 1) * nb; // size of last block
    int i, j, k, z; // block control parameters
    int ib, ib2, jb, kb, zb, zit; // iterators for loop control
    int info; // error control
    int lda = n; // leading dimension for calculating submatrices

    // size for the T reflector accumulator
    int ldt = nb;
    int tsize = ldt * min(m, n);
    double* T = (double*)calloc(tsize, sizeof(double));
    double* T2 = (double*)calloc(tsize, sizeof(double));

    /* initialize StarPU */
    info = starpu_init(NULL);

    block_mtx* A_blk = block_mtx_new(nb, ldt, lda, nb, nb);

    /* Allocate space for data handles * 2 because each block have two handles (LOWER/UPPER)*/
    unsigned long int handle_n = mb * b * 2;

    starpu_data_handle_t handle_A, handle_T, handle_T2;

    starpu_data_handle_t* blocks = (starpu_data_handle_t*)malloc(handle_n * sizeof(starpu_data_handle_t));

    create_block_handles(blocks, A, m, n, nb, b, mb, lda);

    starpu_vector_data_register(&handle_T, STARPU_MAIN_RAM, (uintptr_t)T, tsize, sizeof(T[0]));
    starpu_vector_data_register(&handle_T2, STARPU_MAIN_RAM, (uintptr_t)T2, tsize, sizeof(T2[0]));

    gettimeofday(&start_compute, NULL);
    // for each diagonal block
    for (k = 0; k < min(mb, b); k++) {
        starpu_iteration_push(k);
        kb = (k * b + k) * 2; // diagonal block

        //lower part of diagonal block blocks[kb]
        //upper part of diagonal block blocks[kb+1]
        starpu_task_insert(&dgeqrt_cl,
            STARPU_RW, blocks[kb],
            STARPU_RW, blocks[kb + 1],
            STARPU_W, handle_T,
            // STARPU_PRIORITY, 4,
            STARPU_VALUE, A_blk, sizeof(block_mtx), 0);

        // update diagonal right blocks
        for (j = 1; j < (b - k); j++) {
            jb = (kb + 2 * j); // block right from diagonal
            starpu_task_insert(&dlarfb_cl,
                STARPU_R, blocks[kb],
                STARPU_R, handle_T,
                STARPU_RW, blocks[jb],
                // STARPU_PRIORITY, 2,
                STARPU_VALUE, A_blk, sizeof(block_mtx), 0);
        }

        // eliminate blocks below the diagonal
        for (i = 1; i < (mb - k); i++) {
            ib = kb + b * 2 * i; // block below diagonal
            starpu_task_insert(&dtpqrt_cl,
                STARPU_RW, blocks[kb + 1],
                STARPU_W, handle_T2,
                STARPU_RW, blocks[ib],
                // STARPU_PRIORITY, 3,
                STARPU_VALUE, A_blk, sizeof(block_mtx), 0);

            // update k-th line with i-th line
            for (z = 1; z < (b - k); z++) {
                ib; // block below diag read only
                jb = kb + (2 * z); // diagonal row
                zb = ib + (2 * z); // ith row below diagonal

                starpu_task_insert(&dtpmqrt_cl,
                    STARPU_R, blocks[ib],
                    STARPU_R, handle_T2,
                    STARPU_RW, blocks[jb],
                    STARPU_RW, blocks[zb],
                    // STARPU_PRIORITY, 1,
                    STARPU_VALUE, A_blk, sizeof(block_mtx), 0);
            }
        }
        starpu_iteration_pop();
    }

    /* Wait untill all tasks are executed */
    starpu_task_wait_for_all();
    gettimeofday(&end_compute, NULL);
    compute_time = (end_compute.tv_sec - start_compute.tv_sec) * 1000000L;
    compute_time += (end_compute.tv_usec - start_compute.tv_usec);

    /* Clean data handles */
    for (i = 0; i < handle_n; i++)
        starpu_data_unregister(blocks[i]);
    starpu_data_unregister(handle_T);
    starpu_data_unregister(handle_T2);

    /* terminate StarPU */
    starpu_shutdown();
    gettimeofday(&end, NULL);
    time = (end.tv_sec - start.tv_sec) * 1000000L;
    time += (end.tv_usec - start.tv_usec);
    printf("total_time %lf\n", time / 1000000L);
    printf("compute_time %lf\n", compute_time / 1000000L);
    //print_r(m, n, A, "");
    return 0;
}
