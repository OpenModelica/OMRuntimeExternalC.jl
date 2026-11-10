/*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-2026, Open Source Modelica Consortium (OSMC),
 * c/o Linköpings universitet, Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF AGPL VERSION 3 LICENSE OR
 * THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8.
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
 * RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL
 * VERSION 3, ACCORDING TO RECIPIENTS CHOICE.
 *
 * The OpenModelica software and the OSMC (Open Source Modelica Consortium)
 * Public License (OSMC-PL) are obtained from OSMC, either from the above
 * address, from the URLs:
 * http://www.openmodelica.org or
 * https://github.com/OpenModelica/ or
 * http://www.ida.liu.se/projects/OpenModelica,
 * and in the OpenModelica distribution.
 *
 * GNU AGPL version 3 is obtained from:
 * https://www.gnu.org/licenses/licenses.html#GPL
 *
 * This program is distributed WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 * IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
 *
 * See the full OSMC Public License conditions for more details.
 *
 */

/*
 * The tool side of the Modelica external C interface, and safe entry points
 * for Julia.
 *
 * This file is compiled together with the C sources of the Modelica Standard
 * Library (ModelicaStandardTables, ModelicaIO, ModelicaMatIO, ModelicaInternal,
 * ModelicaStrings, ModelicaRandom, ModelicaFFT) into one shared library,
 * libModelicaExternalC (deps/build_libraries.sh). Nothing else is linked.
 *
 * 1) ModelicaUtilities.h (ModelicaError, ModelicaFormatError, ModelicaMessage,
 *    ModelicaAllocateString, ...) is the interface that a Modelica tool
 *    implements for the C code of a library. It is implemented here.
 *    Compiled external C code of a model, which calls these functions, finds
 *    them in the process once the library is loaded with RTLD_GLOBAL.
 * 2) Modelica code reports an error by calling ModelicaError, which must not
 *    return. Here the call jumps (longjmp) to the safe_* function that Julia
 *    called, which returns 1 and keeps the message (modelica_get_error_msg).
 *    The jump stays inside C: no Julia frame is between setjmp and longjmp.
 *    With no safe_* function active the error ends the process with abort().
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <setjmp.h>
#include <string.h>

#include "ModelicaUtilities.h"
#include "ModelicaIO.h"
#include "ModelicaInternal.h"

#if defined(_MSC_VER)
#  define THREAD_LOCAL __declspec(thread)
#else
#  define THREAD_LOCAL __thread
#endif

/* Jump buffer of the safe_* call running on this thread, and its error message. */
static THREAD_LOCAL jmp_buf *jmpbuf_ptr = NULL;
static THREAD_LOCAL char error_msg[4096];

/* The message of the last failed safe_* call on this thread. */
const char* modelica_get_error_msg(void) {
    return error_msg;
}

/* A Modelica error: jump to the safe_* call that is running, or end the process. */
static void raise_error(const char *what) {
    if (jmpbuf_ptr) {
        longjmp(*jmpbuf_ptr, 1);
    }
    fprintf(stderr, "%s: %s\n", what, error_msg);
    abort();
}

/* ---- ModelicaUtilities.h ---- */

void ModelicaFormatError(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(error_msg, sizeof(error_msg), fmt, ap);
    va_end(ap);
    raise_error("ModelicaFormatError");
    abort(); /* not reached; raise_error does not return */
}

void ModelicaVFormatError(const char *fmt, va_list ap) {
    vsnprintf(error_msg, sizeof(error_msg), fmt, ap);
    raise_error("ModelicaVFormatError");
    abort();
}

void ModelicaError(const char *msg) {
    strncpy(error_msg, msg, sizeof(error_msg) - 1);
    error_msg[sizeof(error_msg) - 1] = '\0';
    raise_error("ModelicaError");
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

char* ModelicaAllocateString(size_t len) {
    char *s = (char *)malloc(len + 1);
    if (!s) ModelicaError("ModelicaAllocateString: out of memory");
    s[0] = '\0';
    return s;
}

char* ModelicaAllocateStringWithErrorReturn(size_t len) {
    char *s = (char *)malloc(len + 1);
    if (s) s[0] = '\0';
    return s;
}

char* ModelicaDuplicateString(const char *str) {
    size_t len = strlen(str);
    char *s = ModelicaAllocateString(len);
    memcpy(s, str, len + 1);
    return s;
}

char* ModelicaDuplicateStringWithErrorReturn(const char *str) {
    size_t len = strlen(str);
    char *s = ModelicaAllocateStringWithErrorReturn(len);
    if (s) memcpy(s, str, len + 1);
    return s;
}

/* ---- safe_*: call a Modelica function, return 0 or an error code ---- */
/* Return 0 on success, nonzero on error (message in modelica_get_error_msg()). */

int safe_ModelicaIO_readMatrixSizes(
    const char* fileName, const char* matrixName, int* dim)
{
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        ModelicaIO_readMatrixSizes(fileName, matrixName, dim);
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
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        ModelicaIO_readRealMatrix(fileName, matrixName, matrix, m, n, verbose);
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
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        int res = ModelicaIO_writeRealMatrix(fileName, matrixName, matrix, m, n, append, version);
        jmpbuf_ptr = NULL;
        return res;
    } else {
        jmpbuf_ptr = NULL;
        return -1;
    }
}

int safe_ModelicaInternal_print(const char* string, const char* fileName) {
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        ModelicaInternal_print(string, fileName);
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
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        *buffer = ModelicaInternal_readLine(fileName, lineNumber, endOfFile);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaInternal_countLines(const char* fileName, int* result) {
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        *result = ModelicaInternal_countLines(fileName);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaInternal_fullPathName(const char* fileName, const char** result) {
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        *result = ModelicaInternal_fullPathName(fileName);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaInternal_stat(const char* name, int* result) {
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        *result = ModelicaInternal_stat(name);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}

int safe_ModelicaStreams_closeFile(const char* fileName) {
    jmp_buf buf;
    jmpbuf_ptr = &buf;
    if (setjmp(buf) == 0) {
        ModelicaStreams_closeFile(fileName);
        jmpbuf_ptr = NULL;
        return 0;
    } else {
        jmpbuf_ptr = NULL;
        return 1;
    }
}
