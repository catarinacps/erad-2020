#include "mutils.h"

/* I/O functions */

// print the whole matrix
void print_m(int m, int n, double* A, char* op)
{
    int i, j;
    printf("%s\n", op);
    for (i = 0; i < m; i++) {
        for (j = 0; j < n; j++)
            printf("%12lf", (A[(i * n) + j]));
        printf("\n");
    }
    printf("\n");
}

// print the upper triangular from QR
void print_r(int m, int n, double* A, char* op)
{
    int i, j;
    printf("%s\n", op);
    for (i = 0; i < m; i++) {
        for (j = i; j < n; j++)
            printf("%12lf", fabs(A[(i * n) + j]));
        printf("\n");
    }
    printf("\n");
}

// read matrix from .mtx file
double* read_mat(char const* filename, unsigned long int* m, unsigned long int* n)
{

    // try opening the file
    FILE* f = fopen(filename, "r");
    if (f == NULL) {
        printf("Error opening file %s!\n", filename);
        exit(-1);
    }

    unsigned long i, j, nnz;
    char line[128], *p;
    double val;

    // ignore header
    do {
        fgets(line, sizeof(line), f);
        p = strchr(line, '%');
    } while (p != NULL);

    // dimensions
    sscanf(line, "%ld %ld %ld", m, n, &nnz);
    double* A;
    // * 2 is because of the dge_trans problem
    A = (double*)malloc((*m) * (*n) * sizeof(double) * 2);

    while (fscanf(f, "%ld %ld %lf", &i, &j, &val) != EOF)
        A[(i - 1) * (*n) + (j - 1)] = val;

    fclose(f);
    return A;
}

// generate random matrix
double* gen_random_mat(unsigned long int mn, int min_max)
{
    // * 2 is because of the dge_trans problem
    double* A = (double*)malloc((unsigned long int)mn * mn * sizeof(double) * 2);
    for (int i = 0; i < mn * mn; i++)
        A[i] = (double)rand() / RAND_MAX + (rand() % (2 * min_max)) - min_max;
    return A;
}

/* Parameter checking */
// program args
void check_params(int argc, char const* argv[])
{
    if (argc != 3 && argc != 5) {
        printf("Usage for read matrix: %s <matrix.mtx> <block_size> \n", argv[0]);
        printf("Usage for generate matrix: %s <matrix_size> <block_size> <seed> <min_max>\n", argv[0]);
        exit(-1);
    }
}

// lapack routines info check
void check_err(int info, char* msg)
{
    if (info < 0) {
        printf("ERROR on %s: INFO = %d \n", msg, info);
        exit(-1);
    }
}

void get_optargs(unsigned long int* m, int* nb, int* s, int* min_max, char const** file, int argc, char const* argv[])
{
    char* cvalue = NULL;
    int c;
    *m = 0, *s = -1, *min_max = 0, *nb = 0;

    while ((c = getopt(argc, argv, "fgsmb")) != -1) {
        switch (c) {
        // f specifies that the matrix will be read from a file
        case 'f':
            *file = optarg;
            return;
            break;

        // g is for generating the matrix of size n*n
        case 'g':
            *file = NULL;
            break;

        // s is the seed for generating the matrix
        case 's':
            *s = atoi(optarg);
            break;

        // m is the min and max value for the matrix
        case 'm':
            *min_max = atoi(optarg);
            break;

        // b is the block size
        case 'b':
            //*nb = atoi(optarg);
            printf("%d \n", *nb);
            break;

        // unknown flags
        case '?':
            printf("Unknown option character `\\x%x'.\n", optopt);
            exit(-1);
        }
    }

    // option n was not passed for amtrix generation
    if (*m == 0 && *file == NULL) {
        printf("-n\tMissing matrix size!\n");
        exit(-1);
    } else if (*s < 0) {
        printf("-s\tMissing seed generator or invalid value s < 0!\n");
        exit(-1);
    } else if (*min_max == 0) {
        printf("-m\tMissing min_max random value!\n");
        exit(-1);
    } else if (*nb == 0) {
        printf("-n\tMissing or invalid block size value!\n");
        exit(-1);
    }
}
