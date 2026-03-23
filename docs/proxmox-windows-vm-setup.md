# Proxmox Windows VM Setup for GPU Testing

Host: `ssh proxmox.polymetallic.co` (root)
Machine: Lenovo ThinkCentre M700 (10MR0047US), Intel i5-6500T, Intel HD Graphics 530
Purpose: Test Visage D3D11 rendering on real GPU hardware (unblocks A.6, D.3)

## Prerequisites

- [x] Proxmox installed and accessible via SSH
- [x] IOMMU already enabled (`intel_iommu=on iommu=pt` in GRUB)
- [x] VirtIO drivers ISO downloaded (`/var/lib/vz/template/iso/virtio-win.iso`, 754MB)
- [x] `screen` installed on host
- [ ] Windows 10 ISO downloaded and uploaded to Proxmox ISO storage
  - Download from: https://www.microsoft.com/en-us/software-download/windows10ISO
  - Select: Windows 10 multi-edition, 64-bit, English
  - Upload via Proxmox web UI or: `scp Win10_*.iso proxmox.polymetallic.co:/var/lib/vz/template/iso/`

## Setup Steps (to be done by Claude over SSH)

### 1. GPU Passthrough Config

- [ ] Verify IOMMU groups: `find /sys/kernel/iommu_groups/ -type l | sort -V`
- [ ] Check if i915 is loaded: `lsmod | grep i915`
- [ ] Blacklist i915 on host: `echo "blacklist i915" > /etc/modprobe.d/blacklist-i915.conf`
- [ ] Add vfio modules: add `vfio vfio_iommu_type1 vfio_pci` to `/etc/modules`
- [ ] Bind Intel HD 530 to vfio-pci (get PCI ID from `lspci -nn | grep VGA`)
- [ ] `update-initramfs -u`
- [ ] Reboot host (WARNING: host loses local display output — manage via web UI only)
- [ ] Verify GPU bound to vfio-pci after reboot

### 2. Create Windows VM

- [ ] Find next available VM ID: `pvesh get /cluster/nextid`
- [ ] Create VM via `qm create`:
  - Machine: q35
  - BIOS: OVMF (UEFI)
  - CPU: host (passthrough real CPU features)
  - RAM: 4-8GB (host has 16GB, ~5GB available)
  - Disk: 64GB on local-lvm (thin-provisioned, ~234GB available)
  - CD-ROM 1: Windows 10 ISO
  - CD-ROM 2: VirtIO drivers ISO
  - Network: VirtIO NIC
- [ ] Add Intel HD 530 as PCI passthrough device
- [ ] Add EFI disk for UEFI boot

### 3. Install Windows

- [ ] Boot VM, access via Proxmox web console (noVNC)
- [ ] Skip license key ("I don't have a product key")
- [ ] Select Windows 10 Pro
- [ ] Load VirtIO disk driver during install (Browse CD → virtio-win → vioscsi → w10 → amd64)
- [ ] Complete installation
- [ ] Install remaining VirtIO drivers (network, balloon, etc.) from VirtIO ISO
- [ ] Install Intel HD 530 graphics driver
- [ ] Verify D3D11 works: `dxdiag` should show Intel HD Graphics 530

### 4. Dev Environment Setup

- [ ] Install Visual Studio 2022 Build Tools (or Community) with C++ workload
- [ ] Install CMake + Ninja (via winget)
- [ ] Enable SSH (Settings → Optional Features → OpenSSH Server)
- [ ] Clone PlunderTube, build with Visage D3D11 enabled
- [ ] Test: PlunderTube standalone launches and renders UI (A.6)
- [ ] Test: JUCE-Plugin-Starter template with Visage bridge (D.3)

## Alternative: Parallels for Windows D3D11 Testing

Parallels Desktop on Apple Silicon provides D3D11 translation to Metal.
SSH access: `ssh parallels` (user: danielraffel)

**D3D11 confirmed available** via dxdiag:
- Card: Parallels Display Adapter (WDDM)
- DDI Version: 12, Feature Levels: 11_1, 11_0, 10_1, 10_0
- Display Memory: 4092 MB
- D3D Status: Enabled

**Build environment:**
- VS2022 Community with native ARM64 compiler (`Hostarm64/arm64`)
- CMake + Ninja installed
- PlunderTube builds 899/899 natively for ARM64

**VBlank crash RESOLVED:** JUCE 8.0.8 crashed on launch (access violation 0xc0000005
in `VBlankDispatcher::updateDisplay()`) due to Parallels virtual display driver returning
`DXGI_ERROR_NOT_CURRENTLY_AVAILABLE` from `EnumOutputs()`. Fixed in JUCE 8.0.9+.
Updated template to JUCE 8.0.12 — standalone now launches and stays running.
PlunderTube needs same JUCE update to test Visage D3D11 rendering.

Parallels does NOT support Linux Vulkan guests — use Proxmox for that.

See: https://kb.parallels.com/en/124137

## GPU Virtualization Research (2026-03-07)

Confirmed via Codex research (UTM docs, WWDC transcripts, Parallels/VMware KBs):

| Platform | Windows D3D11 | Linux Vulkan |
|----------|--------------|--------------|
| UTM (Apple Silicon) | No - no Windows 3D guest support | Experimental - UTM v5 beta Venus/Vulkan 1.3 |
| Parallels (Apple Silicon) | Yes - D3D11 translated to Metal | No - OpenGL/VirGL only |
| VMware Fusion (Apple Silicon) | Inconsistent docs - possibly DX11 from 13.5+ | No - OpenGL only |
| Proxmox + Intel HD 530 (ThinkCentre) | Yes - real GPU | Yes - real GPU |

Conclusion: Parallels for Windows D3D11, Proxmox ThinkCentre for Linux Vulkan.
UTM v5 beta Venus is experimental and has known rendering issues.

## Notes

- Windows runs unactivated (watermark only, full D3D11 functionality)
- Host display output lost after i915 blacklist — manage Proxmox via web UI at https://proxmox.polymetallic.co:8006
- Screen session `winvm` may still exist from prior work: `screen -ls` to check
- 11GB free on root (local storage) — ISOs fit but tight. VM disk goes on local-lvm.
- Existing VMs (100-114) are untouched
