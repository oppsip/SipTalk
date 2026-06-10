# Native SIP Core

This directory contains the C++ boundary that will wrap PJSUA2.

Current files are scaffolding. The next implementation step is to replace the stub event emission in `SipCore.cpp` with real PJSUA2 `Endpoint`, `Account`, and `Call` ownership while keeping the same public API.

Rules:

- PJSUA2 objects stay in native code.
- All commands run through `SipCommandQueue`.
- Callbacks emit events only.
- Platform bridges pass IDs and JSON payloads, not raw native object pointers.
