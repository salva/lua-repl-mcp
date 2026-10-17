# Keep argument-capacity errors local

1. Reproduce large zero-array unpack failure below the byte bound.
2. Protect call preparation as well as code execution and traceback generation;
   use truthful stage/effect metadata and leave interpreter usable.
3. Prove user chunk was not entered on preparation failure; execute successfully
   afterward on both direct host and managed worker.
4. Test boundary-size arrays on qualified Lua versions, nil/null slots and normal
   varargs; do not manufacture a constant from one machine's observed threshold.

Dependencies: F03 argument handling, F05/F07 failure representation; batch with
F09 optional diagnostics. Importance 4/5, transversality 3/5.
