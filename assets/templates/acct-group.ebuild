# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

# The acct-group eclass creates a system group at install time (replacing the
# legacy enewgroup call). It provides SLOT="0" handling and the pkg_* phases.
inherit acct-group

DESCRIPTION="@@DESCRIPTION@@"

SLOT="0"
KEYWORDS="@@KEYWORDS@@"

# GID must be unique across all acct-group packages in the tree/overlay.
ACCT_GROUP_ID=@@GID@@
