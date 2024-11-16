# Dynamic Fan Control Using IPMI

This project provides a Bash script to dynamically control fan speeds based on server temperatures. It utilizes IPMI to monitor system temperatures and adjust fan Pulse Width Modulation (PWM) to maintain optimal cooling while minimizing noise and energy consumption.

---

## Overview

The script reads temperature data from your server using the IPMI protocol and calculates the appropriate fan speed using a configurable linear interpolation method. It sets the fan PWM via IPMI commands, overriding factory dynamic fan controls.

### Features:
- Dynamically adjusts fan speeds based on the highest reported temperature.
- Allows configuration of temperature thresholds and PWM ranges.
- Provides functionality to reset factory dynamic fan controls.
- Outputs real-time data for monitoring temperatures and fan speeds.

---

## Requirements

1. **IPMItool**:
   - Ensure `ipmitool` is installed on your server or client machine.
   - Installation example for Ubuntu:
     ```bash
     sudo apt-get install ipmitool
     ```

2. **Server Compatibility**:
   - The server must support IPMI commands for temperature monitoring and fan control.

3. **Environment Variable**:
   - The script optionally uses an environment variable `IDRAC_PASS` for the iDRAC password. Alternatively, you can hardcode the password directly in the script.

---

## Setup

1. Clone or copy the script to your server or client machine.
2. Make the script executable:
   ```bash
   chmod +x dynamic_fan_control.sh
   ```
3. Export the iDRAC password as an environment variable (optional):
   ```bash
   export IDRAC_PASS="your_password"
   ```

4. Disable factory dynamic fan control before running the script:
   ```bash
   ipmitool -I lanplus -H 10.10.10.205 -U root -P $IDRAC_PASS raw 0x30 0x30 0x01 0x00
   ```

5. (Optional) Re-enable factory fan control at any time:
   ```bash
   ipmitool -I lanplus -H 10.10.10.205 -U root -P $IDRAC_PASS raw 0x30 0x30 0x01 0x01
   ```
### Crontab Configuration for Fan Control

The script can be set up to run periodically using a **crontab** job. This ensures that the fan speed dynamically adjusts based on temperature changes without manual intervention. Below is an explanation of how to configure the crontab entry.

This is a "hacky" method to make a script execute approximately every 10 seconds using **cron**, which by default can only schedule tasks with a granularity of one minute. The trick involves creating multiple crontab entries with varying delays (using the `sleep` command) to stagger the script execution.

---

### Explanation of the Crontab Entries

Each crontab line schedules the same script (`/root/fan-temperature/fan_control.sh`), but with a different delay (`sleep`) before it starts.

#### Breakdown of Each Line:
1. **`* * * * *`**:
   - This specifies the job runs every minute (on the minute).

2. **`sleep X;`**:
   - Introduces a delay of `X` seconds before running the script. This ensures the script is staggered across the minute:
     - `sleep 10`: Waits 10 seconds.
     - `sleep 20`: Waits 20 seconds.
     - `sleep 30`: Waits 30 seconds.
     - `sleep 40`: Waits 40 seconds.
     - `sleep 50`: Waits 50 seconds.

3. **`/root/fan-temperature/fan_control.sh > /tmp/fan_control.txt 2>&1`**:
   - Runs the script and logs the output (`stdout` and `stderr`) to `/tmp/fan_control.txt`.

3. **Custom Cron Extensions**:
   Use a tool like `fcron` or `cron.deny` for finer time intervals.


### Setting Up the Crontab

1. Open the crontab editor for the root user (or the appropriate user if not running as root):
   ```bash
   crontab -e
   ```

2. Add the crontab entries.

3. Save and exit the editor. For example, if using `vim`, press `ESC`, type `:wq`, and press `Enter`.

4. Verify the crontab entry:
   ```bash
   crontab -l
   ```

---

## Configuration

Modify the following parameters in the script to match your system's requirements:

- **Temperature Thresholds**:
  ```bash
  TEMP_MIN=30   # Minimum temperature for fan control (°C)
  TEMP_MAX=65   # Maximum temperature for fan control (°C)
  ```

- **PWM Ranges**:
  ```bash
  FAN_PWM_MIN=15   # Minimum PWM duty cycle percentage
  FAN_PWM_MAX=90   # Maximum PWM duty cycle percentage
  ```

- **iDRAC Credentials**:
  ```bash
  IDRAC_IP="10.10.10.205"  # Replace with your iDRAC IP
  IDRAC_USER="root"        # Replace with your iDRAC username
  IDRAC_PASS="$IDRAC_PASS" # Environment variable or hardcoded password
  ```

---

## How It Works

1. **Temperature Monitoring**:
   - The script retrieves all temperature sensors using the `ipmitool` command:
     ```bash
     ipmitool -I lanplus -H $IDRAC_IP -U $IDRAC_USER -P $IDRAC_PASS sdr type temperature
     ```
   - It filters out invalid readings (e.g., "Disabled") and stores the valid temperatures in an array.

2. **Max Temperature Selection**:
   - The highest temperature is identified:
     ```bash
     max_temp=$(printf "%s\n" "${temperatures[@]}" | sort -nr | head -n1)
     ```

3. **PWM Calculation**:
   - The script calculates the fan speed using a linear interpolation:
     ```bash
     echo $(( (temp - TEMP_MIN) * (FAN_PWM_MAX - FAN_PWM_MIN) / (TEMP_MAX - TEMP_MIN) + FAN_PWM_MIN ))
     ```

4. **Fan Speed Adjustment**:
   - The calculated PWM is set using an IPMI raw command:
     ```bash
     ipmitool -I lanplus -H $IDRAC_IP -U $IDRAC_USER -P $IDRAC_PASS raw 0x30 0x30 0x02 0xff $(printf '0x%02X' $fan_pwm)
     ```

5. **Logging**:
   - Outputs the current temperatures and selected PWM value for transparency:
     ```bash
     echo "All Temperatures: ${temperatures[*]}"
     echo "Highest Temperature: $max_temp°C"
     echo "Setting Fan PWM to $fan_pwm%"
     ```

---

## Usage

Run the script manually or add it to a cron job for periodic execution. For example:

```bash
*/5 * * * * /path/to/dynamic_fan_control.sh >> /var/log/fan_control.log 2>&1
```

This runs the script every 5 minutes and logs output to `/var/log/fan_control.log`.

---

## Notes

1. **Test Before Deployment**:
   - Run the script manually and monitor the temperatures and fan speeds to ensure it works as expected.
2. **Fail-Safe**:
   - Always re-enable factory fan control in case of issues using:
     ```bash
     ipmitool -I lanplus -H $IDRAC_IP -U root -P $IDRAC_PASS raw 0x30 0x30 0x01 0x01
     ```
3. **Edge Cases**:
   - If no valid temperatures are found, the script exits with an error.

---

## License

MIT License