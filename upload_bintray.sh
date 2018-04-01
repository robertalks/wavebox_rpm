#!/bin/sh -e

NAME="$(basename $0)"
CWD="$(pwd)"
BINTRAY_API="https://api.bintray.com"
APIKEY=""

usage() {
	cat << EOF
${NAME}: upload rpm package to Bintray

Usage: ${NAME} [OPTIONS]

        -h          Show help
        -f [...]    Set package to upload
                    (default: none, requires to be set)
        -r [...]    Set repository to upload to
                    (default: none, requires to be set)
        -u [...]    Set Bintray username
                    (default: none, requires to be set)

Example:
       ${NAME} -f mynewapp-1.0.x86_64.rpm -r myrepo -u myaccount

EOF
}

while getopts "hf:r:u:" opt; do
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
		u)
			USER="${OPTARG}"
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

if [ -z "${USER}" ]; then
	usage
	printf "${NAME}: username not specified, required when uploading to Bintray.\n" >&2
	exit 1
fi

if [ -r "${CWD}/.bintray-auth" ]; then
	APIKEY="$(cat ${CWD}/.bintray-auth)"
else
	printf "${NAME}: ${CWD}/.bintray-auth not found. Please use bintray.com to generate an API key.\n"
	printf "Create a file ${CWD}/.bintray-auth and add the API key from bintray.com to the file\n"
	exit 1
fi

RPM_NAME="$(rpm --queryformat "%{NAME}" -qp ${RPM_PACKAGE})"
RPM_VERSION="$(rpm --queryformat "%{VERSION}" -qp ${RPM_PACKAGE})"
RPM_RELEASE="$(rpm --queryformat "%{RELEASE}" -qp ${RPM_PACKAGE})"
RPM_ARCH="$(rpm --queryformat "%{ARCH}" -qp ${RPM_PACKAGE})"
RPM_URL="$(rpm --queryformat "%{URL}" -qp ${RPM_PACKAGE})"
RPM_SUMMARY="$(rpm --queryformat "%{SUMMARY}" -qp ${RPM_PACKAGE})"
RPM_LICENSE="$(rpm --queryformat "%{LICENSE}" -qp ${RPM_PACKAGE})"
RPM_BUGURL="$(rpm --queryformat "%{BUGURL}" -qp ${RPM_PACKAGE})"
RPM_BASENAME="$(basename ${RPM_PACKAGE})"

printf "Package name: ${RPM_NAME}\n"
printf "Package version: ${RPM_VERSION}\n"
printf "Package release: ${RPM_RELEASE}\n"
printf "Package arch: ${RPM_ARCH}\n"

printf "Checking if package ${RPM_NAME} exists... "
rc=$(curl -sk --connect-timeout 30 -m 60 -u "${USER}:${APIKEY}" -H "Content-Type:application/json" -H "Accept:application/json" \
-X GET "${BINTRAY_API}/packages/${USER}/${REPO}/${RPM_NAME}" -w '%{http_code}' -o /dev/null)
if [ $rc -eq 404 -a $rc -ne 200 ]; then
	printf "not found\n"
	jsonTmp="/tmp/.json.$$"
cat << EOF > ${jsonTmp}
{
"name": "${RPM_NAME}",
"desc": "${RPM_SUMMARY}",
"desc_url": "${RPM_URL}",
"labels": ["rpm", "${RPM_NAME}", "yum", "zypper"],
"licenses": ["${RPM_LICENSE}"],
"vcs_url": "${RPM_BUGURL}"
}
EOF
	printf "Creating package ${RPM_NAME}... "
	rc=$(curl -sk --connect-timeout 30 -m 60 -u "${USER}:${APIKEY}" -H "Content-Type:application/json" -H "Accept:application/json" \
-X POST -d "@${jsonTmp}" "${BINTRAY_API}/packages/${USER}/${REPO}" -w '%{http_code}' -o /dev/null)
	rm -f ${jsonTmp} >/dev/null 2>&1
	if [ $rc -eq 201 ]; then
		printf "done\n"
	else
		printf "failed\n"
		exit 1
	fi
elif [ $rc -eq 200 ]; then
	printf "found\n"
else
	printf "failed\n"
	exit 1
fi

printf "Uploading ${RPM_BASENAME} rpm package to Bintray... "
rc=$(curl --connect-timeout 30 -m 60 -sk -u "${USER}:${APIKEY}" -T "${RPM_PACKAGE}" -X PUT \
-H "X-Bintray-Package:${RPM_NAME}" -H "X-Bintray-Version:${RPM_VERSION}-${RPM_RELEASE}" \
"${BINTRAY_API}/content/${USER}/${REPO}/${RPM_BASENAME}" -w '%{http_code}' -o /dev/null)

if [ $rc -eq 201 ]; then
	printf "done\n"
else
	printf "failed\n"
	exit 1
fi

printf "Publishing ${RPM_BASENAME} rpm package to Bintray... "
rc=$(curl -sk --connect-timeout 30 -m 60 -u "${USER}:${APIKEY}" -X POST -H "Content-Type:application/json" -H "Accept:application/json" \
${BINTRAY_API}/content/${USER}/${REPO}/${RPM_NAME}/${RPM_VERSION}-${RPM_RELEASE}/publish -d "{ \"discard\": \"false\" }" -w '%{http_code}' -o /dev/null)

if [ $rc -eq 200 ]; then
	printf "done\n"
else
	printf "failed\n"
	exit 1
fi
