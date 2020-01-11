OBJ_DIR := bin
OUT_DIR := build
SRC_DIR := src
LIB_DIR := lib
INC_DIR := include

DEBUG :=

LIB_EXTRA :=
INC_EXTRA :=

#	- Compilation flags:
#	Compiler and language version
CC := gcc
KSTAR := kstar --runtime starpu
DEBUGF := $(if $(DEBUG),-g -fsanitize=address)
CFLAGS :=\
	-Wall \
	-Wextra \
	-Wpedantic \
	-Wshadow \
	-Wunreachable-code
OMP := -fopenmp
OPT := $(if $(DEBUG),-O0,-O2 -march=native)
LIB := -L$(LIB_DIR) $(LIB_EXTRA)\
	$(shell pkg-config lapack lapacke blas --libs)\
	-lm
INC := -I$(INC_DIR) -I$(SRC_DIR) $(INC_EXTRA)\
	$(shell pkg-config lapack lapacke blas --cflags)

#	Should be defined in the command line
LIBOMP_LIB :=
LIBOMP_INC :=
LIBOMP := -L$(LIBOMP_LIB) -Wl,--rpath,$(LIBOMP_LIB) -I$(LIBOMP_INC)

################################################################################
#	Files:

#	- Path to all final binaries:
TARGET := $(OUT_DIR)/block_qr_libgomp $(OUT_DIR)/block_qr_starpu $(OUT_DIR)/block_qr_libomp $(OUT_DIR)/matrix_generator $(OUT_DIR)/block_qr_kstar_starpu

################################################################################
#	Targets:

.DEFAULT_GOAL = all

all: $(TARGET)

#
# mutils
#
$(OBJ_DIR)/mutils.o: $(SRC_DIR)/mutils/mutils.c
	$(CC) -c -o $@ $^ $(INC) $(CFLAGS)

$(OBJ_DIR)/mutils_kstar.o: $(SRC_DIR)/mutils/mutils.c
	$(KSTAR) -c -o $@ $^ $(INC) $(CFLAGS)

#
# OPENMP task based parallel blocked QR factorization
#
$(OBJ_DIR)/block_qr_libgomp.o: $(SRC_DIR)/block_qr_openmp.c
	$(CC) -c -o $@ $^ $(INC) $(OMP) $(CFLAGS)

$(OUT_DIR)/block_qr_libgomp: $(OBJ_DIR)/block_qr_libgomp.o $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(OMP) $(LIB)

#
# STARPU task based parallel blocked QR factorization
#
$(OBJ_DIR)/block_qr_starpu.o: $(SRC_DIR)/block_qr_starpu.c
	$(CC) -c -o $@ $^ $(INC) $(shell pkg-config starpu-1.3 --cflags) $(CFLAGS)

$(OUT_DIR)/block_qr_starpu: $(OBJ_DIR)/block_qr_starpu.o $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(INC) $(shell pkg-config starpu-1.3 hwloc --libs --cflags) $(LIB)


#
# OpenMP with llvm runtime (libomp)
#
$(OBJ_DIR)/block_qr_libomp.o: $(SRC_DIR)/block_qr_openmp.c
	$(CC) -c -o $@ $^ $(INC) $(OMP) $(LIBOMP) $(CFLAGS)

$(OUT_DIR)/block_qr_libomp: $(OBJ_DIR)/block_qr_libomp.o $(OBJ_DIR)/mutils.o
	$(CC) -o $@ $^ $(LIB) $(OMP) $(LIBOMP)

#
# Kstar with starpu runtime
#
$(OBJ_DIR)/block_qr_kstar_starpu.o: $(SRC_DIR)/block_qr_openmp.c
	$(KSTAR) -c -o $@ $^ $(INC) $(shell pkg-config starpu-1.3 --cflags) $(OMP) $(LIBOMP) $(CFLAGS)

$(OUT_DIR)/block_qr_kstar_starpu: $(OBJ_DIR)/block_qr_kstar_starpu.o $(OBJ_DIR)/mutils_kstar.o
	$(KSTAR) -o $@ $^ $(shell pkg-config starpu-1.3 hwloc --libs) $(LIB) $(OMP) $(LIBOMP)

#
# Matrix Generator
#
$(OUT_DIR)/matrix_generator: $(SRC_DIR)/matrix_generator.c
	$(CC) -o $@ $^ $(CFLAGS)

# misc

print-%:
	@echo $* = $($*)

clean:
	rm -f $(OBJ_DIR)/*.o $(INC_DIR)/*~ $(TARGET) $(LIB_DIR)/*.so *~ *.o
