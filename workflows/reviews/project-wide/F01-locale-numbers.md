# F01 — Locale-independent JSON numbers

High; data correctness; cross-cutting pure codec/evaluation and both interfaces.
At baseline `8383c03`, decimal-comma numeric locale makes `return 1.5` normalize
to two values `[1,5]`. Numeric formatting is an accidental locale dependency,
not an owner restriction. Preserve host locale and exact return count.

Evidence: [numeric encoder](https://github.com/salva/lua-repl-mcp/blob/8383c03/lua_repl_mcp/codec.lua#L77-L79).
Analysis, alternatives and implementation steps: [work package](F01-locale-numbers/03-plan-r1.md).
