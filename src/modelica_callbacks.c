/*
 * Julia-compatible implementations of ModelicaUtilities callback functions,
 * plus safe wrappers for ModelicaIO/ModelicaExternalC functions.
 *
 * The Modelica specification requires the simulation environment to provide
 * ModelicaError, ModelicaFormatError, etc. The OpenModelica runtime provides
 * these using setjmp/longjmp with thread-local data initialized by OMC.
 * When calling from Julia, that data is not set up, causing segfaults.
 *
 * This shim:
 * 1) Replaces the OMC error handlers with our own (load with RTLD_GLOBAL)
 * 2) Provides safe_* wrapper functions that do setjmp in C, call the target
 *    via dlsym, and return an error code + message on failure.
 *
 * Compile: gcc -shared -fPIC -o libModelicaCallbacks.so modelica_callbacks.c -ldl
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <setjmp.h>
#include <string.h>
#include <dlfcn.h>

/* Thread-local jump buffer and error message storage */
static __thread jmp_buf *jmpbuf_ptr = NULL;
static __thread char error_msg[4096];

/* Returns the stored error message (called from Julia after a safe_* call fails) */
const char* modelica_get_error_msg(void) {
    return error_msg;
}

/* ---- ModelicaUtilities callback replacements ---- */

void ModelicaFormatError(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(error_msg, sizeof(error_msg), fmt, ap);
    va_end(ap);
    if (jmpbuf_ptr) {
        longjmp(*jmpbuf_ptr, 1);
    }
    fprintf(stderr, "ModelicaFormatError: %s\n", error_msg);
    abort();
}

void ModelicaVFormatError(const char *fmt, va_list ap) {
    vsnprintf(error_msg, sizeof(error_msg), fmt, ap);
    if (jmpbuf_ptr) {
        longjmp(*jmpbuf_ptr, 1);
    }
    fprintf(stderr, "ModelicaVFormatError: %s\n", error_msg);
    abort();
}

void ModelicaError(const char *msg) {
    strncpy(error_msg, msg, sizeof(error_msg) - 1);
    error_msg[sizeof(error_msg) - 1] = '\0';
    if (jmpbuf_ptr) {
        longjmp(*jmpbuf_ptr, 1);
    }
    fprintf(stderr, "ModelicaError: %s\n", error_msg);
    abort();
}

void ModelicaFormatMessage(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stdout, fmt, ap);
    va_end(ap);
}

void ModelicaVFormatMessage(const char *fmt, va_list ap) {
    vfprintf(stdout, fmt, ap);
}

void ModelicaMessage(const char *msg) {
    fputs(msg, stdout);
}

void ModelicaFormatWarning(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "ModelicaWarning: ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
}

void ModelicaVFormatWarning(const char *fmt, va_list ap) {
    fprintf(stderr, "ModelicaWarning: ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
}

void ModelicaWarning(const char *msg) {
    fprintf(stderr, "ModelicaWarning: %s\n", msg);
}

/* Memory allocation callbacks */
char* ModelicaAllocateString(size_t len) {
    char *s = (char *)malloc(len + 1);
    if (s) s[0] = '\0';
    return s;
}

char* ModelicaAllocateStringWithErrorReturn(size_t len) {
    return (char *)malloc(len + 1);
}

/* ---- Safe wrappers: setjmp in C, call target via dlsym ---- */
/* Return 0 on success, 1 on error (message in modelica_get_error_msg()) */

int safe_ModelicaIO_readMatrixSizes(
    const char* fileName, const char* matrixName, int* dim)
{
    typedef void (*fn_t)(const char*, const char*, int*);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaIO_readMatrixSizes");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaIO_readMatrixSizes not found");
        return 1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        fn(fileName, matrixName, dim);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaIO_readRealMatrix(
    const char* fileName, const char* matrixName,
    double* matrix, size_t m, size_t n, int verbose)
{
    typedef void (*fn_t)(const char*, const char*, double*, size_t, size_t, int);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaIO_readRealMatrix");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaIO_readRealMatrix not found");
        return 1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        fn(fileName, matrixName, matrix, m, n, verbose);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaIO_writeRealMatrix(
    const char* fileName, const char* matrixName,
    double* matrix, size_t m, size_t n, int append, const char* version)
{
    typedef int (*fn_t)(const char*, const char*, double*, size_t, size_t, int, const char*);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaIO_writeRealMatrix");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaIO_writeRealMatrix not found");
        return -1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        int res = fn(fileName, matrixName, matrix, m, n, append, version);
        jmpbuf_ptr = NULL;
        return res;
    } else {
        jmpbuf_ptr = NULL;
        return -1;
    }
}

int safe_ModelicaInternal_print(const char* string, const char* fileName) {
    typedef void (*fn_t)(const char*, const char*);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaInternal_print");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaInternal_print not found");
        return 1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        fn(string, fileName);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaInternal_readLine(
    const char* fileName, int lineNumber,
    const char** buffer, int* endOfFile)
{
    typedef const char* (*fn_t)(const char*, int, int*);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaInternal_readLine");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaInternal_readLine not found");
        return 1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        *buffer = fn(fileName, lineNumber, endOfFile);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaInternal_countLines(const char* fileName, int* result) {
    typedef int (*fn_t)(const char*);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaInternal_countLines");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaInternal_countLines not found");
        return 1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        *result = fn(fileName);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaInternal_fullPathName(const char* fileName, const char** result) {
    typedef const char* (*fn_t)(const char*);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaInternal_fullPathName");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaInternal_fullPathName not found");
        return 1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        *result = fn(fileName);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaInternal_stat(const char* name, int* result) {
    typedef int (*fn_t)(const char*);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaInternal_stat");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaInternal_stat not found");
        return 1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        *result = fn(name);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaStreams_closeFile(const char* fileName) {
    typedef void (*fn_t)(const char*);
    fn_t fn = (fn_t)dlsym(RTLD_DEFAULT, "ModelicaStreams_closeFile");
    if (!fn) {
        snprintf(error_msg, sizeof(error_msg), "ModelicaStreams_closeFile not found");
        return 1;
    }
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        fn(fileName);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}
