# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

# MY_PN=@@UPSTREAM_NAME@@  # Uncomment if upstream name differs
inherit meson

if [[ ${PV} == *9999* ]]; then
	EGIT_REPO_URI="@@GIT_URI@@"
	inherit git-r3
else
	GIT_COMMIT="@@COMMIT@@"
	SRC_URI="@@SRC_URI_BASE@@/archive/${GIT_COMMIT}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="@@KEYWORDS@@"
	S="${WORKDIR}/@@SOURCE_DIR@@"
fi

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"

LICENSE="@@LICENSE@@"
SLOT="@@SLOT@@"
IUSE="test"
RESTRICT="!test? ( test )"

DEPEND="@@DEPEND@@"
RDEPEND="${DEPEND}"
BDEPEND="
	virtual/pkgconfig
"

src_configure() {
	local emesonargs=(
		$(meson_feature test tests)
	)
	meson_src_configure
}
