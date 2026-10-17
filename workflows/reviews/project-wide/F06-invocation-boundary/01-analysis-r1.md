# Protect invocation preparation

Lua call-stack/argument capacity is finite independently of the JSON byte bound.
Argument unpack currently executes outside the protected invocation, so a legal
payload can end the attachment before code runs. Protecting setup and reporting
pre-effect failure is necessary; a new arbitrary public argument count is not.
Classify any unavoidable VM limit honestly instead of silently shrinking JSON
allowances. Do not imply that arbitrary memory exhaustion is recoverable.
