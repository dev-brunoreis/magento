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
WARDEN_WEB_ROOT="$(echo "${WARDEN_WEB_ROOT:-/}" | sed 's#^/#./#')"
REQUIRED_FILES=("${WARDEN_WEB_ROOT}/composer.json")
CLEAN_INSTALL=
AUTO_PULL=1
SKIP_INSTALL=
ADMIN_USER="admin"
ADMIN_PASS="admin1234@admin"
ADMIN_EMAIL="admin@example.com"
STORE_NAME="Magento"
LOCALE="pt_BR"
TIMEZONE="America/Sao_Paulo"
CURRENCY="BRL"
URL_FRONT="https://${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}/"
URL_ADMIN="https://${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}/admin/"

## argument parsing
while (( "$#" )); do
    case "$1" in
        --clean-install)
            CLEAN_INSTALL=1
            shift
            ;;
        --skip-install)
            SKIP_INSTALL=1
            shift
            ;;
        --admin-user)
            shift
            ADMIN_USER="$1"
            shift
            ;;
        --admin-pass)
            shift
            ADMIN_PASS="$1"
            shift
            ;;
        --admin-email)
            shift
            ADMIN_EMAIL="$1"
            shift
            ;;
        --store-name)
            shift
            STORE_NAME="$1"
            shift
            ;;
        --locale)
            shift
            LOCALE="$1"
            shift
            ;;
        --timezone)
            shift
            TIMEZONE="$1"
            shift
            ;;
        --currency)
            shift
            CURRENCY="$1"
            shift
            ;;
        --no-pull)
            AUTO_PULL=
            shift
            ;;
        *)
            error "Unrecognized argument '$1'"
            exit -1
            ;;
    esac
done

## auto-generate admin password if not provided
if [[ -z "${ADMIN_PASS}" ]]; then
    ADMIN_PASS=$(openssl rand -base64 12)
fi

:: Verifying configuration
INIT_ERROR=

## attempt to install mutagen if not already present
if [[ $OSTYPE =~ ^darwin ]] && ! which mutagen 2>/dev/null >/dev/null && which brew 2>/dev/null >/dev/null; then
    warning "Mutagen could not be found; attempting install via brew."
    brew install havoc-io/mutagen/mutagen
fi

## check for presence of host machine dependencies
for DEP_NAME in warden docker-compose; do
  if ! which "${DEP_NAME}" 2>/dev/null >/dev/null; then
    error "Command '${DEP_NAME}' not found. Please install."
    INIT_ERROR=1
  fi
done

## verify warden version constraint
WARDEN_VERSION=$(warden version 2>/dev/null) || true
WARDEN_REQUIRE=0.6.0
if ! test $(version ${WARDEN_VERSION}) -ge $(version ${WARDEN_REQUIRE}); then
  error "Warden ${WARDEN_REQUIRE} or greater is required (version ${WARDEN_VERSION} is installed)"
  INIT_ERROR=1
fi

## check for presence of local configuration files to ensure they exist
for REQUIRED_FILE in ${REQUIRED_FILES[@]}; do
  if [[ ! -f "${REQUIRED_FILE}" ]]; then
    error "Missing local file: ${REQUIRED_FILE}"
    INIT_ERROR=1
  fi
done

## exit script if there are any missing dependencies or configuration files
[[ ${INIT_ERROR} ]] && exit 1

:: Starting Warden
warden svc up
if [[ ! -f ~/.warden/ssl/certs/${TRAEFIK_DOMAIN}.crt.pem ]]; then
    warden sign-certificate ${TRAEFIK_DOMAIN}
fi

:: Initializing environment
if [[ $AUTO_PULL ]]; then
  warden env pull --ignore-pull-failures || true
  warden env build --pull
else
  warden env build
fi
warden env up -d

## wait for mariadb to start listening for connections
warden shell -c "while ! nc -z db 3306 </dev/null; do sleep 2; done"

:: Installing dependencies
warden env exec -T php-fpm composer install

## Run OpenMage installation if not skipped
if [[ ! ${SKIP_INSTALL} ]]; then
  if [[ ${CLEAN_INSTALL} ]] || [[ ! -f "${WARDEN_WEB_ROOT}/app/etc/env.php" ]]; then
    :: Installing OpenMage using Console Installer

    # Remove existing configuration files to ensure a fresh install
    if [[ -f "${WARDEN_WEB_ROOT}/app/etc/local.xml" ]]; then
        rm "${WARDEN_WEB_ROOT}/app/etc/local.xml"
    fi

    if [[ ! -f "${WARDEN_WEB_ROOT}/app/etc/local.xml.template" ]]; then
        cp "${WARDEN_WEB_ROOT}/vendor/openmage/magento-lts/app/etc/local.xml.template" "${WARDEN_WEB_ROOT}/app/etc/local.xml.template"
    fi
    :: Droping and recreating database
    warden db connect -e 'drop database if exists magento; create database magento;'
    :: Installing OpenMage
    warden env exec -T php-fpm php "${WARDEN_WEB_ROOT}/install.php" -- \
        --license_agreement_accepted yes \
        --locale "${LOCALE}" \
        --timezone "${TIMEZONE}" \
        --default_currency "${CURRENCY}" \
        --db_host db \
        --db_name magento \
        --db_user magento \
        --db_pass magento \
        --db_prefix "" \
        --url "${URL_FRONT}" \
        --use_rewrites yes \
        --use_secure yes \
        --secure_base_url "${URL_FRONT}" \
        --use_secure_admin yes \
        --admin_lastname Admin \
        --admin_firstname Store \
        --admin_email "${ADMIN_EMAIL}" \
        --admin_username "${ADMIN_USER}" \
        --admin_password "${ADMIN_PASS}" \
        --skip_url_validation yes
  fi
fi

:: Initialization complete
function print_install_info {
    FILL=$(printf "%0.s-" {1..128})
    C1_LEN=12
    let "C2_LEN=${#URL_ADMIN}>${#ADMIN_PASS}?${#URL_ADMIN}:${#ADMIN_PASS}"

    # note: in CentOS bash .* isn't supported (is on Darwin), but *.* is more cross-platform
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN "Frontend URL" $C2_LEN "$URL_FRONT"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN "Admin URL" $C2_LEN "$URL_ADMIN"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN "Admin User" $C2_LEN "$ADMIN_USER"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN "Admin Pass" $C2_LEN "$ADMIN_PASS"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
}
print_install_info
