#!/usr/bin/env bash
[[ ! ${WARDEN_DIR} ]] && >&2 echo -e "\033[31mThis script is not intended to be run directly!\033[0m" && exit 1
set -euo pipefail

function :: {
  echo
  echo "==> [$(date +%H:%M:%S)] $@"
}

## load configuration needed for setup
WARDEN_ENV_PATH="$(locateEnvPath)" || exit $?
loadEnvConfig "${WARDEN_ENV_PATH}" || exit $?

assertDockerRunning

## change into the project directory
cd "${WARDEN_ENV_PATH}"

## configure command defaults
CLEAR_FILES=
CLEAR_REDIS=
CLEAR_DB=
CLEAR_ALL=
LIST_SESSIONS=
COUNT_SESSIONS=
REDIS_DB=1

## argument parsing
while (( "$#" )); do
    case "$1" in
        --files)
            CLEAR_FILES=1
            shift
            ;;
        --redis)
            CLEAR_REDIS=1
            shift
            ;;
        --database)
            CLEAR_DB=1
            shift
            ;;
        --all)
            CLEAR_ALL=1
            shift
            ;;
        --list)
            LIST_SESSIONS=1
            shift
            ;;
        --count)
            COUNT_SESSIONS=1
            shift
            ;;
        --redis-db)
            shift
            REDIS_DB="$1"
            shift
            ;;
        *)
            error "Unrecognized argument '$1'"
            exit -1
            ;;
    esac
done

## if no specific action is specified, default to clearing all session storage
if [[ ! ${CLEAR_FILES} ]] && [[ ! ${CLEAR_REDIS} ]] && [[ ! ${CLEAR_DB} ]] && [[ ! ${LIST_SESSIONS} ]] && [[ ! ${COUNT_SESSIONS} ]]; then
    CLEAR_ALL=1
fi

## List active sessions
if [[ ${LIST_SESSIONS} ]]; then
    :: Listing active sessions

    # List file-based sessions
    if [[ -d "var/session" ]]; then
        echo "File-based sessions:"
        warden env exec php-fpm find var/session -name "sess_*" -type f -exec ls -la {} \; 2>/dev/null || echo "No file-based sessions found"
    fi

    # List Redis sessions
    if warden env exec redis redis-cli ping > /dev/null 2>&1; then
        echo -e "\nRedis sessions (database ${REDIS_DB}):"
        SESSION_COUNT=$(warden env exec redis redis-cli -n ${REDIS_DB} KEYS "sess_*" | wc -l)
        if [[ ${SESSION_COUNT} -gt 0 ]]; then
            warden env exec redis redis-cli -n ${REDIS_DB} KEYS "sess_*"
        else
            echo "No Redis sessions found"
        fi
    fi

    # List database sessions
    echo -e "\nDatabase sessions:"
    warden db connect -e "SELECT session_id, session_expires, CHAR_LENGTH(session_data) as data_length FROM core_session ORDER BY session_expires DESC LIMIT 10;" 2>/dev/null || echo "No database sessions table found or accessible"
fi

## Count sessions
if [[ ${COUNT_SESSIONS} ]]; then
    :: Counting sessions

    # Count file-based sessions
    if [[ -d "var/session" ]]; then
        FILE_COUNT=$(warden env exec php-fpm find var/session -name "sess_*" -type f | wc -l)
        echo "File-based sessions: ${FILE_COUNT}"
    fi

    # Count Redis sessions
    if warden env exec redis redis-cli ping > /dev/null 2>&1; then
        REDIS_COUNT=$(warden env exec redis redis-cli -n ${REDIS_DB} KEYS "sess_*" | wc -l)
        echo "Redis sessions (database ${REDIS_DB}): ${REDIS_COUNT}"
    fi

    # Count database sessions
    DB_COUNT=$(warden db connect -e "SELECT COUNT(*) as session_count FROM core_session;" 2>/dev/null | tail -n 1) || DB_COUNT="N/A"
    echo "Database sessions: ${DB_COUNT}"
fi

## Clear file-based sessions
if [[ ${CLEAR_FILES} ]] || [[ ${CLEAR_ALL} ]]; then
    :: Clearing file-based sessions

    if [[ -d "var/session" ]]; then
        warden env exec php-fpm rm -rf var/session/sess_*
        echo "✓ File-based sessions cleared"
    else
        echo "⚠ No var/session directory found"
    fi
fi

## Clear Redis sessions
if [[ ${CLEAR_REDIS} ]] || [[ ${CLEAR_ALL} ]]; then
    :: Clearing Redis sessions

    if warden env exec redis redis-cli ping > /dev/null 2>&1; then
        SESSION_COUNT=$(warden env exec redis redis-cli -n ${REDIS_DB} KEYS "sess_*" | wc -l)
        if [[ ${SESSION_COUNT} -gt 0 ]]; then
            warden env exec redis redis-cli -n ${REDIS_DB} EVAL "return redis.call('del', unpack(redis.call('keys', ARGV[1])))" 0 "sess_*"
            echo "✓ Redis sessions cleared (${SESSION_COUNT} sessions from database ${REDIS_DB})"
        else
            echo "⚠ No Redis sessions found in database ${REDIS_DB}"
        fi
    else
        warning "Redis service is not running or not accessible"
    fi
fi

## Clear database sessions
if [[ ${CLEAR_DB} ]] || [[ ${CLEAR_ALL} ]]; then
    :: Clearing database sessions

    warden db connect -e "DELETE FROM core_session;" 2>/dev/null && echo "✓ Database sessions cleared" || echo "⚠ Could not clear database sessions (table may not exist)"
fi

:: Session management complete
