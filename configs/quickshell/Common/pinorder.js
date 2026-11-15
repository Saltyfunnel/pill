.pragma library
// Island menu order: list of ALL items (pinned or not), so
// disabling and re-enabling preserves the position. Pure functions (tests/pinorder.test.js).

// Full order: saved items (without duplicates or deleted ones), then missing pinned items
// (respecting the historical order of `pins`) and finally the rest in catalog order.
function full(saved, pins, all) {
    const out = []
    const add = id => { if (all.indexOf(id) >= 0 && out.indexOf(id) < 0) out.push(id) }
    ;(saved || []).forEach(add); (pins || []).forEach(add); all.forEach(add)
    return out
}
// Moves `id` one position (delta -1 up, +1 down). Out of range: no changes.
function move(order, id, delta) {
    const i = order.indexOf(id), j = i + delta
    if (i < 0 || j < 0 || j >= order.length) return order.slice()
    const out = order.slice(); out[i] = order[j]; out[j] = id
    return out
}
// Pinned items sorted according to `order` (without duplicates).
function sortPins(pins, order) {
    return order.filter(id => pins.indexOf(id) >= 0)
}
