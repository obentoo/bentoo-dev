# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop pax-utils unpacker xdg

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"
SRC_URI="
	amd64? ( @@DEB_URL_AMD64@@ -> ${P}-amd64.deb )
	arm64? ( @@DEB_URL_ARM64@@ -> ${P}-arm64.deb )
"
S="${WORKDIR}"

LICENSE="@@LICENSE@@"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
IUSE="@@IUSE@@"
RESTRICT="bindist mirror strip"

RDEPEND="
	@@RDEPEND@@
"

QA_PREBUILT="*"

src_install() {
	# Install application to /opt
	dodir /opt/@@PKG_NAME@@
	cp -ar usr/share/@@PKG_NAME@@/. "${D}/opt/@@PKG_NAME@@/" || die

	# Sandbox and PaX
	fperms 4711 /opt/@@PKG_NAME@@/chrome-sandbox
	pax-mark m /opt/@@PKG_NAME@@/@@BINARY@@

	# Symlink binary
	dosym ../@@PKG_NAME@@/bin/@@BINARY@@ /opt/bin/@@BINARY@@

	# Desktop integration
	domenu usr/share/applications/@@PKG_NAME@@.desktop
	local size
	for size in 16 24 32 48 64 128 256 512; do
		newicon -s "${size}" usr/share/pixmaps/@@ICON_FILE@@ @@PKG_NAME@@.png
	done
}

pkg_postinst() {
	xdg_pkg_postinst
}
