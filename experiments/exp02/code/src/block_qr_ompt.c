#include "init/initialization.h"
#include "mutils/mutils.h"
#include <lapacke.h>
#include <time.h>

extern int ACTUAL_TASK;
extern uint64_t ITERATION;

int main(int argc, char const* argv[])
{
    struct timeval start, end, start_compute;
    double time, compute_time;
    check_params(argc, argv);
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

    gettimeofday(&start_compute, NULL);
#pragma omp parallel
    {
#pragma omp single
        {
            // for each diagonal block
            for (k = 0; k < min(b, mb); k++) {

                kb = k * nb * n + k * nb;
                ACTUAL_TASK = 0;
                ITERATION = k;
#pragma omp task depend(inout                                      \
                        : A [kb:kb], A [kb + 1:kb + 1]) depend(out \
                                                               : T [0:tsize])
                {
                    //printf("\tLAPACKE_dgeqrt k=%d A[%d] \n", k, k*nb*n + k*nb);
                    info = LAPACKE_dgeqrt(LAPACK_ROW_MAJOR, nb, nb, nb, &A[kb], lda, T, ldt);
                    // check_err(info, "LAPACKE_dgeqrt");
                }

                // update diagonal right blocks
                for (j = k + 1; j < b; j++) {
                    jb = k * nb * n + j * nb;
                    ACTUAL_TASK = 1;
#pragma omp task depend(in                                     \
                        : A [kb:kb], T [0:tsize]) depend(inout \
                                                         : A [jb:jb + nb])
                    {
                        //printf("\tLAPACKE_dlarfb k=%d A[%d: %d] jb=%d\n", k, k*nb*n + k*nb, kb+nb, jb);
                        info = LAPACKE_dlarfb(LAPACK_ROW_MAJOR, 'L', 'T', 'F', 'C', nb, nb, nb, &A[kb], lda, T, ldt, &A[jb], lda);
                        // check_err(info, "LAPACKE_dlarfb");
                    }
                }

                // eliminate blocks below the diagonal
                for (i = k + 1; i < mb; i++) {
                    ib = i * nb * n + k * nb;
                    ACTUAL_TASK = 2;
#pragma omp task depend(inout                                           \
                        : A [kb + 1:kb + 1], A [ib:ib + nb]) depend(out \
                                                                    : T2 [0:tsize])
                    {
                        //printf("\tLAPACKE_dtpqrt k=%d A[%d]\n", k, k*nb*n + k*nb);
                        info = LAPACKE_dtpqrt(LAPACK_ROW_MAJOR, nb, nb, 0, nb, &A[kb], lda, &A[ib], lda, T2, ldt);
                        // check_err(info, "LAPACKE_dtpqrt");
                    }

                    // update k-th line with i-th line
                    for (zit = k + 1, z = 1; zit < b; zit++, z++) {
                        jb = k * nb * n + zit * nb;
                        ib2 = (i * nb * n + k * nb) + z * nb;
                        ACTUAL_TASK = 3;
#pragma omp task depend(inout                                         \
                        : A [jb:jb + nb], A [ib2:ib2 + nb]) depend(in \
                                                                   : A [ib:ib + nb], T2 [0:tsize])
                        {
                            //printf("\tLAPACKE_dtpmqrt k=%d A[%d]\n", k, k*nb*n + k*nb);
                            info = LAPACKE_dtpmqrt(LAPACK_ROW_MAJOR, 'L', 'T', nb, nb, nb, 0, nb, &A[ib], lda, T2, ldt, &A[jb], lda, &A[ib2], lda);
                            // check_err(info, "LAPACKE_dtpmqrt");
                        }
                    }
                }
            }
        }
    }

    gettimeofday(&end, NULL);
    time = (end.tv_sec - start.tv_sec) * 1000000L;
    time += (end.tv_usec - start.tv_usec);
    compute_time = (end.tv_sec - start_compute.tv_sec) * 1000000L;
    compute_time += (end.tv_usec - start_compute.tv_usec);
    printf("total_time %lf\n", time / 1000000L);
    printf("compute_time %lf\n", compute_time / 1000000L);
    // print_r(m, n, A, "");
    return 0;
}
