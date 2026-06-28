# Copyright 1999-@@YEAR@@ Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=@@EAPI@@

# The acct-user eclass creates a system user at install time (replacing the
# legacy enewuser call). It provides SLOT="0" handling and the pkg_* phases.
inherit acct-user

DESCRIPTION="@@DESCRIPTION@@"

SLOT="0"
KEYWORDS="@@KEYWORDS@@"

# UID must be unique across all acct-user packages in the tree/overlay.
ACCT_USER_ID=@@UID@@
# Supplementary groups the user joins (bash array). The primary group is the
# matching acct-group/<name> package, pulled in automatically.
ACCT_USER_GROUPS=( @@GROUPS@@ )
# Home defaults to /dev/null when unset; set explicitly only if a real home
# directory is required by the service.
ACCT_USER_HOME=@@HOME@@
# Login shell — system accounts should not be loginable.
ACCT_USER_SHELL=/sbin/nologin

# Must be called AFTER the ACCT_USER_GROUPS/HOME variables are set; it generates
# the dependencies on the corresponding acct-group/* packages.
acct-user_add_deps
