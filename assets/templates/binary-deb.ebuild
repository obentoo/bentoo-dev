# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

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
KEYWORDS="-* @@KEYWORDS@@"
IUSE="@@IUSE@@"
RESTRICT="bindist mirror strip"

RDEPEND="
	@@RDEPEND@@
"

QA_PREBUILT="*"

src_install() {
	# Install application payload to /opt. Adjust the source path to wherever
	# the .deb stages the app (commonly usr/share/<pkg> or usr/lib/<pkg>).
	dodir /opt/@@PKG_NAME@@
	cp -ar usr/share/@@PKG_NAME@@/. "${D}/opt/@@PKG_NAME@@/" || die

	# --- Electron/Chromium apps only -------------------------------------
	# Chromium-based apps ship a setuid chrome-sandbox helper and need a PaX
	# MPROTECT exception. Uncomment for Electron/Chromium payloads; leave
	# commented for ordinary .deb packages (fperms dies if the file is absent).
	# fperms 4711 /opt/@@PKG_NAME@@/chrome-sandbox
	# pax-mark m /opt/@@PKG_NAME@@/@@BINARY@@
	# ---------------------------------------------------------------------

	# Symlink binary (adjust the in-package path to the real executable).
	dosym ../@@PKG_NAME@@/@@BINARY@@ /opt/bin/@@BINARY@@

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
