#!/bin/bash

get_candidate_repo() {
	local -r minor="${1}"
	local -r dev_prev="${2}"
	local dev_prev_suffix="-dev-preview"
	if ! ${dev_prev}; then
		dev_prev_suffix=""
	fi

	echo "https://mirror.openshift.com/pub/openshift-v4/${UNAME_M}/microshift/ocp${dev_prev_suffix}/latest-4.${minor}/el9/os"
}

check_if_repo_exists() {
	local -r repo="${1}"
	code=$(curl --silent --location --output /dev/null --write-out "%{http_code}" "${repo}/repodata/repomd.xml")
	if [ "${code}" == "404" ]; then
		return 1
	else
		return 0
	fi
}

get_current_release_from_candidates() {
	local -r minor="${1}"

	rc_repo=$(get_candidate_repo "${minor}" false)
	if check_if_repo_exists "${rc_repo}"; then
		echo "${rc_repo}"
		return 0
	fi

	ec_repo=$(get_candidate_repo "${minor}" true)
	if check_if_repo_exists "${ec_repo}"; then
		echo "${ec_repo}"
		return 0
	fi

	echo ""
}

dnf_repo_is_enabled() {
	local -r rhsm_repo="${1}"
	sudo dnf repolist | grep -q "${rhsm_repo}"
}

get_current_release_from_sub_repos() {
	local -r minor="${1}"
	local -r rhsm_repo="rhocp-4.${minor}-for-rhel-9-x86_64-rpms"

	if dnf_repo_is_enabled "${rhsm_repo}"; then
		newest=$(sudo dnf repoquery microshift --quiet --queryformat '%{version}-%{release}' --repo "${rhsm_repo}" | sort --version-sort | tail -n1)
		if [ -n "${newest}" ]; then
			echo "${newest}"
			return
		fi
	fi
	echo ""
}

# get_crel_version_repo attempts to obtain full version string and repository url
# for "already released RPMs for current release" - this includes ECs and RCs from
# http mirrors, and packages in the ocp repository.
#
# Failed attempt to obtain version/repo is not a failure, at the start of each release,
# there might not be an EC yet. In such case variables exported below might be empty,
# and such osbuild source, blueprint, and test scenarios should be skipped.
get_crel_version_repo() {
	local -r minor="${1}"

	CURRENT_RELEASE_VERSION=$(get_current_release_from_sub_repos "${minor}")
	if [ -n "${CURRENT_RELEASE_VERSION}" ]; then
		export CURRENT_RELEASE_VERSION
		return
	fi

	CURRENT_RELEASE_REPO=$(get_current_release_from_candidates "${minor}")
	if [ -z "${CURRENT_RELEASE_REPO}" ]; then
		return
	fi
	export CURRENT_RELEASE_REPO

	CURRENT_RELEASE_VERSION=$(sudo dnf repoquery microshift --quiet --queryformat '%{version}-%{release}' --disablerepo '*' --repofrompath "this,${CURRENT_RELEASE_REPO}")
	if [ -n "${CURRENT_RELEASE_VERSION}" ]; then
		export CURRENT_RELEASE_VERSION
	fi
}
