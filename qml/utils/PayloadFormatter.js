.pragma library

function detectFormat(text) {
    if (!text || text.trim().length === 0)
        return "raw"

    var trimmed = text.trim()

    // JSON detection
    if ((trimmed.charAt(0) === '{' && trimmed.charAt(trimmed.length - 1) === '}') ||
        (trimmed.charAt(0) === '[' && trimmed.charAt(trimmed.length - 1) === ']')) {
        try {
            JSON.parse(trimmed)
            return "json"
        } catch (e) {
            // Not valid JSON, continue checking
        }
    }

    // XML detection
    if (trimmed.charAt(0) === '<' && trimmed.charAt(trimmed.length - 1) === '>') {
        if (trimmed.match(/^<\??\w+[\s\S]*>$/))
            return "xml"
    }

    return "raw"
}

function beautifyJson(text) {
    try {
        var obj = JSON.parse(text.trim())
        return JSON.stringify(obj, null, 2)
    } catch (e) {
        return { error: e.message, text: text }
    }
}

function beautifyXml(text) {
    var trimmed = text.trim()
    var formatted = ""
    var indent = 0
    var inTag = false
    var tagContent = ""

    // Simple XML indentation
    var tokens = trimmed.replace(/>\s*</g, ">\n<").split("\n")

    for (var i = 0; i < tokens.length; i++) {
        var line = tokens[i].trim()
        if (line.length === 0)
            continue

        // Closing tag
        if (line.match(/^<\//) ) {
            indent--
        }

        for (var s = 0; s < indent; s++)
            formatted += "  "
        formatted += line + "\n"

        // Opening tag (not self-closing, not closing, not declaration)
        if (line.match(/^<[^\/\?!]/) && !line.match(/\/>$/) && !line.match(/^<\?/)) {
            indent++
        }
    }

    return formatted.trimRight()
}

function beautify(text, format) {
    if (!text || text.trim().length === 0)
        return text

    var fmt = format || detectFormat(text)

    if (fmt === "json")
        return beautifyJson(text)
    else if (fmt === "xml")
        return beautifyXml(text)
    else
        return text
}

function validateJson(text) {
    if (!text || text.trim().length === 0)
        return { valid: true, message: "" }

    try {
        JSON.parse(text.trim())
        return { valid: true, message: "Valid JSON" }
    } catch (e) {
        return { valid: false, message: e.message }
    }
}

function validateXml(text) {
    if (!text || text.trim().length === 0)
        return { valid: true, message: "" }

    var trimmed = text.trim()

    // Basic XML validation
    if (trimmed.charAt(0) !== '<') {
        return { valid: false, message: "XML must start with '<'" }
    }

    // Check matching tags (simple)
    var openTags = trimmed.match(/<([a-zA-Z][a-zA-Z0-9]*)[^>]*(?<!\/)\s*>/g) || []
    var closeTags = trimmed.match(/<\/([a-zA-Z][a-zA-Z0-9]*)\s*>/g) || []

    if (openTags.length === 0 && closeTags.length === 0) {
        return { valid: false, message: "No XML tags found" }
    }

    return { valid: true, message: "Valid XML" }
}
