#include <getopt.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define max(a, b) \
    ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })

#define min(a, b) \
    ({ __typeof__ (a) _a = (a); \
   __typeof__ (b) _b = (b); \
 _a < _b ? _a : _b; })

void print_m(int m, int n, double* A, char* op);

void print_r(int m, int n, double* A, char* op);

void check_err(int info, char* msg);

double* read_mat(const char* filename, unsigned long int* m, unsigned long int* n);

double* gen_random_mat(unsigned long int mn, int min_max);

void check_params(int argc, char const* argv[]);

void get_optargs(unsigned long int* m, int* nb, int* s, int* min_max, char const** file, int argc, char const* argv[]);
