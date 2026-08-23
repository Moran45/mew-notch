//
//  ArionRGBController.m
//  MewNotch
//
//  Created by Codex on 25/02/26.
//

#import "ArionRGBController.h"

#import <IOKit/IOCFPlugIn.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/scsi/SCSITask.h>
#import <IOKit/scsi/SCSITaskLib.h>

#include <string.h>

NSErrorDomain const ArionRGBErrorDomain = @"ArionRGBErrorDomain";

static BOOL arionCopyStringProperty(io_registry_entry_t entry, CFStringRef key, char *output, size_t outputSize) {
    if (output == NULL || outputSize == 0) {
        return NO;
    }

    output[0] = '\0';

    CFTypeRef value = IORegistryEntryCreateCFProperty(entry, key, kCFAllocatorDefault, 0);
    if (value == NULL) {
        return NO;
    }

    BOOL didCopy = NO;
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        didCopy = CFStringGetCString((CFStringRef)value, output, (CFIndex)outputSize, kCFStringEncodingUTF8);
    }

    CFRelease(value);
    return didCopy;
}

@interface ArionRGBController ()
@end

@implementation ArionRGBController

+ (instancetype)sharedInstance {
    static ArionRGBController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}

- (BOOL)isArionAvailable {
    io_service_t service = [self findArionService];
    if (service == IO_OBJECT_NULL) {
        return NO;
    }

    IOObjectRelease(service);
    return YES;
}

- (BOOL)canOpenChannelWithError:(NSError * _Nullable * _Nullable)error {
    io_service_t service = [self findArionService];
    if (service == IO_OBJECT_NULL) {
        return [self populateError:error
                              code:ArionRGBErrorCodeDeviceNotFound
                       description:@"No se encontró un dispositivo ROG STRIX ARION conectado."];
    }

    SCSITaskDeviceInterface **device = [self createTaskDeviceInterfaceFromService:service error:error];
    IOObjectRelease(service);

    if (device == NULL) {
        return NO;
    }

    (*device)->Release(device);
    return YES;
}

- (BOOL)applyStaticColorWithRed:(uint8_t)red
                          green:(uint8_t)green
                           blue:(uint8_t)blue
                          error:(NSError * _Nullable * _Nullable)error {
    io_service_t service = [self findArionService];
    if (service == IO_OBJECT_NULL) {
        return [self populateError:error
                              code:ArionRGBErrorCodeDeviceNotFound
                       description:@"No se encontró un dispositivo ROG STRIX ARION conectado."];
    }

    SCSITaskDeviceInterface **device = [self createTaskDeviceInterfaceFromService:service error:error];
    IOObjectRelease(service);

    if (device == NULL) {
        return NO;
    }

    uint8_t staticMode = 1;
    uint8_t speed = 0x02;
    uint8_t direction = 0x00;
    uint8_t directFlag = 0x00;
    uint8_t applyChanges = 0x01;

    uint8_t colorPayload[12] = {0};
    for (int ledIndex = 0; ledIndex < 4; ledIndex++) {
        colorPayload[(ledIndex * 3) + 0] = red;
        colorPayload[(ledIndex * 3) + 1] = blue;   // El Arion usa orden RBG en este registro.
        colorPayload[(ledIndex * 3) + 2] = green;
    }

    BOOL didApply =
        [self writeRegister:0x8021 payload:&staticMode payloadSize:1 device:device error:error] &&
        [self writeRegister:0x8022 payload:&speed payloadSize:1 device:device error:error] &&
        [self writeRegister:0x8023 payload:&direction payloadSize:1 device:device error:error] &&
        [self writeRegister:0x80A0 payload:&applyChanges payloadSize:1 device:device error:error] &&
        [self writeRegister:0x8020 payload:&directFlag payloadSize:1 device:device error:error] &&
        [self writeRegister:0x80A0 payload:&applyChanges payloadSize:1 device:device error:error] &&
        [self writeRegister:0x8160 payload:colorPayload payloadSize:sizeof(colorPayload) device:device error:error] &&
        [self writeRegister:0x80A0 payload:&applyChanges payloadSize:1 device:device error:error];

    (*device)->Release(device);

    return didApply;
}

- (io_service_t)findArionService {
    CFMutableDictionaryRef matchingDictionary = IOServiceMatching("IOSCSIHierarchicalLogicalUnit");
    if (matchingDictionary == NULL) {
        return IO_OBJECT_NULL;
    }

    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator);
    if (result != KERN_SUCCESS || iterator == IO_OBJECT_NULL) {
        return IO_OBJECT_NULL;
    }

    io_service_t selectedService = IO_OBJECT_NULL;

    io_service_t service = IO_OBJECT_NULL;
    while ((service = IOIteratorNext(iterator))) {
        char vendor[64] = {0};
        char product[64] = {0};

        BOOL hasVendor = arionCopyStringProperty(service, CFSTR(kIOPropertySCSIVendorIdentification), vendor, sizeof(vendor));
        BOOL hasProduct = arionCopyStringProperty(service, CFSTR(kIOPropertySCSIProductIdentification), product, sizeof(product));

        if (hasVendor && hasProduct && strncmp(vendor, "ROG", 3) == 0 && strncmp(product, "ESD-S1C", 7) == 0) {
            selectedService = service;
            break;
        }

        IOObjectRelease(service);
    }

    IOObjectRelease(iterator);

    return selectedService;
}

