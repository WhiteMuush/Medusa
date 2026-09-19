# tests/test_helper.bash - shared bootstrap for the bats test suite.
#
# Every *.bats file loads this file. It resolves the repository root and
# exposes load_libs(), which sources the source-only libraries into the test
# shell without ever launching the interactive menu or a real Docker command.

MEDUSA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
export MEDUSA_ROOT
export MEDUSA_HOME="${MEDUSA_ROOT}"

# A predictable terminal so helpers that call tput do not error out on CI
# runners where TERM is unset.
export TERM="${TERM:-xterm}"

# Source core into the test shell. The load guard makes repeated calls safe.
load_libs() {
    # shellcheck source=../lib/core.sh
    source "${MEDUSA_ROOT}/lib/core.sh"
}
