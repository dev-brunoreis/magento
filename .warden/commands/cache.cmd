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
CLEAR_REDIS=
CLEAR_MAGENTO=
CLEAR_ALL=
FLUSH_ALL=
REDIS_DB=0

## argument parsing
while (( "$#" )); do
    case "$1" in
        --redis)
            CLEAR_REDIS=1
            shift
            ;;
        --magento)
            CLEAR_MAGENTO=1
            shift
            ;;
        --all)
            CLEAR_ALL=1
            shift
            ;;
        --flush-all)
            FLUSH_ALL=1
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

## if no specific cache type is specified, default to clearing all
if [[ ! ${CLEAR_REDIS} ]] && [[ ! ${CLEAR_MAGENTO} ]] && [[ ! ${FLUSH_ALL} ]]; then
    CLEAR_ALL=1
fi

## Clear Redis cache
if [[ ${CLEAR_REDIS} ]] || [[ ${CLEAR_ALL} ]]; then
    :: Clearing Redis cache

    # Check if Redis is running
    if warden env exec redis redis-cli ping > /dev/null 2>&1; then
        if [[ ${FLUSH_ALL} ]]; then
            :: Flushing all Redis databases
            warden env exec redis redis-cli FLUSHALL
            echo "✓ All Redis databases flushed"
        else
            :: Clearing Redis database ${REDIS_DB}
            warden env exec redis redis-cli -n ${REDIS_DB} FLUSHDB
            echo "✓ Redis database ${REDIS_DB} cleared"
        fi
    else
        warning "Redis service is not running or not accessible"
    fi
fi

## Clear Magento cache
if [[ ${CLEAR_MAGENTO} ]] || [[ ${CLEAR_ALL} ]]; then
    :: Clearing Magento cache directories

    # Clear var/cache directory
    if [[ -d "var/cache" ]]; then
        warden env exec php-fpm rm -rf var/cache/*
        echo "✓ Magento var/cache cleared"
    fi

    # Clear var/full_page_cache directory
    if [[ -d "var/full_page_cache" ]]; then
        warden env exec php-fpm rm -rf var/full_page_cache/*
        echo "✓ Magento var/full_page_cache cleared"
    fi

    # Clear var/session directory
    if [[ -d "var/session" ]]; then
        warden env exec php-fpm rm -rf var/session/*
        echo "✓ Magento var/session cleared"
    fi

    # Clear media/css and media/js directories
    if [[ -d "media/css" ]]; then
        warden env exec php-fpm rm -rf media/css/*
        echo "✓ Magento media/css cleared"
    fi

    if [[ -d "media/js" ]]; then
        warden env exec php-fpm rm -rf media/js/*
        echo "✓ Magento media/js cleared"
    fi
fi

:: Cache clearing complete
