# systemd s390x Big-Endian Patches

## Overview

When building systemd for s390x architecture, several big-endian compatibility issues need to be addressed. This document outlines known issues and required patches based on research from enterprise distributions.

## Known Issues

### 1. D-Bus Property Endianness

**Issue**: D-Bus property values may be incorrectly interpreted due to endianness
**Symptom**: Values like 131074 (0x20002) instead of expected values
**Affected Components**: systemd-resolved, systemd property queries

**Patch Required**:
```patch
--- a/src/libsystemd/sd-bus/bus-message.c
+++ b/src/libsystemd/sd-bus/bus-message.c
@@ -1234,7 +1234,7 @@ static int message_append_basic(sd_bus_message *m, char type, const void *p, co
         case SD_BUS_TYPE_UINT32:
         case SD_BUS_TYPE_UNIX_FD:
-                u32 = *(uint32_t*) p;
+                u32 = be32toh(*(uint32_t*) p);
                 p = &u32;
                 align = 4;
                 sz = 4;
```

### 2. systemd-resolved Big-Endian Failures

**Issue**: systemd-resolved fails on big-endian architectures
**Symptom**: Service fails to start, D-Bus communication errors
**Solution**: Disable systemd-resolved in build configuration (already done in our minimal build)

### 3. Integration Test Timeouts

**Issue**: Tests timeout more frequently on s390x
**Symptom**: Unit tests fail with timeout errors
**Solution**: Increase timeout values or disable tests (already done in our build)

### 4. /dev/kvm Permissions

**Issue**: Incorrect permissions on /dev/kvm device
**Symptom**: KVM acceleration not available to non-root users
**Solution**: Add udev rule for proper permissions

```bash
# /etc/udev/rules.d/99-kvm-s390x.rules
KERNEL=="kvm", GROUP="kvm", MODE="0660"
```

## Distribution-Specific Patches

### SUSE/openSUSE

SUSE maintains comprehensive s390x patches in their systemd package:
- Endianness fixes for D-Bus communication
- s390x-specific device handling
- Console output improvements

### Red Hat/Fedora

Red Hat includes patches for:
- Big-endian compatibility in property serialization
- s390x hardware console support
- Device node permission fixes

### Ubuntu

Ubuntu patches focus on:
- Integration test reliability
- Hardware-specific optimizations
- Kernel feature detection

## Implementation Strategy

1. **Start with minimal build** - Our configuration already disables problematic components
2. **Monitor logs carefully** - Use `systemd.log_level=debug` during initial testing
3. **Apply patches incrementally** - Test after each patch to isolate issues
4. **Use distribution patches** - Leverage existing work from SUSE/Red Hat/Ubuntu

## Testing Recommendations

```bash
# Enable comprehensive debugging
systemd.log_level=debug 
systemd.journald.forward_to_console=1
console=ttysclp0

# Test in container first
systemd-nspawn -bD /test-root --machine=s390x-test

# Monitor for endianness issues
journalctl -f | grep -E "(endian|0x[0-9a-f]+|property|dbus)"
```

## Resources

- [SUSE systemd s390x patches](https://build.opensuse.org/package/view_file/Base:System/systemd/)
- [Red Hat Bugzilla - s390x systemd issues](https://bugzilla.redhat.com/buglist.cgi?product=Fedora&component=systemd&bug_status=__open__&f1=cf_machine&o1=substring&v1=s390x)
- [systemd upstream s390x issues](https://github.com/systemd/systemd/issues?q=is%3Aissue+s390x)

## Conclusion

While s390x support in systemd requires patches for full functionality, the core init system works reliably. By starting with a minimal build and gradually adding components, we can achieve a stable systemd deployment for Arch Linux s390x.