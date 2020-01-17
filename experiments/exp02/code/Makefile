OBJ_DIR := bin
OUT_DIR := build
SRC_DIR := src
LIB_DIR := lib
INC_DIR := include

DEBUG :=

#	- Compilation flags:
#	Compiler and language version
CC := gcc
KSTAR := kstar --runtime starpu
PRELINK := scorep
DEBUGF := $(if $(DEBUG),-g -fsanitize=address)
CFLAGS :=\
	-Wall \
	-Wextra \
	-Wpedantic \
	-Wshadow \
	-Wunreachable-code
OMP := -fopenmp
OPT := $(if $(DEBUG),-O0,-O2 -march=native)
LIB := -L$(LIB_DIR) \
	$(shell pkg-config lapack lapacke blas --libs)\
	-lm
INC := -I$(INC_DIR) -I$(SRC_DIR) \
	$(shell pkg-config lapack lapacke blas --cflags)

# LIBOMP := -L$(LIBOMP_LIB) -Wl,--rpath,$(LIBOMP_LIB) -I$(LIBOMP_INC)

#	Should be defined in the command line
LIBOMP_PATH :=
LIBOMP := -L$(LIBOMP_PATH)/lib -Wl,--rpath,$(LIBOMP_PATH)/lib -I$(LIBOMP_PATH)/include
LIBOMP_OMPT_PATH :=
LIBOMP_OMPT := -L$(LIBOMP_OMPT_PATH)/lib -Wl,--rpath,$(LIBOMP_OMPT_PATH)/lib -I$(LIBOMP_OMPT_PATH)/include

################################################################################
#	Files:

#	- List of targets
TARGET_EXE := $(OUT_DIR)/block_qr_scorep $(OUT_DIR)/block_qr_starpu $(OUT_DIR)/block_qr_ompt $(OUT_DIR)/matrix_generator $(OUT_DIR)/block_qr_kstar_starpu $(OUT_DIR)/block_qr_libkomp_clang $(OUT_DIR)/block_qr_libkomp_gcc

#	- Path to all final libraries:
TARGET_LIB := $(patsubst %, $(LIB_DIR)/lib%.so, $(shell basename $(shell find $(LIB_DIR)/* -maxdepth 0 -type d)))

################################################################################
#	Targets:

.DEFAULT_GOAL = all

all: $(TARGET_LIB) $(TARGET_EXE)

#
# mutils
#
$(OBJ_DIR)/mutils.o: $(SRC_DIR)/mutils/mutils.c
	$(CC) -c -o $@ $^ $(INC) $(CFLAGS)

$(OBJ_DIR)/mutils_kstar.o: $(SRC_DIR)/mutils/mutils.c
	$(KSTAR) -c -o $@ $^ $(INC) $(CFLAGS)

#
# SCOREP - OPENMP task based parallel blocked QR factorization
#
$(OUT_DIR)/block_qr_scorep: $(SRC_DIR)/block_qr_openmp.c $(OBJ_DIR)/mutils.o
	$(PRELINK) $(CC) -o $@ $^ $(INC) $(OMP) $(LIB) $(CFLAGS)

#
# STARPU task based parallel blocked QR factorization
#
$(OUT_DIR)/block_qr_starpu: $(SRC_DIR)/block_qr_starpu.c $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(INC) $(shell pkg-config starpu-1.3 hwloc fxt poti --libs --cflags) $(LIB) $(CFLAGS)

#
# Lib for getting OMPT traces
#
$(LIB_DIR)/libinit.so: $(LIB_DIR)/init/initialization.c $(LIB_DIR)/init/initialization.h
	$(CC) $^ -o $@ -shared -fPIC $(CFLAGS) $(LIBOMP_OMPT) $(OMP)

$(OUT_DIR)/block_qr_ompt: $(SRC_DIR)/block_qr_ompt.c $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(INC) $(LIB) $(CFLAGS) $(OMP) $(LIBOMP_OMPT) -DDYN_TOOL -linit

#
# Kstar with starpu runtime
#
$(OBJ_DIR)/block_qr_kstar_starpu.o: $(SRC_DIR)/block_qr_openmp.c
	$(KSTAR) -c -o $@ $^ $(INC) $(OMP) $(LIBOMP) $(CFLAGS)

$(OUT_DIR)/block_qr_kstar_starpu: $(OBJ_DIR)/block_qr_kstar_starpu.o $(OBJ_DIR)/mutils_kstar.o
	$(KSTAR) -o $@ $^ $(shell pkg-config starpu-1.3 hwloc fxt poti --libs) $(LIB) $(OMP) $(LIBOMP)

#
# Libkomp
#
$(OUT_DIR)/block_qr_libkomp_clang: $(SRC_DIR)/block_qr_openmp.c $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(INC) $(LIB) $(CFLAGS) $(OMP) $(LIBOMP)

$(OUT_DIR)/block_qr_libkomp_gcc: $(SRC_DIR)/block_qr_openmp.c $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(INC) $(OMP) $(CFLAGS) $(LIB)

#
# Matrix Generator
#
$(OUT_DIR)/matrix_generator: $(SRC_DIR)/matrix_generator.c
	$(CC) -o $@ $^ $(CFLAGS)

print-%:
	@echo "$* == $($*)"

clean:
	rm -f $(OBJ_DIR)/*.o $(INC_DIR)/*~ $(OUT_DIR)/* $(TARGET_EXE) $(LIB_DIR)/*.so *~ *.o
