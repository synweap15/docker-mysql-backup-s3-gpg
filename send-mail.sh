#!/bin/bash

# Enable debug mode if DEBUG environment variable is set
[[ -n "${DEBUG:-}" ]] && set -x

# Usage info
usage() {
  echo "Usage: $0 [-t to_emails] [-c cc_emails] [-b bcc_emails] [-s subject] [-o body] [-a attachments]" 1>&2
  exit 1
}

# Initialize variables
to=""
cc=""
bcc=""
subject=""
body=""
attachments=""

# Get the arguments
while getopts "t:c:b:s:o:a:" flag; do
    case "${flag}" in
        t) to=${OPTARG} ;;
        c) cc=${OPTARG} ;;
        b) bcc=${OPTARG} ;;
        s) subject=${OPTARG} ;;
        o) body=${OPTARG} ;;
        a) attachments=${OPTARG} ;;
        *) usage ;;
    esac
done

# Basic validation
[[ -z "$to" ]] && { echo "Error: 'to' email is required"; usage; }
[[ -z "$subject" ]] && { echo "Error: 'subject' is required"; usage; }
[[ -z "$body" ]] && { echo "Error: 'body' is required"; usage; }

# Construct 'to', 'cc', 'bcc' JSON arrays
construct_email_array() {
  local emails="$1"
  local json_array=""

  IFS=',' read -r -a email_array <<< "$emails"
  for email in "${email_array[@]}"; do
      email=$(echo "$email" | xargs)  # Trim spaces
      json_array+="{\"email\": \"$email\"},"
  done

  json_array="${json_array%,}"  # Remove trailing comma
  echo "$json_array"
}

# Generate 'to', 'cc', 'bcc' arrays
to_json=$(construct_email_array "$to")
cc_json=""
if [[ -n "$cc" ]]; then
  cc_json=", \"cc\": ["$(construct_email_array "$cc")"]"
fi
bcc_json=""
if [[ -n "$bcc" ]]; then
  bcc_json=", \"bcc\": ["$(construct_email_array "$bcc")"]"
fi

# Construct attachments array if provided
attachments_json=""
if [[ -n "$attachments" ]]; then
  attachments_json="\"attachments\": ["
  IFS=',' read -r -a attachments_array <<< "$attachments"
  for attachment in "${attachments_array[@]}"; do
      base64_content=$(base64 -w 0 "$attachment")
      filename=$(basename "$attachment")
      mime_type=$(file --mime-type -b "$attachment")
      attachments_json+="{\"content\": \"$base64_content\", \"type\": \"$mime_type\", \"filename\": \"$filename\"},"
  done
  attachments_json="${attachments_json%,}]"  # Remove trailing comma and close array
fi

# Validate 'from' and API key
if [[ -z "$MAIL_FROM" ]]; then
  echo "Error: MAIL_FROM environment variable not set."
  exit 1
fi
if [[ -z "$SENDGRID_API_KEY" ]]; then
  echo "Error: SENDGRID_API_KEY environment variable not set."
  exit 1
fi

# Generate final JSON
sendGridJson="{\"personalizations\": [{\"to\": [${to_json}], \"subject\": \"$subject\"${cc_json}${bcc_json}}], \"from\": {\"email\": \"$MAIL_FROM\"}, \"content\": [{\"type\": \"text/html\", \"value\": \"$body\"}]"

# Add attachments to JSON if any
if [[ -n "$attachments_json" ]]; then
  sendGridJson+=", $attachments_json"
fi

sendGridJson+="}"  # Close the JSON object

# Output JSON for debugging
echo "sendGridJson = $sendGridJson"

# Save JSON to a temporary file
tfile=$(mktemp /tmp/sendgrid.XXXXXXXXX)
echo "$sendGridJson" > "$tfile"

# Send the HTTP request to SendGrid
response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" --request POST \
  --url https://api.sendgrid.com/v3/mail/send \
  --header "Authorization: Bearer $SENDGRID_API_KEY" \
  --header "Content-Type: application/json" \
  --data @"$tfile")

# Cleanup temporary file
rm "$tfile"

# Extract the response status
http_status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

# Check HTTP status code
if [[ "$http_status" -ne 202 ]]; then
  echo "Error: Failed to send email. Status code: $http_status"
  exit 1
fi

echo "Email sent successfully."
