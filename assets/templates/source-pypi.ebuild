# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

DISTUTILS_USE_PEP517=@@BUILD_BACKEND@@
PYTHON_COMPAT=( python3_{11..14} )

# The pypi eclass derives SRC_URI from ${PN}/${PV} automatically — do NOT
# declare SRC_URI manually below. If the PyPI project name differs from ${PN}:
#   - set PYPI_PN="ProjectName" before `inherit` to override the project name, or
#   - set PYPI_NO_NORMALIZE=1 to keep the original (non-normalized) name casing.
inherit distutils-r1 pypi

DESCRIPTION="@@DESCRIPTION@@"
HOMEPAGE="@@HOMEPAGE@@"

LICENSE="@@LICENSE@@"
SLOT="@@SLOT@@"
KEYWORDS="@@KEYWORDS@@"

RDEPEND="@@RDEPEND@@"

# distutils_enable_tests adds the `test` USE flag, RESTRICT and the pytest
# dependency automatically — do not redeclare them. For extra test-only deps
# beyond pytest, add: BDEPEND="test? ( @@TEST_DEPS@@ )" below this call.
distutils_enable_tests pytest
