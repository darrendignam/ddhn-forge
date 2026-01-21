# ViPER ARM64 Build Guide

This document describes how to build and use ARM64 versions of ViPER for Apple Silicon Macs and Windows ARM devices.

## Architecture Support

ViPER now supports two architectures:

- **x86_64 (amd64)**: Traditional Intel/AMD processors
- **ARM64 (aarch64)**: Apple Silicon (M1/M2/M3) and Windows ARM (Surface Pro X, etc.)

## Automated Builds

ARM64 builds are automatically created via GitHub Actions when you push a tag:

```bash
git tag v1.2.0
git push origin v1.2.0
```

This triggers two workflows:
- `build-ova.yml` - Builds x86_64 version (QCOW2, OVA)
- `build-ova-arm64.yml` - Builds ARM64 version (QCOW2, VHDX)

## Output Formats

### ARM64 Builds
- **QCOW2**: For Apple Silicon using UTM, Parallels, or QEMU
- **VHDX**: For Windows ARM using Hyper-V

### x86_64 Builds
- **QCOW2**: For KVM/QEMU environments
- **OVA**: For VirtualBox and VMware

## Local ARM64 Build

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get install qemu-system-arm qemu-efi-aarch64 qemu-utils ansible

# macOS (for cross-compilation)
brew install qemu ansible
```

### Build Steps

1. **Initialize Packer plugins:**
   ```bash
   packer init viper-arm64.pkr.hcl
   ```

2. **Validate configuration:**
   ```bash
   packer validate viper-arm64.pkr.hcl
   ```

3. **Build the ARM64 VM:**
   ```bash
   packer build viper-arm64.pkr.hcl
   ```
   
   ⚠️ **Warning**: This uses TCG emulation and will take 2-3 hours (much longer than native builds)

4. **Outputs will be in:** `output-qemu-arm64/`
   - `viper-v1.2-alpha-arm64.qcow2`
   - `viper-v1.2-alpha-arm64.vhdx`

### Manual VHDX Conversion

If you only have the QCOW2 file:

```bash
./scripts/convert-to-vhdx.sh
```

Or manually:

```bash
qemu-img convert -f qcow2 -O vhdx \
  output-qemu-arm64/viper-v1.2-alpha-arm64.qcow2 \
  output-qemu-arm64/viper-v1.2-alpha-arm64.vhdx
```

## Installation Instructions

### Apple Silicon (M1/M2/M3 Macs)

**Using UTM (Recommended):**

1. Download and install [UTM](https://mac.getutm.app/)
2. Download the ARM64 QCOW2 file
3. In UTM:
   - Click "Create a New Virtual Machine"
   - Select "Emulate"
   - Choose "Linux"
   - Under "Boot", select "Import existing disk"
   - Browse to the downloaded QCOW2 file
   - Configure: 2 CPUs, 4GB RAM
   - Start the VM

**Using Parallels Desktop:**

1. Open Parallels Desktop
2. File → New
3. Install Windows or another OS → Continue
4. Select "Image File"
5. Browse to the QCOW2 file
6. Follow the wizard

### Windows ARM (Surface Pro X, etc.)

**Using Hyper-V:**

1. Download the ARM64 VHDX file
2. Open Hyper-V Manager
3. Action → New → Virtual Machine
4. Select "Generation 2" (UEFI required)
5. Assign memory: 4096 MB
6. Configure networking as needed
7. Use existing virtual hard disk → Browse to VHDX
8. Finish the wizard
9. Before starting:
   - Settings → Security → Disable Secure Boot
   - Settings → Processor → 2 virtual processors
10. Start the VM

## Default Credentials

- **Username**: vagrant
- **Password**: vagrant

## Architecture Detection

The Ansible roles automatically detect the architecture and install the correct packages:

- Java-based tools (Tika, JHOVE, DROID, veraPDF) work on any architecture
- MediaArea tools (MediaInfo, MediaConch) are downloaded for the correct architecture
- Debian packages (Handbrake, GIMP, Inkscape) are installed from ARM64 repositories

## Performance Notes

### Build Times
- **x86_64 on x86_64 (with KVM)**: ~30-45 minutes
- **ARM64 on x86_64 (TCG emulation)**: ~2-3 hours (GitHub Actions timeout: 180 minutes)
- **ARM64 on ARM64 (native)**: ~30-45 minutes

### Runtime Performance
- ARM64 VMs running on Apple Silicon have excellent performance (native)
- ARM64 VMs on Windows ARM devices perform well (native)
- Cross-architecture emulation (running x86_64 on ARM or vice versa) is significantly slower

## Troubleshooting

### Build Fails with "Cannot access KVM"
This is expected for ARM64 builds on x86_64. The build uses TCG (software emulation) automatically.

### "UEFI firmware not found"
Install the QEMU UEFI firmware:
```bash
# Ubuntu/Debian
sudo apt-get install qemu-efi-aarch64

