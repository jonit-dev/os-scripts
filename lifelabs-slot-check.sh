#!/bin/bash

# ===========================
# Configuration
# ===========================

# **Important:** Replace the placeholders with your actual values.
AUTH_TOKEN="DA4089BEFD46B23F958EF6422C995E54E9B797E5435529544350BE71B0DFE4EB"
SITE_ID="cfa41b73-1592-ef11-8a6a-7c1e5240b167"
PROXY_URL="https://pwt-proxy.lifelabs.com/proxy/location/time"
ORIGIN_URL="https://appointments.lifelabs.com"
REFERER_URL="https://appointments.lifelabs.com"

# Telegram Configuration
TELEGRAM_BOT_TOKEN="7593083657:AAFiSsBGuWuRS421B-6ips0v71QgC20Z-pk"  # Ensure this token is kept secure
TELEGRAM_CHAT_ID="1063140002"  # Your Telegram Chat ID

# **Security Note:** It's advisable to store sensitive information like AUTH_TOKEN and TELEGRAM_BOT_TOKEN in environment variables or a separate secured configuration file.

# ===========================
# Headers Configuration
# ===========================

HEADERS=(
  -H "Accept: */*"
  -H "Accept-Language: en-GB,en;q=0.7"
  -H "Authorization: Bearer $AUTH_TOKEN"
  -H "Content-Type: application/json"
  -H "Cookie: visid_incap_2849147=ypeS+9JyRKiauBR4YrlpnWJ1XmcAAAAAQUIPAAAAAAAIR+thJM0CzRSYTsofn3yG; visid_incap_2903219=/EiwNjs+Rqe7iRBSAnwvInB1XmcAAAAAQUIPAAAAAACfABDB1H/JNNgtE+XwcATx; visid_incap_2863522=f+Dt/uzESZSfxIKMTSJkVIV1XmcAAAAAQUIPAAAAAACmOkouhfwdZVpz0r5+9EQx; visid_incap_3124301=NwWIVNixQRK5UiH/beyMl4h1XmcAAAAAQUIPAAAAAACwo7KGaLiF1tmJYfK28QQu; visid_incap_3124307=o2+yJr3hTsetZdBDk3ZbD5J1XmcAAAAAQUIPAAAAAABe4cbP5zvfrTrK9nvwBbQb; incap_ses_678_2849147=+1qPdccFkV6epmCjsL1oCf5bfGcAAAAA0WyQp/WXjeU2VW1+Y2XIOA==; incap_ses_678_2863522=JsrdCrf3BGPoqGCjsL1oCQBcfGcAAAAAKAFV7v9wTzC8mVRaP8WekQ==; incap_ses_678_3124301=eykkGoafEB9GqmCjsL1oCQJcfGcAAAAAycuskSbWMOiY5Xf+c64iVQ==; ARRAffinity=cf34161d1134f92611bf8d0dc2cbe0e72047765b2c8bc4391be0020dc8948870; ARRAffinitySameSite=cf34161d1134f92611bf8d0dc2cbe0e72047765b2c8bc4391be0020dc8948870; incap_ses_678_3124307=nyLPTZnDjWuyqmCjsL1oCQRcfGcAAAAAW5X8SGqXq+VxwDc5f2IxkQ==; visid_incap_2863365=NM6RwUiDR3S5v0WdO45b9A1cfGcAAAAAQUIPAAAAAAChJWW+m4Vrx/1C6OWWQLLt; nlbi_2863365=TQaCYgMBR3XqkTeI869QcgAAAADAPC1ykgPtuNsmVT4Sorug; incap_ses_678_2863365=yNfVPY+mz0gZsmCjsL1oCQ5cfGcAAAAAA2SHK2AG3tQe/L37sY8/HA=="
  -H "Origin: $ORIGIN_URL"
  -H "Priority: u=1, i"
  -H "Referer: $REFERER_URL"
  -H 'Sec-CH-UA: "Brave";v="131", "Chromium";v="131", "Not_A Brand";v="24"'
  -H "Sec-CH-UA-Mobile: ?0"
  -H 'Sec-CH-UA-Platform: "Windows"'
  -H "Sec-Fetch-Dest: empty"
  -H "Sec-Fetch-Mode: cors"
  -H "Sec-Fetch-Site: same-site"
  -H "Sec-GPC: 1"
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
)

# ===========================
# Logging Configuration
# ===========================

LOG_FILE="available_slots.log"
RAW_RESPONSE_LOG="raw_responses.log"

# Create or clear the log files
> "$LOG_FILE"
> "$RAW_RESPONSE_LOG"

# ===========================
# Function: Send Telegram Message
# ===========================

send_telegram_message() {
  local message="$1"
  curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="$message" >/dev/null
}

# ===========================
# Function: Send Request & Parse Response
# ===========================

