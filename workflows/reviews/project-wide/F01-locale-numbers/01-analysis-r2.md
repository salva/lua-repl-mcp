# Locale-independent number conversion

Both public surfaces share the JSON codec. The defective floating-point path is
`string.format('%.17g', v)` at codec.lua:79; its decimal marker follows the host's
numeric locale. The integer branch separately uses tostring. Decimal-comma float
emission makes scalar return 1.5 normalize as two values `[1,5]`; object-number
normalization can fail outright. An embedding host legitimately selects locale;
global locale mutation would violate host ownership. Check parser sensitivity,
finite range, subtype and exact tuple length as well as emitter output. This is
accidental implementation coupling, not required compatibility. Use real available
locales; absence is missing coverage, not proof of success.
