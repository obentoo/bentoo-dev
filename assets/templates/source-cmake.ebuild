# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# MY_PN=@@UPSTREAM_NAME@@  # Uncomment if upstream name differs
inherit cmake

if [[ ${PV} == *9999* ]]; then
	EGIT_REPO_URI="@@GIT_URI@@"
	inherit git-r3
else
	EGIT_COMMIT="@@COMMIT@@"
	SRC_URI="@@SRC_URI_BASE@@/archive/${EGIT_COMMIT}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
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
BDEPEND="@@BDEPEND@@"

src_configure() {
	local mycmakeargs=(
		-DBUILD_TESTING=$(usex test)
	)
	cmake_src_configure
}
