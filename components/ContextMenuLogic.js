.pragma library

function hasIndicator(list) {
    const items = list || [];
    for (let i = 0; i < items.length; i++) {
        if (items[i] && items[i].check)
            return true;
    }
    return false;
}

function indicatorWidth(list, glyphWidth, spacing) {
    return hasIndicator(list) ? glyphWidth + spacing : 0;
}
