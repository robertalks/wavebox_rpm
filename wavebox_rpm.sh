#!/bin/sh -e

NAME="$(basename $0)"
CWD="$(pwd)"
TMP_PATH="/tmp/wavebox.$$"
WAVEBOX_VERSION=""

if [ "$(which rpmbuild)" == "" ]; then
	printf "Unable to find rpmbuild, please use yum or zypper to install the package\n" >&2
	exit 1
fi
if [ "$(which curl)" == "" ]; then
	printf "Unable to find curl, please use yum or zypper to install the package\n" >&2
	exit 1
fi

usage() {
	cat << EOF
$NAME: Wavebox RPM package generator tool

Usage: $NAME [OPTIONS]

        -h          Show help
        -a [...]    Set package architecture
                    (default: x86_64, available: x86_64, i386)

Example:
       $NAME -a i386

EOF
}

wavebox_set_version() {
	local app_version=
	local tmp_file="/tmp/.version.$$"

	printf "Retrieving latest Wavebox version from Github ... "
	curl -sk -X GET 'https://api.github.com/repos/wavebox/waveboxapp/releases/latest' -o $tmp_file >/dev/null 2>&1
	app_version=$(sed -n 's/.*\"\(tag_name\)\": \"\(.*\)\"\,/\2/p' $tmp_file 2>/dev/null | sed 's/v//g')
	rm -f $tmp_file >/dev/null 2>&1
	printf "$app_version\n"

	WAVEBOX_VERSION=$app_version
}

wavebox_set_release() {
	local new_version="$1"
	local old_version=""
	local release=""

	if [ -r "${CWD}/.version" ]; then
		old_version="$(cat ${CWD}/.version)"
	else
		echo "$new_version" > ${CWD}/.version
	fi

	if [ -r "${CWD}/.release" ]; then
		release=$(cat ${CWD}/.release)
	else
		release=0
	fi

	if [ "$new_version" == "$old_version" ]; then
		release=$(($release + 1))
	else
		release=0
	fi

	echo "$release" > ${CWD}/.release

	RPM_REVISION=$release
}

while getopts "ha:" opt; do
	case "$opt" in
		h)
			usage
			exit 0
		;;
		a)
			RPM_ARCH="$OPTARG"
		;;
	esac
done

if [ -z "$RPM_ARCH" ]; then
	RPM_ARCH="x86_64"
fi

case "${RPM_ARCH}" in
	i386)
		PACKAGE_ARCH="ia32"
		_ARCH="${PACKAGE_ARCH}"
	;;
	x86_64)
		PACKAGE_ARCH="x86_64"
		_ARCH="x64"
	;;
esac

wavebox_set_version
wavebox_set_release "${WAVEBOX_VERSION}"

if [ "${WAVEBOX_VERSION}" == "" ]; then
	printf "Unable to determine version, something went wrong... \n" >&2
	exit 1
fi

WAVEBOX_PATH="/opt/wavebox"
WAVEBOX_ALT_VERSION="$(echo ${WAVEBOX_VERSION} | sed 's/\./_/g')"
PACKAGE_NAME="Wavebox_${WAVEBOX_ALT_VERSION}_linux_${PACKAGE_ARCH}.tar.gz"
PACKAGE_URL="https://github.com/wavebox/waveboxapp/releases/download/v${WAVEBOX_VERSION}/${PACKAGE_NAME}"
RPM_PACKAGE_NAME="wavebox"
RPM_PACKAGE="${RPM_PACKAGE_NAME}-${WAVEBOX_VERSION}-${RPM_REVISION}.${RPM_ARCH}.rpm"
RPM_BUILD_PATH="${TMP_PATH}/rpmbuild"

mkdir -p ${TMP_PATH}
mkdir -p ${RPM_BUILD_PATH}/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} || exit 1

printf "Downloading ${PACKAGE_NAME}: "
rc=$(curl -skL -X GET "${PACKAGE_URL}" -o "${RPM_BUILD_PATH}/SOURCES/${PACKAGE_NAME}" -w '%{http_code}')
if [ "$rc" -eq 200 ]; then
	printf "done\n"
else
	printf "failed\n"
	exit 1
fi

printf "Generating ${RPM_PACKAGE_NAME}.spec ...\n"
cat << EOF > ${RPM_BUILD_PATH}/SPECS/${RPM_PACKAGE_NAME}.spec
%define           _topdir         ${RPM_BUILD_PATH}
Name:             ${RPM_PACKAGE_NAME}
Version:          ${WAVEBOX_VERSION}
Release:          ${RPM_REVISION}
Summary:          Wavebox is your secure desktop client for the cloud
License:          MPL-2.0
Vendor:           Wavebox
URL:              https://wavebox.io
BugURL:           https://github.com/wavebox/waveboxapp/issues
ExcludeArch:      noarch
Source:           ${PACKAGE_NAME}
Requires(post):   coreutils shared-mime-info desktop-file-utils
Requires(postun): shared-mime-info desktop-file-utils
%if 0%{?suse_version}
Requires:         libXss1
%else
Requires:         libXScrnSaver
%endif
Packager:         Robert Milasan <robert@linux-source.org>

%description
Wavebox is your secure desktop client for the cloud.
Add the apps you use everyday and effortlessly switch between them for an easier, more productive workflow.

%prep
%setup -n Wavebox-linux-${_ARCH}

%build

