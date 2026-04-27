# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
GST_ORG_MODULE=@@GST_MODULE@@

inherit gstreamer-meson

DESCRIPTION="@@DESCRIPTION@@"
KEYWORDS="~amd64 ~arm ~arm64"
IUSE="+orc"

RDEPEND="
	@@RDEPEND@@
	orc? ( >=dev-lang/orc-0.4.33[${MULTILIB_USEDEP}] )
"
DEPEND="${RDEPEND}"

multilib_src_configure() {
	local emesonargs=(
		@@MESON_ARGS@@
	)
	gstreamer_multilib_src_configure
}
