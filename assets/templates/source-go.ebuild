# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

inherit go-module

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="@@GIT_URI@@"
else
	# EGO_SUM is deprecated (go-module emits a fatal QA notice). Ship a vendor
	# dependency tarball instead: generate it upstream-side with
	#   go mod vendor && tar caf ${P}-deps.tar.xz vendor
	# (or use a GitHub-archive deps tarball), host it, and list it here.
	SRC_URI="
		@@SRC_URI@@
		@@DEPS_TARBALL_URI@@
	"
	KEYWORDS="@@KEYWORDS@@"
	S="${WORKDIR}/@@SOURCE_DIR@@"
fi

LICENSE="@@LICENSE@@"
# Dependent (vendored) module licenses
LICENSE+=" @@MODULE_LICENSES@@"
SLOT="@@SLOT@@"

RDEPEND="@@RDEPEND@@"

src_compile() {
	# Honour Gentoo LDFLAGS via the external linker. Drop -linkmode=external
	# for pure-Go packages built with CGO_ENABLED=0.
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
