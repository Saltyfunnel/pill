.pragma library
// Emoji picker: pure logic (tested with node in tests/emoji.test.js).

var TONES = ["", "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"]

// Lowercase and accentless, to search for "cafe" and find "café".
function norm(s) {
    return String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim()
}

// emoji.json → [{ id, label, icon, items: [{ e, name, key, tone }] }] in the requested language.
function parse(text, lang) {
    var d
    try { d = JSON.parse(text) } catch (e) { return [] }
    if (!d || !Array.isArray(d.categories)) return []
    var en = lang === "en"
    return d.categories.map(function (c) {
        return {
            id: c.id, label: en ? c.en : c.es, icon: c.icon,
            items: (c.items || []).filter(function (it) { return Array.isArray(it) && typeof it[0] === "string" && it[0] }).map(function (it) {
                return { e: it[0], name: en ? it[2] : it[1], key: norm(it[1] + " " + it[2]), tone: it[3] === 1 }
            })
        }
    })
}

// Searches Spanish and English names (all words must appear). Max `limit`.
function search(cats, query, limit) {
    var words = norm(query).split(/\s+/).filter(function (w) { return w })
    if (words.length === 0) return []
    var out = []
    for (var i = 0; i < cats.length; i++)
        for (var j = 0; j < cats[i].items.length; j++) {
            var it = cats[i].items[j]
            if (words.every(function (w) { return it.key.indexOf(w) >= 0 })) {
                out.push(it)
                if (out.length >= (limit || 64)) return out
            }
        }
    return out
}

// Skin tone: the modifier goes right after the first code (and without the variation
// selector U+FE0F, which the modifier replaces: ✌️ + 🏽 → ✌🏽).
function withTone(e, tone) {
    var t = TONES[tone] || ""
    if (!t) return e
    // Without Array.from: the Qt 6.8 JS engine iterates by UTF-16 code units and splits surrogate pairs.
    var first = String.fromCodePoint(e.codePointAt(0))
    var rest = e.slice(first.length)
    if (rest.charAt(0) === "\uFE0F") rest = rest.slice(1)
    return first + t + rest
}

// Exact text copied for an item.
function textFor(item, tone) { return item.tone ? withTone(item.e, tone) : item.e }

// Drawing only: Qt 6.8 splits ZWJ sequences that carry U+FE0F before
// U+200D (🏳️‍🌈 → 🏳 + 🌈); without that selector, the emoji font joins them anyway. The copied text
// is always the complete sequence (textFor), never this.
function glyph(s) { return String(s).replace(/\uFE0F\u200D/g, "\u200D") }
