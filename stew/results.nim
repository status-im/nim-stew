# This module has graduated from stew and is now available from the
# `results` nimble package instead (https://github.com/arnetheduck/nim-results)

when defined(stewWarnResults):
  # This deprecation notice will be made default in some future stew commit
  {.deprecated: "`stew/results` is now availabe as `import results` via the `results` Nimble package".}

import pkg/results
export results
