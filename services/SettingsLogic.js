.pragma library

function filtering(filter) {
    return filter !== "";
}

function matches(filter, label) {
    if (!filtering(filter))
        return true;
    return label.toLowerCase().includes(filter.toLowerCase());
}

function sectionMatches(query, title, options) {
    if (matches(query, title))
        return true;
    const list = options || [];
    for (let i = 0; i < list.length; i++) {
        if (matches(query, list[i]))
            return true;
    }
    return false;
}
