# Keep preparation-capacity failures local and exact

1. Use the bounded one-million-zero-argument fixture below input-byte limit;
   do not discover a threshold through unbounded resource exhaustion.
2. Implement protected preparation and trampoline marker. Assert exact failed /
   limit_exceeded / execution / not_started result, managed idle/usable state,
   no chunk-entry side-effect witness and successful next execution.
3. Fault traceback generation while provoking both preparation and ordinary
   runtime errors; retain the primary code/message/state and omit failed trace.
4. Test nil/null/normal varargs, syntax failures and qualified Lua versions on
   direct host and guardian-backed installed manager paths.

Dependencies: F03 copier, F05 and pre-C F07 failure interface; batch with F09.
Importance4/5, transversality3/5. No arbitrary positional cap or effect replay.
