OBJ_DIR := bin
OUT_DIR := build
SRC_DIR := src
LIB_DIR := lib
INC_DIR := include

DEBUG :=

#	- Compilation flags:
#	Compiler and language version
CC := gcc
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
	$(shell pkg-config lapack lapacke blas starpu-1.3 fxt poti hwloc --libs)\
	-lm
INC := -I$(INC_DIR) -I$(SRC_DIR) \
	$(shell pkg-config lapack lapacke blas starpu-1.3 --cflags)

# LIBOMP := -L$(LIBOMP_LIB) -Wl,--rpath,$(LIBOMP_LIB) -I$(LIBOMP_INC)

#	Should be defined in the command line
LIBOMP_LIB :=
LIBOMP_INC :=
LIBOMP := -L$(LIBOMP_LIB) -Wl,--rpath,$(LIBOMP_LIB) -I$(LIBOMP_INC)

################################################################################
#	Files:

# 	- List of targets
TARGET_EXE := $(OUT_DIR)/block_qr_scorep $(OUT_DIR)/block_qr_starpu $(OUT_DIR)/block_qr_ompt $(OUT_DIR)/matrix_generator $(OUT_DIR)/block_qr_kstar_starpu

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

#
# SCOREP - OPENMP task based parallel blocked QR factorization
#
$(OUT_DIR)/block_qr_scorep: $(SRC_DIR)/block_qr_openmp.c $(OBJ_DIR)/mutils.o
	$(PRELINK) $(CC) -o $@ $^ $(INC) $(OMP) $(LIB) $(CFLAGS)

#
# STARPU task based parallel blocked QR factorization
#
$(OUT_DIR)/block_qr_starpu: $(SRC_DIR)/block_qr_starpu.c $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(INC) $(LIB) $(CFLAGS)

#
# Lib for getting OMPT traces
#
$(LIB_DIR)/libinit.so: $(LIB_DIR)/init/initialization.c $(LIB_DIR)/init/initialization.h
	$(CC) $^ -o $@ -shared -fPIC $(CFLAGS) $(LIBOMP) $(OMP)

$(OUT_DIR)/block_qr_ompt: $(SRC_DIR)/block_qr_ompt.c $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(INC) $(LIB) $(CFLAGS) $(OMP) $(LIBOMP) -DDYN_TOOL -linit

#
# Kstar with starpu runtime
#
$(OBJ_DIR)/block_qr_kstar_starpu.o: $(SRC_DIR)/block_qr_openmp.c
	$(KSTAR) -c -o $@ $^ $(INC) $(OMP) $(LIBOMP) $(CFLAGS)

$(OUT_DIR)/block_qr_kstar_starpu: $(OBJ_DIR)/block_qr_kstar_starpu.o $(OBJ_DIR)/mutils_kstar.o
	$(KSTAR) -o $@ $^ $(LIB) $(OMP) $(LIBOMP)

#
# Matrix Generator
#
$(OUT_DIR)/matrix_generator: $(SRC_DIR)/matrix_generator.c
	$(CC) -o $@ $^ $(CFLAGS)

print-%:
	@echo "$* == $($*)"

clean:
	rm -f $(OBJ_DIR)/*.o $(INC_DIR)/*~ $(OUT_DIR)/* $(TARGET_EXE) $(LIB_DIR)/*.so *~ *.o