.pragma library
// State machine for power actions (single state for all):
//    idle --click A--> armed(A) --click A (< armMs)--> executes A once --> idle
//    armed(A) --click B--> armed(B)   (never two armed at the same time)
//    after execution, clicks are ignored for guardMs (double click / rapid clicks).
// Pure functions: receive the state and return { state, run } (run = id to execute or "").

function initial() { return { armed: "", armedAt: 0, firedAt: -1e15 } }

function press(st, id, now, armMs, guardMs) {
    if (now - st.firedAt < guardMs) return { state: st, run: "" }
    if (st.armed === id && now - st.armedAt < armMs)
        return { state: { armed: "", armedAt: 0, firedAt: now }, run: id }
    return { state: { armed: id, armedAt: now, firedAt: st.firedAt }, run: "" }
}

function disarm(st) { return { armed: "", armedAt: 0, firedAt: st.firedAt } }
