#include <stdio.h>
#include <stdlib.h>

void print_matrix(int mn, double* A)
{
    for (int i = 0; i < mn * mn; i++) {
        printf("%10.3e ", A[i]);
        if ((i + 1) % mn == 0)
            printf("\n");
    }
    printf("\n");
}

double* get_random_matrix(int mn, int min_max)
{
    double* A = (double*)malloc(mn * mn * sizeof(double));
    for (int i = 0; i < mn * mn; i++)
        A[i] = (double)rand() / RAND_MAX + (rand() % (2 * min_max)) - min_max;
    return A;
}

double multiply_diagonal(double* A, int mn)
{
    double det = 1.0;
    // check if the number is really close to zero
    for (int i = 0; i < mn; i++) {
        if (A[i * mn + i] >= -0.1 && A[i * mn + i] <= 0.1)
            return 0.0;
    }

    return det;
}

double* get_ld_matrix(int mn, int min_max)
{
    double* A = (double*)malloc(mn * mn * sizeof(double));
    double v;

    for (int i = 0; i < mn * mn; i++)
        A[i] = (double)rand() / RAND_MAX + (rand() % (2 * min_max)) - min_max;

    // make first and last rows Linearly dependent
    for (int i = 0, v = 1.0; i < mn; i++, v++)
        A[i * mn] = (double)v;

    for (int i = mn - 1, v = 1.0; i < mn * mn; i += mn, v++)
        A[i] = (double)v * 2.0;

    return A;
}

int main(int argc, const char** argv)
{
    if (argc < 4) {
        printf("Usage: ./%s <rows/cols> <min_max_random> <rand_seed>\n", argv[0]);
        exit(-1);
    }

    int mn = atoi(argv[1]);
    int min_max = atoi(argv[2]);
    int seed = atoi(argv[3]);
    int lda = mn;
    int iterations = 0;
    int* ipiv = (int*)malloc(mn * sizeof(double));
    double* A = (double*)malloc(mn * mn * sizeof(double));
    double det = 0.0;
    srand(seed);

    // while (det == 0.0) {
    A = get_random_matrix(mn, min_max);
    // A = get_ld_matrix(mn, min_max);
    // print_matrix(mn, A);
    // LAPACKE_dgetrf(LAPACK_ROW_MAJOR, mn, mn, A, lda, ipiv);
    // print_matrix(mn, A);
    //   det = multiply_diagonal(A, mn);
    //   printf("det = %.32e iter = %d\n", det, iterations);
    //   iterations++;
    // }

    /* Output the matrix in the matrix market format */
    printf("%%%%MatrixMarket format\n");
    printf("%%Generated with ./matrix_generator %d %d %d on %d iterations\n", mn, min_max, seed, iterations);
    printf("%d %d %d\n", mn, mn, mn * mn);
    for (int i = 0; i < mn; i++) {
        for (int j = 0; j < mn; j++) {
            printf("%d %d %lf\n", i + 1, j + 1, A[i * mn + j]);
        }
    }

    free(ipiv);
    free(A);
    return 0;
}
