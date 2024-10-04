#!/bin/bash
[[ -n "${DEBUG:-}" ]] && set -x
set -eu -o pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

source /etc/profile.d/s3.sh

AWS_CLI_OPTS=(--color off)
[[ -n "${AWS_ENDPOINT}" ]] && AWS_CLI_OPTS+=(--endpoint-url "$AWS_ENDPOINT")

MYSQLDUMP_OPTS=(-u"${MYSQL_USER}" -p"$MYSQL_PASSWORD")

[[ -n "${MYSQL_HOST:-}" ]] && MYSQLDUMP_OPTS+=(-h"$MYSQL_HOST")

if [[ -z "${MYSQL_DATABASE:-}" ]]; then
    MYSQLDUMP_OPTS+=(--all-databases)
    BACKUP_FILENAME=all-databases
else
    MYSQLDUMP_OPTS+=(--databases "$MYSQL_DATABASE")
    BACKUP_FILENAME="$MYSQL_DATABASE"
fi

[[ -n "${MYSQLDUMP_ADDITIONAL_OPTS:-}" ]] && IFS=" " read -r -a MYSQLDUMP_ADDITIONAL_OPTS_ARR <<< "$MYSQLDUMP_ADDITIONAL_OPTS" && MYSQLDUMP_OPTS+=("${MYSQLDUMP_ADDITIONAL_OPTS_ARR[@]}")

S3_FILENAME="${BACKUP_BUCKET}/$(date "+${BACKUP_PREFIX}${BACKUP_FILENAME}${BACKUP_SUFFIX}")"

function s3() {
    aws "${AWS_CLI_OPTS[@]}" s3 "$@"
}

mysqldump "${MYSQLDUMP_OPTS[@]}" \
    | gpg --encrypt -r "${PGP_KEY}" --compress-algo zlib --quiet \
    | s3 cp - "s3://${S3_FILENAME}" \
    || (s3 rm "s3://${S3_FILENAME}";  $(exit 1))

E_CODE=$?

if [[ "$E_CODE" -eq 0 ]]; then
  STATUS="SUCCESS"
else
  STATUS="FAIL"
fi

REPORT="[$STATUS] MySQL backup of $MYSQL_DATABASE to $S3_FILENAME, exit code: $E_CODE"
echo "$REPORT"

SEND_MAIL_SCRIPT="${BASH_SOURCE%/*}/send-mail.sh"
if [[ "$E_CODE" -eq 0 ]]; then
  # send mail success
  exec "$SEND_MAIL_SCRIPT" -t '"$MAIL_TO"' -s '[SLAVE] Backup of "$MYSQL_DATABASE" successful"' -o '"$REPORT"'
else
  # send mail fail
  exec "$SEND_MAIL_SCRIPT" -t '"$MAIL_TO"' -s '"[SLAVE] Backup of $MYSQL_DATABASE error"' -o '"$REPORT"'
fi

echo "Notification email sent"
