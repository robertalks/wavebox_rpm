#!/bin/sh -e

NAME="$(basename $0)"
BINTRAY_API="https://api.bintray.com"

usage() {
	cat << EOF
${NAME}: upload rpm package to Bintray

Usage: ${NAME} [OPTIONS]

        -h          Show help
        -f [...]    Set package to upload
                    (default: none, requires to be set)
        -r [...]    Set repository to upload to
                    (default: none, requires to be set)
        -p [...]    Set Bintray project aka package
                    (default: none, requires to be set)
        -u [...]    Set Bintray username
                    (default: none, requires to be set)
        -k [...]    Set Bintray API key
                    (default: none, requires to be set)

Example:
       ${NAME} -p mynewapp-1.0.x86_64.rpm -r myrepo -u myaccount -k myapikey

EOF
}

while getopts "hf:r:p:u:k:" opt; do
	case "$opt" in
		h)
			usage
			exit 0
		;;
		f)
			RPM_PACKAGE="${OPTARG}"
		;;
		r)
			REPO="${OPTARG}"
		;;
		p)
			PROJECT="${OPTARG}"
		;;
		u)
			USER="${OPTARG}"
		;;
		k)
			APIKEY="${OPTARG}"
		;;
	esac
done

if [ -z "${RPM_PACKAGE}" ]; then
	usage
	printf "${NAME}: package must be specified.\n" >&2
	exit 1
fi

if [ ! -r "${RPM_PACKAGE}" ]; then
	usage
	printf "${NAME}: given package not found.\n" >&2
	exit 1
fi

if [ -z "${REPO}" ]; then
	usage
	printf "${NAME}: repository where to upload file most be specified.\n" >&2
	exit 1
fi

if [ -z "${PROJECT}" ]; then
	usage
	printf "${NAME}: Bintray project must be specified.\n" >&2
	exit 1
fi

if [ -z "${USER}" ]; then
	usage
	printf "${NAME}: username not specified, required when uploading to Bintray.\n" >&2
	exit 1
fi

if [ -z "${APIKEY}" ]; then
	usage
	printf "${NAME}: API key not specfied, required when uploading to Bintray.\n" >&2
	exit 1
fi

RPM_NAME="$(rpm --queryformat "%{NAME}" -qp ${RPM_PACKAGE})"
RPM_VERSION="$(rpm --queryformat "%{VERSION}" -qp ${RPM_PACKAGE})"
RPM_RELEASE="$(rpm --queryformat "%{RELEASE}" -qp ${RPM_PACKAGE})"
RPM_ARCH="$(rpm --queryformat "%{ARCH}" -qp ${RPM_PACKAGE})"
RPM_BASENAME="$(basename ${RPM_PACKAGE})"

printf "Bintray package: ${PROJECT}\n"
printf "Package name: ${RPM_NAME}\n"
printf "Package version: ${RPM_VERSION}-${RPM_RELEASE}\n"
printf "Package arch: ${RPM_ARCH}\n"

printf "Uploading ${RPM_BASENAME} rpm package to Bintray... "
rc=$(curl -sk -u "${USER}:${APIKEY}" -T "${RPM_PACKAGE}" -X PUT -H "X-Bintray-Package:${RPM_NAME}" -H "X-Bintray-Version:${RPM_VERSION}-${RPM_RELEASE}" \
"${BINTRAY_API}/content/${USER}/${REPO}/${RPM_BASENAME}" -w '%{http_code}' -o /dev/null)

if [ $rc -eq 201 ]; then
	printf "done\n"
else
	printf "failed\n"
fi

printf "Publishing ${RPM_BASENAME} rpm package to Bintray... "
rc=$(curl -sk -u "${USER}:${APIKEY}" -X POST -H "Content-Type:application/json" -H "Accept:application/json" \
${BINTRAY_API}/content/${USER}/${REPO}/${PROJECT}/${RPM_VERSION}-${RPM_RELEASE}/publish -d "{ \"discard\": \"false\" }" -w '%{http_code}' -o /dev/null)

if [ $rc -eq 200 ]; then
	printf "done\n"
else
	printf "failed\n"
fi
