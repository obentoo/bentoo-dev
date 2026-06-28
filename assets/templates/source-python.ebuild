# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

DISTUTILS_USE_PEP517=@@BUILD_BACKEND@@
PYTHON_COMPAT=( python3_{11..14} )

inherit distutils-r1

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"
SRC_URI="@@SRC_URI@@"

LICENSE="@@LICENSE@@"
SLOT="@@SLOT@@"
KEYWORDS="@@KEYWORDS@@"

RDEPEND="@@RDEPEND@@"

# distutils_enable_tests adds the `test` USE flag, RESTRICT and the pytest
# dependency automatically — do not redeclare them. For extra test-only deps
# beyond pytest, add: BDEPEND="test? ( @@TEST_DEPS@@ )" below this call.
distutils_enable_tests pytest
