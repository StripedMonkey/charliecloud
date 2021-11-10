true
# shellcheck disable=SC2034
CH_TEST_TAG=$ch_test_tag

load "${CHTEST_DIR}/common.bash"

setup() {
    scope full
    [[ -z $ch_cray ]] || skip 'issue #193 and Spack issue #8618'
    prerequisites_ok spack
    export PATH=/spack/bin:$PATH
}

@test "${ch_tag}/version" {
    ch-run "$ch_img" -- spack --version
}

@test "${ch_tag}/compilers" {
    echo "spack compiler list"
    ch-run "$ch_img" -- spack compiler list
    echo "spack compiler list --scope=system"
    ch-run "$ch_img" -- spack compiler list --scope=system
    echo "spack compiler list --scope=user"
    ch-run "$ch_img" -- spack compiler list --scope=user
    echo "spack compilers"
    ch-run "$ch_img" -- spack compilers
}

@test "${ch_tag}/spec" {
    ch-run "$ch_img" -- spack spec hdf5
}

@test "${ch_tag}/install chariecloud" {
    ch-run "$ch_img" -- spack install charliecloud+docs^py-sphinx-rtd-theme@0.4.3
    ch-run "$ch_img" -- spack clean --all
}
