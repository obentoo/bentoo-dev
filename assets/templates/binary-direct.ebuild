# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"
SRC_URI="
	amd64? ( @@BINARY_URL_AMD64@@ -> @@BINARY_NAME@@-amd64-${PV} )
	arm64? ( @@BINARY_URL_ARM64@@ -> @@BINARY_NAME@@-arm64-${PV} )
"
S="${WORKDIR}"

LICENSE="@@LICENSE@@"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
RESTRICT="bindist mirror strip"

QA_PREBUILT="opt/bin/@@BINARY_NAME@@"

RDEPEND="@@RDEPEND@@"

src_compile() {
	:
}

src_install() {
	exeinto /opt/bin
	newexe "${DISTDIR}/${A[0]}" @@BINARY_NAME@@
}
