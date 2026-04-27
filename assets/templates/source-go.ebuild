# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="@@GIT_URI@@"
else
	SRC_URI="@@SRC_URI@@"
	KEYWORDS="~amd64"
	S="${WORKDIR}/@@SOURCE_DIR@@"
fi

LICENSE="@@LICENSE@@"
# Dependent licenses
LICENSE+=" @@MODULE_LICENSES@@"
SLOT="@@SLOT@@"

RDEPEND="@@RDEPEND@@"

src_compile() {
	local go_ldflags=(
		"-linkmode=external"
		-X "@@VERSION_PKG@@.Version=${PV}"
		-X "@@VERSION_PKG@@.Revision=gentoo"
	)
	ego build -o @@BINARY@@ -ldflags "${go_ldflags[*]}" @@BUILD_TARGET@@
}

src_install() {
	dobin @@BINARY@@
	einstalldocs
}