# macOS
# UEFI firmware is included with QEMU from Homebrew
```

### MediaArea Tools Installation Fails
Ensure the `viper_architecture` variable is correctly set in Ansible. Check:
```bash
ansible -m setup localhost | grep ansible_architecture
```

Should return `aarch64` on ARM64 or `x86_64` on AMD64/Intel.

### VM Won't Boot in Hyper-V
- Ensure you created a Generation 2 VM (UEFI)
- Disable Secure Boot in VM settings
- Verify the VHDX file is not corrupted (check file size and checksums)

### UTM Import Issues
- Make sure you select "Emulate" and then "Linux" when creating the VM
- Use "Import existing disk" option, not "Create a new disk"
- After import, verify the CPU architecture is set to ARM64 (aarch64)

## Technical Details

### Packer Configuration
- **QEMU Binary**: `qemu-system-aarch64`
- **Machine Type**: `virt` (ARM Virtual Machine)
- **CPU Model**: `cortex-a72`
- **Firmware**: QEMU UEFI for AArch64
- **Accelerator**: TCG (software emulation when cross-compiling)

### Debian ARM64
- **ISO**: Debian 12 (Bookworm) ARM64 netinstall
- **Architecture**: aarch64 (64-bit ARM)
- **Repositories**: All Debian packages available for ARM64

### Ansible Variables
```yaml
# Automatically set based on detected architecture
viper_architecture: "amd64"  # or "arm64"

# Used in MediaArea package URLs
download_url: "https://mediaarea.net/.../{{ viper_architecture }}.Debian_12.deb"
```

## CI/CD Pipeline

The GitHub Actions workflow for ARM64:
1. Installs ARM64 QEMU and dependencies
2. Initializes and validates Packer configuration
3. Builds the VM (with 180-minute timeout)
4. Converts QCOW2 to VHDX
5. Uploads both formats to artifact server
6. Creates GitHub release with download links

## File Sizes

Approximate sizes for ARM64 builds:
- QCOW2 (compressed): ~3-4 GB
- VHDX (fixed): ~4-5 GB

## Related Files

- [`viper-arm64.pkr.hcl`](../viper-arm64.pkr.hcl) - ARM64 Packer configuration
- [`.github/workflows/build-ova-arm64.yml`](../.github/workflows/build-ova-arm64.yml) - ARM64 CI/CD workflow
- [`scripts/convert-to-vhdx.sh`](../scripts/convert-to-vhdx.sh) - VHDX conversion script
- [`ansible/roles/viper.tools/defaults/main.yml`](../ansible/roles/viper.tools/defaults/main.yml) - Architecture detection

## Questions or Issues?

If you encounter problems with ARM64 builds, please open an issue on GitHub with:
- Your host architecture (Apple Silicon, Windows ARM, x86_64)
- Build logs or error messages
- Expected vs. actual behavior
