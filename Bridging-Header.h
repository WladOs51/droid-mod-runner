#ifndef Bridging_Header_h
#define Bridging_Header_h

#include <stdint.h>
#include <stddef.h>

int extract_apk_package_info(const uint8_t *axml_data, size_t len, char *out_pkg, size_t max_pkg_len);
int inspect_dex_file(const uint8_t *dex_bytes, size_t len);
int32_t dalvik_vm_execute_bytecode(const uint16_t *insns, size_t insn_count);
int execute_android_arm64_so_function(const uint8_t *raw_machine_code, size_t code_size, int arg1, int arg2);
int native_unzip_archive(const char *zip_path, const char *dest_dir);

#endif
