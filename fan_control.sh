#!/usr/bin/bash

# Configuration
FAN_PWM_MIN=15   # Minimum PWM duty cycle percentage
FAN_PWM_MAX=90   # Maximum PWM duty cycle percentage
TEMP_MIN=30      # Minimum temperature for fan control (°C)
TEMP_MAX=65      # Maximum temperature for fan control (°C)


IDRAC_IP="10.10.10.205"
IDRAC_USER="root"
IDRAC_PASS="$IDRAC_PASS" # or hardcode it here.
# IPMI PASSWORD ENV: IDRAC_PASS

# To re-enable dynamic fan control ie go back to factory settings.
# ipmitool -I lanplus -H $IDRAC_IP -U $IDRAC_USER -P $IDRAC_PASS raw 0x30 0x30 0x01 0x01

# Make sure you disable dynamic fan control once before setting up the crontab.
# ipmitool -I lanplus -H $IDRAC_IP -U $IDRAC_USER -P $IDRAC_PASS raw 0x30 0x30 0x01 0x00

# Calculate PWM based on temperature
calculate_pwm() {
    local temp=$1

    if (( temp <= TEMP_MIN )); then
        echo $FAN_PWM_MIN
    elif (( temp >= TEMP_MAX )); then
        echo $FAN_PWM_MAX
    else
        # Linear interpolation
        echo $(( (temp - TEMP_MIN) * (FAN_PWM_MAX - FAN_PWM_MIN) / (TEMP_MAX - TEMP_MIN) + FAN_PWM_MIN ))
    fi
}

# IPMI tool command configuration
IPMI_COMMAND="ipmitool -I lanplus -H $IDRAC_IP -U $IDRAC_USER -P $IDRAC_PASS sdr type temperature"

# Fetch temperatures, filter out "Disabled", and build an array
readarray -t temperatures < <($IPMI_COMMAND | grep Temp | cut -d"|" -f5 | cut -d" " -f2 | grep -v Disabled)

# Check if any valid temperatures were found
if [[ ${#temperatures[@]} -eq 0 ]]; then
    echo "No valid temperatures found."
    exit 1
fi

echo "All Temperatures: ${temperatures[*]}"

# Find the maximum temperature
max_temp=$(printf "%s\n" "${temperatures[@]}" | sort -nr | head -n1)
echo "Highest Temperature: $max_temp°C"

fan_pwm=$(calculate_pwm $max_temp)

echo "Setting Fan PWM to $fan_pwm%"
# Set fan PWM using ipmitool
ipmitool -I lanplus -H $IDRAC_IP -U $IDRAC_USER -P $IDRAC_PASS raw 0x30 0x30 0x02 0xff $(printf '0x%02X' $fan_pwm)