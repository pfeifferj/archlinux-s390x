# Arch Linux Kernel Build for s390x

Cross-compilation of the Arch Linux kernel for IBM s390x.

## Files

- `PKGBUILD-s390x` -- modified PKGBUILD for s390x cross-compilation
- `config-s390x` -- kernel config with s390x drivers (DASD, QETH, channel I/O) and Arch defaults
- `linux/` -- clone of Arch Linux kernel packaging repository (reference)

## Differences from Standard Arch Kernel

- Uses `s390x-linux-gnu-gcc` cross-compilation toolchain
- s390x-specific config: DASD storage, QETH networking, channel I/O, `CONFIG_UNIX=y`, `CONFIG_KMOD=y`
- No documentation build
- Boot image from `arch/s390/boot/bzImage` instead of x86

## Building

```bash
make kernel
```
