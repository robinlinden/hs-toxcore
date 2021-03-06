ifneq ($(shell which nproc),)
PROCS	:= $(shell nproc)
else
PROCS	:= $(shell sysctl -n hw.ncpu)
endif

ifneq ($(wildcard ../spec/pandoc.mk),)
ifneq ($(shell which pandoc),)
DOCS	:= ../spec/spec.md
include ../spec/pandoc.mk
endif
endif

ifneq ($(shell which clang-format),)
CLANG_FORMAT := clang-format
endif
ifneq ($(shell which clang-format-3.8),)
CLANG_FORMAT := clang-format-3.8
endif
CLANG_FORMAT ?= nonexistent-program

ifneq ($(shell which clang-tidy),)
CLANG_TIDY := clang-tidy
endif
ifneq ($(shell which clang_tidy),)
CLANG_TIDY := clang_tidy
endif
ifneq ($(shell which clang-tidy-3.8),)
CLANG_TIDY := clang-tidy-3.8
endif
CLANG_TIDY ?= nonexistent-program


# Cabal version-dependent flags.
CABAL_VER_NUM := $(shell cabal --numeric-version)
CABAL_VER_MAJOR := $(shell echo $(CABAL_VER_NUM) | cut -f1 -d.)
CABAL_VER_MINOR := $(shell echo $(CABAL_VER_NUM) | cut -f2 -d.)
CABAL_GT_1_22 := $(shell [ $(CABAL_VER_MAJOR) -gt 1 -o \( $(CABAL_VER_MAJOR) -eq 1 -a $(CABAL_VER_MINOR) -ge 22 \) ] && echo true)

ifeq ($(CABAL_GT_1_22),true)
ENABLE_COVERAGE		= --enable-coverage
DISABLE_PROFILING	= --disable-profiling
HPC_DIRS		= --hpcdir=. --srcdir=. `ls -d dist/hpc/vanilla/mix/* | sed -e 's/^/--srcdir=/'`
CABAL_JOBS		= --jobs=$(PROCS)
else
ENABLE_COVERAGE		= --enable-library-coverage
DISABLE_PROFILING	=
HPC_DIRS		= --hpcdir=. --srcdir=. `ls -d dist/hpc/mix/* | sed -e 's/^/--srcdir=/'`
CABAL_JOBS		=
endif
