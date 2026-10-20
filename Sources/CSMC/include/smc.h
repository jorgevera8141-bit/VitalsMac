#ifndef SMC_H
#define SMC_H

#include <IOKit/IOKitLib.h>
#include <stdint.h>

typedef struct {
    char key[5];
    char type[5];
    uint32_t size;
    uint8_t bytes[32];
} SMCValue;

/// Opens a connection to the AppleSMC service.
kern_return_t smc_open(io_connect_t *connection);

void smc_close(io_connect_t connection);

/// Reads one key (4 characters) into `out`.
kern_return_t smc_read(io_connect_t connection, const char *key, SMCValue *out);

/// Writes the 4-character key at `index` (NUL-terminated) into `key_out`.
kern_return_t smc_key_at_index(io_connect_t connection, uint32_t index, char key_out[5]);

#endif
