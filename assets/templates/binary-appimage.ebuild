# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

inherit desktop xdg

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"
SRC_URI="@@APPIMAGE_URL@@ -> ${P}.AppImage"

# AppImages extract to ${WORKDIR}/squashfs-root. Set S globally so the package
# manager runs src_install from there (a local S= inside src_unpack has no
# effect — the PM has already captured S by then).
S="${WORKDIR}/squashfs-root"

LICENSE="@@LICENSE@@"
SLOT="0"
KEYWORDS="-* @@KEYWORDS@@"
RESTRICT="bindist mirror strip"

QA_PREBUILT="*"

RDEPEND="
	@@RDEPEND@@
"

src_unpack() {
	cp "${DISTDIR}/${P}.AppImage" "${WORKDIR}/" || die
	chmod +x "${WORKDIR}/${P}.AppImage" || die
	cd "${WORKDIR}" || die
	"./${P}.AppImage" --appimage-extract || die
}

src_install() {
	# Install the extracted AppImage tree (squashfs-root) under /opt.
	dodir /opt/@@PKG_NAME@@
	cp -a "${S}/." "${D}/opt/@@PKG_NAME@@/" || die

	# AppImages expose an AppRun entrypoint; symlink the real binary if known,
	# otherwise fall back to AppRun. Adjust @@BINARY@@ to the actual executable.
	dosym ../@@PKG_NAME@@/@@BINARY@@ /opt/bin/@@BINARY@@

	# Desktop integration (the .desktop and icon live inside squashfs-root).
	# domenu @@PKG_NAME@@.desktop
	# newicon @@ICON_FILE@@ @@PKG_NAME@@.png
}
