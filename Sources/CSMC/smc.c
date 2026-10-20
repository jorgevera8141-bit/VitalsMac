#include "smc.h"
#include <string.h>

// Layout mirrors the structure the AppleSMC kernel driver expects.
typedef struct {
    char major;
    char minor;
    char build;
    char reserved;
    uint16_t release;
} SMCVersion;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCPLimitData;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    char dataAttributes;
} SMCKeyInfoData;

typedef struct {
    uint32_t key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfoData keyInfo;
    char result;
    char status;
    char data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCKeyData;

enum {
    kSMCHandleYPCEvent = 2,
    kSMCReadKey = 5,
    kSMCReadIndex = 8,
    kSMCGetKeyInfo = 9,
};

static uint32_t pack_fourcc(const char *s) {
    return ((uint32_t)(uint8_t)s[0] << 24) | ((uint32_t)(uint8_t)s[1] << 16) |
           ((uint32_t)(uint8_t)s[2] << 8) | (uint32_t)(uint8_t)s[3];
}

static void unpack_fourcc(uint32_t value, char out[5]) {
    out[0] = (char)(value >> 24);
    out[1] = (char)(value >> 16);
    out[2] = (char)(value >> 8);
    out[3] = (char)value;
    out[4] = '\0';
}

static kern_return_t smc_call(io_connect_t connection, SMCKeyData *input, SMCKeyData *output) {
    size_t outputSize = sizeof(SMCKeyData);
    return IOConnectCallStructMethod(connection, kSMCHandleYPCEvent, input, sizeof(SMCKeyData),
                                     output, &outputSize);
}

kern_return_t smc_open(io_connect_t *connection) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == IO_OBJECT_NULL) {
        return kIOReturnNotFound;
    }
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, connection);
    IOObjectRelease(service);
    return result;
}

void smc_close(io_connect_t connection) {
    IOServiceClose(connection);
}

kern_return_t smc_read(io_connect_t connection, const char *key, SMCValue *out) {
    SMCKeyData input;
    SMCKeyData output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    memset(out, 0, sizeof(*out));

    input.key = pack_fourcc(key);
    input.data8 = kSMCGetKeyInfo;
    kern_return_t result = smc_call(connection, &input, &output);
    if (result != KERN_SUCCESS || output.result != 0) {
        return result != KERN_SUCCESS ? result : kIOReturnNotFound;
    }

    out->size = output.keyInfo.dataSize > 32 ? 32 : output.keyInfo.dataSize;
    unpack_fourcc(output.keyInfo.dataType, out->type);
    memcpy(out->key, key, 4);
    out->key[4] = '\0';

    input.keyInfo.dataSize = output.keyInfo.dataSize;
    input.data8 = kSMCReadKey;
    memset(&output, 0, sizeof(output));
    result = smc_call(connection, &input, &output);
    if (result != KERN_SUCCESS || output.result != 0) {
        return result != KERN_SUCCESS ? result : kIOReturnError;
    }
    memcpy(out->bytes, output.bytes, sizeof(out->bytes));
    return KERN_SUCCESS;
}

kern_return_t smc_key_at_index(io_connect_t connection, uint32_t index, char key_out[5]) {
    SMCKeyData input;
    SMCKeyData output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));

    input.data8 = kSMCReadIndex;
    input.data32 = index;
    kern_return_t result = smc_call(connection, &input, &output);
    if (result != KERN_SUCCESS || output.result != 0) {
        return result != KERN_SUCCESS ? result : kIOReturnNotFound;
    }
    unpack_fourcc(output.key, key_out);
    return KERN_SUCCESS;
}
