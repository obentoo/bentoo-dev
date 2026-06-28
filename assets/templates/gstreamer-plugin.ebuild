# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

# The official gstreamer.eclass builds split GStreamer plugins (meson-based in
# current versions) and derives HOMEPAGE, SRC_URI, LICENSE, SLOT and IUSE from
# GST_ORG_MODULE. It provides multilib_src_configure automatically.
#
# NOTE: some overlays ship a custom `gstreamer-meson` eclass instead. If the
# detected overlay has eclass/gstreamer-meson.eclass, swap the inherit below to
# `gstreamer-meson` and use gstreamer_multilib_src_configure.
GST_ORG_MODULE=@@GST_MODULE@@

inherit gstreamer

DESCRIPTION="@@DESCRIPTION@@"
KEYWORDS="@@KEYWORDS@@"
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
