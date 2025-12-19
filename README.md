
# Apps

A collection of small, practical Linux utilities and scripts, each designed to solve a specific task. Each app is self-contained and easy to use.

This repository serves as a home for all tiny tools you create — each app has its own section, usage instructions, and optional configuration.

---

## Table of Contents

* [Bluetooth Audio Utilities](#bluetooth-audio-utilities)
* [Battery Monitoring](#battery-monitoring)
* [Other Utilities](#other-utilities)

---

## Bluetooth Audio Utilities

Scripts to simplify connecting, managing, and routing audio to Bluetooth devices.

### `bt-connect.sh`

**Description:**
Connect a trusted Bluetooth device by shortcut, automatically switch profile, unsuspend the sink, set as default, and move all current audio streams.

**Requirements:**

| Package | Purpose |
| :--- | :--- |
| `bluetooth` / `bluez` | Core Bluetooth stack for Linux; manages Bluetooth devices. |
| `bluez-tools` | Command-line tools to control Bluetooth devices (`bluetoothctl`). |
| `pipewire` / `pipewire-pulse` | Modern audio server; replaces PulseAudio for routing audio streams. |
| `wireplumber` | Session manager for PipeWire; handles device profiles and routing. |
| `pipewire-audio-client-libraries` | Provides client libraries to control PipeWire sinks and streams. |
| `libspa-0.2-bluetooth` | Bluetooth SPA plugin for PipeWire; enables A2DP/HSP profiles. |

Install with:

```bash
sudo apt update
sudo apt install bluetooth bluez bluez-tools pipewire pipewire-pulse wireplumber pipewire-audio-client-libraries libspa-0.2-bluetooth
```

**Notes:**

* Make sure to **mask PulseAudio** if migrating fully to PipeWire to avoid conflicts:

  ```bash
  systemctl --user mask pulseaudio.service pulseaudio.socket
  systemctl --user enable --now pipewire pipewire-pulse wireplumber
  ```
* These packages allow connecting, trusting, and routing audio to Bluetooth headsets reliably with `bt-connect.sh`.

**Usage:**

```bash
# Connect to Q20i using default A2DP profile
bt-connect.sh -s q20i

# Connect using headset profile (HSP/HFP)
bt-connect.sh -s q20i headset-head-unit
```

**Configuration:**
Edit the `DEVICES` array inside the script to add more shortcuts:

```bash
DEVICES=(
    [q20i]="88:0E:85:62:AB:ED"
    [earbuds]="XX:XX:XX:XX:XX:XX"
)
```

---

## Battery Monitoring

Scripts to monitor battery levels and send notifications when low or critical.  

### `battery-watch.sh`

**Description:**  
Continuously monitors battery status and sends desktop notifications when battery levels drop below configured thresholds.  

**Requirements:**

| Package | Purpose |
| :--- | :--- |
| `acpi` | Provides battery status information for monitoring (`acpi -b`). |
| `libnotify-bin` | Enables sending desktop notifications via `notify-send`. |

Install with:

```bash
sudo apt update
sudo apt install acpi libnotify-bin
```

**Usage:**

```bash
~/.local/bin/battery-watch.sh
```

**Configuration:**

* `LOW` and `CRITICAL` thresholds can be adjusted inside the script.
* `INTERVAL` defines how often (in seconds) the battery is checked.
* Can be run as a **systemd user service** to monitor battery in the background automatically.

**Example Systemd Service:**

Save as `~/.config/systemd/user/battery-watch.service`:

```ini
[Unit]
Description=Battery Watch Service

[Service]
ExecStart=%h/.local/bin/battery-watch.sh
Restart=always

[Install]
WantedBy=default.target
```

Enable and start the service:

```bash
systemctl --user daemon-reload
systemctl --user enable --now battery-watch.service
```

This ensures you get battery notifications automatically in the background.

---

## Other Utilities

This section is reserved for additional scripts or tools. Each app should have:

* **Description**
* **Usage**
* **Optional configuration or setup instructions**

Example:

### `example-script.sh`

**Description:**
A short description of what this utility does.

**Usage:**

```bash
./example-script.sh [options]
```

---

## Contributing

* Submit pull requests for new apps or improvements to existing scripts.
* Keep scripts **small, self-contained, and reliable**.
* Include clear usage instructions and any configuration details.

---

## License

[MIT License](LICENSE)

---