# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
@@CRATES_LIST@@
"

RUST_MIN_VER="@@RUST_MIN_VER@@"

inherit cargo

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"

if [[ ${PV} == *9999* ]]; then
	EGIT_REPO_URI="@@GIT_URI@@"
	inherit git-r3
else
	SRC_URI="@@SRC_URI@@
		${CARGO_CRATE_URIS}
	"
	KEYWORDS="~amd64"
fi

# License for the package itself + dependent crates
LICENSE="@@LICENSE@@"
# Dependent licenses (generate with cargo-license)
LICENSE+=" @@CRATE_LICENSES@@"
SLOT="@@SLOT@@"
IUSE="@@IUSE@@"

DEPEND="@@DEPEND@@"
RDEPEND="${DEPEND}"
BDEPEND="
	virtual/pkgconfig
"

# QA_FLAGS_IGNORED="usr/bin/@@BINARY@@"

src_compile() {
	cargo_src_compile
}

src_install() {
	dobin target/release/@@BINARY@@
	einstalldocs
}
