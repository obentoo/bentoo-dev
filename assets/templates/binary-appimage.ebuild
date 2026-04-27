# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"
SRC_URI="@@APPIMAGE_URL@@ -> ${P}.AppImage"
S="${WORKDIR}"

LICENSE="@@LICENSE@@"
SLOT="0"
KEYWORDS="-* ~amd64"
RESTRICT="bindist mirror strip"

QA_PREBUILT="*"

RDEPEND="
	sys-libs/zlib
	x11-libs/libX11
"

src_unpack() {
	cp "${DISTDIR}/${P}.AppImage" "${WORKDIR}/" || die
	chmod +x "${P}.AppImage" || die
	"./${P}.AppImage" --appimage-extract || die
	S="${WORKDIR}/squashfs-root"
}

src_install() {
	dodir /opt/@@PKG_NAME@@
	cp -ar . "${D}/opt/@@PKG_NAME@@/" || die

	dosym ../@@PKG_NAME@@/@@BINARY@@ /opt/bin/@@BINARY@@

	# Desktop integration (adapt icon/desktop paths from AppImage contents)
	# domenu @@PKG_NAME@@.desktop
	# newicon @@ICON_FILE@@ @@PKG_NAME@@.png
}
