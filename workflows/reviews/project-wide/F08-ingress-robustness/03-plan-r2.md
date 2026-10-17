# Reject duplicates without destroying sessions

1. Implement -32600/id:null duplicate policy in the single ingress owner. Test
   invalid JSON -32700 separately from decoded false/null/scalars -32600.
2. Assert original request retains ownership and produces exactly one original-ID
   response; a rejected duplicate neither cancels work nor consumes its payload.
3. Test duplicate while running and after evaluation termination but before
   response commitment; then legitimate ID reuse after response enqueue and
   cancellation suppression. Generation checks prevent late-response aliasing.
4. Cover admission/protocol rejection, failed fallback encoding, failed enqueue
   and disconnect against the exact reservation lifecycle. Keep unrelated session
   globals usable through live managed tests and saturation/cancellation races.

Dependencies: F05 errors, selected F13 commitment and F04 waiter handling.
Implement C's registry using that fixed contract; final integrated races run D.
Importance4/5, transversality3/5.
