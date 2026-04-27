# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=@@BUILD_BACKEND@@
PYTHON_COMPAT=( python3_{11..14} )

inherit distutils-r1

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"
SRC_URI="@@SRC_URI@@"

LICENSE="@@LICENSE@@"
SLOT="@@SLOT@@"
KEYWORDS="~amd64"

RDEPEND="@@RDEPEND@@"
BDEPEND="
	test? ( @@TEST_DEPS@@ )
"

distutils_enable_tests pytest
