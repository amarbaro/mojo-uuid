# Sourced by the other scripts, from the repository root: sets MOJO, HASHLIB_SRC and PYTHON.
# mojo-hashlib comes from a sibling checkout, else a pinned clone under .work/deps.
if [ -z "${MOJO:-}" ]; then
  if [ -x .venv/bin/mojo ]; then MOJO=.venv/bin/mojo; else MOJO=mojo; fi
fi
if [ -z "${HASHLIB_SRC:-}" ]; then
  if [ -d ../mojo-hashlib-public/src ]; then HASHLIB_SRC=../mojo-hashlib-public/src
  elif [ -d ../mojo-hashlib/src ]; then HASHLIB_SRC=../mojo-hashlib/src
  else
    if [ ! -d .work/deps/mojo-hashlib ]; then
      mkdir -p .work/deps
      git clone -q --depth 1 --branch v0.1.2 https://github.com/amarbaro/mojo-hashlib .work/deps/mojo-hashlib || { echo "FAIL setup: clone mojo-hashlib"; exit 1; }
    fi
    HASHLIB_SRC=.work/deps/mojo-hashlib/src
  fi
fi
# The CPython oracle needs 3.14 (uuid6/7/8 exist there only): the system python3, else uv's managed one.
if [ -z "${PYTHON:-}" ]; then
  if python3 -c 'import sys; sys.exit(sys.version_info < (3, 14))' 2>/dev/null; then PYTHON=python3
  elif command -v uv >/dev/null 2>&1; then PYTHON="uv run --no-project --python 3.14 python"
  else echo "FAIL setup: the oracle needs CPython >= 3.14 or uv"; exit 1; fi
fi
export MOJO HASHLIB_SRC PYTHON
