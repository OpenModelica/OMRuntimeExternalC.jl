// A simple program that uses LoadLibrary and 
// GetProcAddress to access argv[1] dll and call symbol argv[2]
 
#include <windows.h> 
#include <stdio.h> 
 
typedef int (__cdecl *MYPROC)(LPCWSTR);

int main(int argc, const char** argv ) 
{ 
    HINSTANCE hinstLib;
    MYPROC ProcAdd; 
    BOOL fFreeResult, fRunTimeLinkSuccess = FALSE;
    
    if (argc < 3) {
      fprintf(stderr, "usage: %s lib.dll function_symbol\n", argv[0]);
      exit(1);
    }
 
    // Get a handle to the DLL module.
    hinstLib = LoadLibrary(argv[1]);
 
    // If the handle is valid, try to get the function address.
 
    if (hinstLib != NULL) { 
        ProcAdd = (MYPROC) GetProcAddress(hinstLib, argv[2]);
 
        // If the function address is valid, call the function.
 
        if (NULL != ProcAdd) {
          fRunTimeLinkSuccess = TRUE;
          (ProcAdd) (L"Message sent to the DLL function\n"); 
        } else {
          fprintf(stderr, "Error: %d. Could not lookup the symbol %s in the library: %s\n", GetLastError(), argv[2], argv[1]);
          perror("The error is: ");
          exit(1);
        }

        // Free the DLL module.
 
        fFreeResult = FreeLibrary(hinstLib); 
    } else {
      fprintf(stderr, "Error %d. Could not load the library: %s\n",  GetLastError(), argv[1]);
      perror("The error is: ");
      exit(1);
    }

    // If unable to call the DLL function, use an alternative.
    if (! fRunTimeLinkSuccess) 
        printf("Message printed from executable\n"); 

    return 0;

}