send_request() {
  local date="$1"
  local payload
  local response
  local error
  local appointmentSlots
  local slots

  # Construct JSON payload using jq
  payload=$(jq -n --arg site_id "$SITE_ID" --arg dt "$date" '{site_id: [$site_id], date: [$dt]}')

  # Send the POST request and capture the response
  response=$(curl "$PROXY_URL" "${HEADERS[@]}" --data-raw "$payload" --silent --show-error)

  # Log the raw response for debugging
  echo "---------- $(date +"%Y-%m-%d %H:%M:%S") ----------" >> "$RAW_RESPONSE_LOG"
  echo "DATE: $date" >> "$RAW_RESPONSE_LOG"
  echo "$response" >> "$RAW_RESPONSE_LOG"

  # Check if curl command succeeded
  if [ $? -ne 0 ]; then
    echo "----------" | tee -a "$LOG_FILE"
    echo "DATE: $date" | tee -a "$LOG_FILE"
    echo "Error: Failed to connect to $PROXY_URL" | tee -a "$LOG_FILE"
    return
  fi

  # Check for errors in the response
  error=$(echo "$response" | jq -r '.errorMessage // empty')

  if [[ -n "$error" ]]; then
    echo "----------" | tee -a "$LOG_FILE"
    echo "DATE: $date" | tee -a "$LOG_FILE"
    echo "Error: $error" | tee -a "$LOG_FILE"
    return
  fi

  # Parse and display available slots
  echo "----------" | tee -a "$LOG_FILE"
  echo "DATE: $date" | tee -a "$LOG_FILE"
  echo "Available Appointment Times:" | tee -a "$LOG_FILE"

  # Safely extract appointmentSlots
  appointmentSlots=$(echo "$response" | jq '.appointmentSlots')

  if [[ "$appointmentSlots" == "null" || "$appointmentSlots" == "[]" ]]; then
    echo "  No available slots." | tee -a "$LOG_FILE"
  else
    # Extract slots using jq with safe navigation
    slots=$(echo "$response" | jq -r '.appointmentSlots[].slots[]? | .time // empty')

    if [[ -z "$slots" ]]; then
      echo "  No available slots." | tee -a "$LOG_FILE"
    else
      while IFS= read -r slot_time; do
        # Convert ISO8601 to human-readable format
        # Note: On macOS, replace 'date -d' with 'gdate -d' if using GNU date
        readable_time=$(date -d "$slot_time" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)

        # Check if date conversion was successful
        if [[ $? -ne 0 ]]; then
          # For systems like macOS without 'date -d', use an alternative method or skip
          readable_time="$slot_time"
        fi

        echo "  - $readable_time" | tee -a "$LOG_FILE"

        # Extract hour from the slot time
        slot_hour=$(date -d "$slot_time" +"%H" 2>/dev/null)

        # Check if date conversion was successful
        if [[ $? -eq 0 ]]; then
          # Force slot_hour to be interpreted as decimal to avoid octal issues
          slot_hour=$((10#$slot_hour))
          
          # Check if the slot time is before 11 AM
          if [[ "$slot_hour" -lt 11 ]]; then
            # Send Telegram notification
            send_telegram_message "✅ Available Slot Found!\nDate: $date\nTime: $readable_time"
          fi
        fi
      done <<< "$slots"
    fi
  fi
}

# ===========================
# Function: Get Today's Date
# ===========================

get_today_date() {
  date +"%Y-%m-%d"
}

# ===========================
# Function: Get Date 4 Days From Today (Total 5 Days)
# ===========================

get_five_days_from_today() {
  date -d "$(date +%Y-%m-%d) +4 days" +"%Y-%m-%d"
}

# ===========================
# Function: Generate Date Range (Today to 5 Days Later)
# ===========================

generate_date_range() {
  local start_date="$1"
  local end_date="$2"
  local current_date="$start_date"

  while [[ "$current_date" < "$end_date" || "$current_date" == "$end_date" ]]; do
    echo "$current_date"
    current_date=$(date -I -d "$current_date + 1 day")
  done
}

# ===========================
# Main Execution Loop
# ===========================

while true; do
  # Get today's date and the date 4 days from today (total 5 days)
  TODAY=$(get_today_date)
  END_DAY=$(get_five_days_from_today)

  echo "Checking availability from $TODAY to $END_DAY..."

  # Generate the list of dates to check
  DATE_LIST=$(generate_date_range "$TODAY" "$END_DAY")

  # Loop over each date and send requests
  for current_date in $DATE_LIST; do
    send_request "$current_date"
    # Optional: Add a short delay to avoid overwhelming the server
    sleep 1
  done

  echo "All requests processed. Check '$LOG_FILE' for results and '$RAW_RESPONSE_LOG' for raw API responses."

  # Wait for 3 minutes before the next execution
  sleep 180
done