- (SCSITaskDeviceInterface **)createTaskDeviceInterfaceFromService:(io_service_t)service
                                                              error:(NSError * _Nullable * _Nullable)error {
    CFTypeRef pluginTypes = IORegistryEntryCreateCFProperty(service, CFSTR("IOCFPlugInTypes"), kCFAllocatorDefault, 0);
    if (pluginTypes == NULL || CFGetTypeID(pluginTypes) != CFDictionaryGetTypeID()) {
        if (pluginTypes != NULL) {
            CFRelease(pluginTypes);
        }

        [self populateError:error
                       code:ArionRGBErrorCodeUserClientNotAvailable
                description:@"El nodo SCSI del Arion no expone IOCFPlugInTypes en macOS, por lo que no se puede crear un canal SCSITask desde user-space."];
        return NULL;
    }
    CFRelease(pluginTypes);

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;

    IOReturn result = IOCreatePlugInInterfaceForService(
        service,
        kIOSCSITaskDeviceUserClientTypeID,
        kIOCFPlugInInterfaceID,
        &plugin,
        &score
    );

    if (result != kIOReturnSuccess || plugin == NULL) {
        NSString *description = [NSString stringWithFormat:
                                 @"No fue posible abrir el canal SCSI del Arion (código: 0x%08x).",
                                 result];
        [self populateError:error
                       code:ArionRGBErrorCodeUserClientNotAvailable
                description:description];
        return NULL;
    }

    SCSITaskDeviceInterface **device = NULL;
    HRESULT queryResult = (*plugin)->QueryInterface(
        plugin,
        CFUUIDGetUUIDBytes(kIOSCSITaskDeviceInterfaceID),
        (LPVOID *)&device
    );

    (*plugin)->Release(plugin);

    if (queryResult != S_OK || device == NULL) {
        NSString *description = [NSString stringWithFormat:
                                 @"No fue posible inicializar la interfaz SCSI del Arion (HRESULT: 0x%08x).",
                                 (unsigned int)queryResult];
        [self populateError:error
                       code:ArionRGBErrorCodeUserClientNotAvailable
                description:description];
        return NULL;
    }

    return device;
}

- (BOOL)writeRegister:(uint16_t)registerAddress
              payload:(const uint8_t *)payload
          payloadSize:(uint8_t)payloadSize
               device:(SCSITaskDeviceInterface **)device
                error:(NSError * _Nullable * _Nullable)error {
    if (device == NULL || payload == NULL || payloadSize == 0) {
        return [self populateError:error
                              code:ArionRGBErrorCodeCommandFailed
                       description:@"Parámetros inválidos al generar el comando SCSI."];
    }

    SCSITaskInterface **task = (*device)->CreateSCSITask(device);
    if (task == NULL) {
        return [self populateError:error
                              code:ArionRGBErrorCodeCommandFailed
                       description:@"No se pudo crear la tarea SCSI para escribir color."];
    }

    SCSITaskSGElement scatterElement;
    memset(&scatterElement, 0, sizeof(scatterElement));
    scatterElement.address = (IOVirtualAddress)payload;
    scatterElement.length = payloadSize;

    IOReturn result = (*task)->SetScatterGatherEntries(
        task,
        &scatterElement,
        1,
        payloadSize,
        kSCSIDataTransfer_FromInitiatorToTarget
    );

    if (result != kIOReturnSuccess) {
        (*task)->Release(task);
        NSString *description = [NSString stringWithFormat:
                                 @"Falló SetScatterGatherEntries para el registro 0x%04x (0x%08x).",
                                 registerAddress,
                                 result];
        return [self populateError:error code:ArionRGBErrorCodeCommandFailed description:description];
    }

    uint8_t commandDescriptorBlock[16] = {0};
    commandDescriptorBlock[0] = 0xEC;
    commandDescriptorBlock[1] = 0x41;
    commandDescriptorBlock[2] = 0x53;
    commandDescriptorBlock[3] = (registerAddress >> 8) & 0xFF;
    commandDescriptorBlock[4] = registerAddress & 0xFF;
    commandDescriptorBlock[13] = payloadSize;

    result = (*task)->SetCommandDescriptorBlock(task, commandDescriptorBlock, sizeof(commandDescriptorBlock));
    if (result != kIOReturnSuccess) {
        (*task)->Release(task);
        NSString *description = [NSString stringWithFormat:
                                 @"No se pudo configurar el CDB para el registro 0x%04x (0x%08x).",
                                 registerAddress,
                                 result];
        return [self populateError:error code:ArionRGBErrorCodeCommandFailed description:description];
    }

    result = (*task)->SetTimeoutDuration(task, 20000);
    if (result != kIOReturnSuccess) {
        (*task)->Release(task);
        NSString *description = [NSString stringWithFormat:
                                 @"No se pudo establecer timeout para el registro 0x%04x (0x%08x).",
                                 registerAddress,
                                 result];
        return [self populateError:error code:ArionRGBErrorCodeCommandFailed description:description];
    }

    SCSI_Sense_Data senseData;
    memset(&senseData, 0, sizeof(senseData));

    SCSITaskStatus taskStatus = kSCSITaskStatus_No_Status;
    UInt64 bytesTransferred = 0;

    result = (*task)->ExecuteTaskSync(task, &senseData, &taskStatus, &bytesTransferred);
    (*task)->Release(task);

    if (result != kIOReturnSuccess || taskStatus != kSCSITaskStatus_GOOD) {
        NSString *description = [NSString stringWithFormat:
                                 @"El Arion rechazó el comando 0x%04x (resultado: 0x%08x, estado: %u).",
                                 registerAddress,
                                 result,
                                 taskStatus];
        return [self populateError:error code:ArionRGBErrorCodeCommandFailed description:description];
    }

    return YES;
}

- (BOOL)populateError:(NSError * _Nullable * _Nullable)error
                 code:(ArionRGBErrorCode)code
          description:(NSString *)description {
    if (error != NULL) {
        *error = [NSError errorWithDomain:ArionRGBErrorDomain
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: description}];
    }

    return NO;
}

@end
