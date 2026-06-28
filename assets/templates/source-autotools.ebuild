# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"
SRC_URI="@@SRC_URI@@"

LICENSE="@@LICENSE@@"
SLOT="@@SLOT@@"
KEYWORDS="@@KEYWORDS@@"
IUSE="@@IUSE@@"

DEPEND="@@DEPEND@@"
RDEPEND="${DEPEND}"
BDEPEND="@@BDEPEND@@"

src_configure() {
	local myeconfargs=(
		# $(use_enable feature)
		# $(use_with lib)
	)
	econf "${myeconfargs[@]}"
}

src_install() {
	default
	# Remove static libraries if not needed
	# find "${ED}" -name '*.la' -delete || die
}
