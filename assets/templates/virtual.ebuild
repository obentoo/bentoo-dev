# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

# Virtuals carry no upstream sources: they have no SRC_URI and no LICENSE.
# They only express a dependency choice between interchangeable providers.
DESCRIPTION="Virtual for @@WHAT@@"
HOMEPAGE=""

SLOT="0"
KEYWORDS="@@KEYWORDS@@"

# List the interchangeable providers; the first satisfied one wins.
RDEPEND="|| ( @@PROVIDER_ATOMS@@ )"
