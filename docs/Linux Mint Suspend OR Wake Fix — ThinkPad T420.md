Here you go — a clean, reference-style Markdown summary of everything we established in this thread, written for future you or anyone with a ThinkPad running Linux Mint.

---

# 🧠 Linux Mint Suspend/Wake Fix — ThinkPad T420

**Context:**
Suspend/resume behavior became glitchy after earlier tweaks to allow wake from *any* peripheral while using the T420 in closed-lid, external-monitor mode.

**Goal:**

> Allow wake only via **power button**, while ignoring wake signals from **wireless mouse**, **built-in keyboard**, and **touchpad**.

---

## 🔍 Initial Investigation

### Step 1 — Inspect current wake sources

```bash
cat /proc/acpi/wakeup
```

Output before fix:

```
LID   S3  *enabled   platform:PNP0C0D:00
SLPB  S3  *enabled   platform:PNP0C0E:00
EHC1  S3  *enabled   pci:0000:00:1d.0
EHC2  S3  *enabled   pci:0000:00:1a.0
```

### Findings

| Device   | Description                                | Notes                                |
| -------- | ------------------------------------------ | ------------------------------------ |
| **LID**  | Lid switch                                 | Keep enabled for normal lid behavior |
| **SLPB** | Sleep button (Fn+F4 etc.)                  | Safe to keep enabled                 |
| **EHC1** | USB 2.0 host controller (right/rear ports) | Causes unwanted wake                 |
| **EHC2** | USB 2.0 host controller (left ports)       | Causes unwanted wake                 |

T420 has **no XHC** (no USB 3.0), so both EHC controllers cover all ports.

---

## ⚙️ Step-by-Step Fix

### 1. Temporarily disable USB wake

```bash
echo EHC1 | sudo tee /proc/acpi/wakeup
echo EHC2 | sudo tee /proc/acpi/wakeup
```

→ Now only `LID` and `SLPB` remain enabled:

```
LID   S3  *enabled
SLPB  S3  *enabled
```

✅ Suspend/wake now stable
✅ Wireless mouse & built-in keyboard no longer wake system
✅ Power button still wakes (hardware-controlled)

---

## 🔁 Make It Persistent

Create `/etc/systemd/system/disable-usb-wake.service`:

```ini
[Unit]
Description=Disable USB wake (ThinkPad T420)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c '
  for dev in EHC1 EHC2; do
    grep -q "^$dev" /proc/acpi/wakeup && echo $dev > /proc/acpi/wakeup
  done
'

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now disable-usb-wake.service
```

Verify after reboot:

```bash
cat /proc/acpi/wakeup | grep enabled
# → Only LID and SLPB should be enabled
```

---

## 🧩 Optional — Use Lid-Closed Mode Safely

If using an external monitor while lid is closed, tell systemd to ignore lid events:

```bash
sudo nano /etc/systemd/logind.conf
```

Uncomment and set:

```
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
```

Then reload:

```bash
sudo systemctl restart systemd-logind
```

This allows working in closed-lid mode **without suspend**, while still maintaining reliable suspend/resume via power button.

---

## 🧠 Technical Notes

* The ThinkPad T420 uses **EHC1/EHC2** (USB 2.0 controllers) for all USB ports.
* `EHC1` = rear/right ports, `EHC2` = left ports.
* `/proc/acpi/wakeup` toggles ACPI wake sources at runtime (non-persistent).
* BIOS “Wake on USB” can override these, but older T-series models usually rely on OS control.
* Systemd service ensures both controllers are toggled after boot, regardless of load order.

---

## ✅ Final State Summary

| Wake Source      | State    | Reason             |
| ---------------- | -------- | ------------------ |
| **Power Button** | Active   | Hardware wake      |
| **LID**          | Enabled  | Optional; harmless |
| **SLPB**         | Enabled  | Standard           |
| **EHC1**         | Disabled | Prevents USB wake  |
| **EHC2**         | Disabled | Prevents USB wake  |

Result:

> **Stable suspend/resume behavior.
> Laptop wakes only via power button.
> All USB, keyboard, and touchpad wake events ignored.**

---

### 🔖 File locations touched

* `/proc/acpi/wakeup` — runtime toggle (non-persistent)
* `/etc/systemd/system/disable-usb-wake.service` — persistent toggle
* `/etc/systemd/logind.conf` — optional lid-switch behavior

---

Would you like me to format this into a `.md` file (ready to drop into `~/Documents/fixes/thinkpad_suspend_fix.md`)?