%install
mkdir -p \$RPM_BUILD_ROOT/${WAVEBOX_PATH}
cp -afR * \$RPM_BUILD_ROOT/${WAVEBOX_PATH}
mkdir -p \$RPM_BUILD_ROOT/usr/bin
ln -sf ${WAVEBOX_PATH}/Wavebox \$RPM_BUILD_ROOT/usr/bin/Wavebox
ln -sf ${WAVEBOX_PATH}/Wavebox \$RPM_BUILD_ROOT/usr/bin/wavebox

mkdir -p \$RPM_BUILD_ROOT/usr/share/applications
install -m 644 wavebox.desktop \$RPM_BUILD_ROOT/usr/share/applications/wavebox.desktop
mkdir -p \$RPM_BUILD_ROOT/usr/share/pixmaps
install -m 644 wavebox_icon.png \$RPM_BUILD_ROOT/usr/share/pixmaps/wavebox.png
mkdir -p \$RPM_BUILD_ROOT/usr/share/icons/hicolor/32x32/apps/
install -m 644 wavebox_icon_32.png \$RPM_BUILD_ROOT/usr/share/icons/hicolor/32x32/apps/wavebox.png
mkdir -p \$RPM_BUILD_ROOT/usr/share/icons/hicolor/48x48/apps/
install -m 644 wavebox_icon_48.png \$RPM_BUILD_ROOT/usr/share/icons/hicolor/48x48/apps/wavebox.png
mkdir -p \$RPM_BUILD_ROOT/usr/share/icons/hicolor/64x64/apps/
install -m 644 wavebox_icon_64.png \$RPM_BUILD_ROOT/usr/share/icons/hicolor/64x64/apps/wavebox.png
mkdir -p \$RPM_BUILD_ROOT/usr/share/icons/hicolor/96x96/apps/
install -m 644 wavebox_icon_96.png \$RPM_BUILD_ROOT/usr/share/icons/hicolor/96x96/apps/wavebox.png
mkdir -p \$RPM_BUILD_ROOT/usr/share/icons/hicolor/128x128/apps/
install -m 644 wavebox_icon_128.png \$RPM_BUILD_ROOT/usr/share/icons/hicolor/128x128/apps/wavebox.png
mkdir -p \$RPM_BUILD_ROOT/usr/share/icons/hicolor/256x256/apps/
install -m 644 wavebox_icon_256.png \$RPM_BUILD_ROOT/usr/share/icons/hicolor/256x256/apps/wavebox.png
mkdir -p \$RPM_BUILD_ROOT/usr/share/icons/hicolor/512x512/apps/
install -m 644 wavebox_icon_512.png \$RPM_BUILD_ROOT/usr/share/icons/hicolor/512x512/apps/wavebox.png

%post
if test -x /usr/bin/update-mime-database; then
  /usr/bin/update-mime-database "/usr/share/mime" || true
fi
if test -x /usr/bin/update-desktop-database; then
  /usr/bin/update-desktop-database --quiet "/usr/share/applications" || true
fi
if test -x /usr/bin/gtk-update-icon-cache; then
  /usr/bin/gtk-update-icon-cache --quiet --force "/usr/share/icons/hicolor" || true
fi
exit 0

%postun
if [ \$1 -eq 0 ]; then
  if test -x /usr/bin/gtk-update-icon-cache; then
    /usr/bin/gtk-update-icon-cache --quiet --force "/usr/share/icons/hicolor" || true
  fi
fi
if [ \$1 -eq 0 ]; then
  if test -x /usr/bin/update-desktop-database; then
    /usr/bin/update-desktop-database --quiet "/usr/share/applications" || true
  fi
fi
if [ \$1 -eq 0 ]; then
  if test -x /usr/bin/update-mime-database; then
    /usr/bin/update-mime-database "/usr/share/mime" || true
  fi
fi
exit 0

%clean
rm -rfv \$RPM_BUILD_ROOT

%files
%defattr(0644, root, root, 0755)
%dir $WAVEBOX_PATH
$WAVEBOX_PATH/*
%attr(755,root,root) $WAVEBOX_PATH/Wavebox
%attr(755,root,root) $WAVEBOX_PATH/libnode.so
%attr(755,root,root) $WAVEBOX_PATH/libffmpeg.so
/usr/bin/Wavebox
/usr/bin/wavebox
/usr/share/applications/wavebox.desktop
/usr/share/pixmaps/wavebox.png
/usr/share/icons/hicolor/32x32/apps/wavebox.png
/usr/share/icons/hicolor/48x48/apps/wavebox.png
/usr/share/icons/hicolor/64x64/apps/wavebox.png
/usr/share/icons/hicolor/96x96/apps/wavebox.png
/usr/share/icons/hicolor/128x128/apps/wavebox.png
/usr/share/icons/hicolor/256x256/apps/wavebox.png
/usr/share/icons/hicolor/512x512/apps/wavebox.png
EOF

printf "Generating RPM package: ${RPM_PACKAGE}\n"
( cd ${RPM_BUILD_PATH}/SPECS
  rpmbuild -bb --quiet --target=${RPM_ARCH} ${RPM_PACKAGE_NAME}.spec 2>/dev/null
)

if [ -r "${RPM_BUILD_PATH}/RPMS/${RPM_ARCH}/${RPM_PACKAGE}" ]; then
	cp -af ${RPM_BUILD_PATH}/RPMS/${RPM_ARCH}/${RPM_PACKAGE} ${CWD}/${RPM_PACKAGE}
  	printf "Package generated: ${CWD}/${RPM_PACKAGE}\n"
else
	printf "Failed to generate RPM package\n" >&2
	exit 1
fi

rm -fr ${TMP_PATH}
