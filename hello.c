#include <efi.h>
#include <efilib.h>

EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    InitializeLib(ImageHandle, SystemTable);

    /* Clear screen */
    uefi_call_wrapper(ST->ConOut->ClearScreen, 1, ST->ConOut);

    /* Print banner */
    Print(L"========================================\r\n");
    Print(L"   Hello, World! — UEFI OS v0.1\r\n");
    Print(L"========================================\r\n\r\n");

    /* Firmware info */
    Print(L"  Firmware Vendor : %s\r\n", ST->FirmwareVendor);
    Print(L"  Firmware Rev    : %d.%d\r\n",
          ST->FirmwareRevision >> 16, ST->FirmwareRevision & 0xFFFF);
    Print(L"  UEFI Revision   : %d.%d\r\n",
          ST->Hdr.Revision >> 16, ST->Hdr.Revision & 0xFFFF);

    /* Memory map size (quick sanity check) */
    UINTN MemMapSize = 0;
    UINTN MapKey, DescSize;
    UINT32 DescVer;
    uefi_call_wrapper(BS->GetMemoryMap, 5,
                      &MemMapSize, NULL, &MapKey, &DescSize, &DescVer);
    Print(L"  Memory Map Size : %d bytes\r\n", MemMapSize);

    Print(L"\r\n  Target: Intel i5-14400F / RTX 5060 / 64GB RAM\r\n");
    Print(L"\r\n  Press any key to shut down...\r\n");

    /* Wait for keypress */
    UINTN Index;
    uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &Index);

    /* Shutdown */
    uefi_call_wrapper(RT->ResetSystem, 4, EfiResetShutdown, EFI_SUCCESS, 0, NULL);

    /* Should not reach here */
    return EFI_SUCCESS;
}
