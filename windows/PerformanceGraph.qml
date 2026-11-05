import QtQuick
import qs.config

Canvas {
    id: root

    property list<real> values
    property list<real> valuesBelow
    property list<real> valuesOver
    property real maxValue: 100
    property int windowSamples: 2
    property bool live: true

    onValuesChanged: root.repaint()
    onValuesBelowChanged: root.repaint()
    onValuesOverChanged: root.repaint()
    onMaxValueChanged: root.repaint()
    onWindowSamplesChanged: root.repaint()
    onLiveChanged: root.repaint()
    onWidthChanged: root.repaint()
    onHeightChanged: root.repaint()

    function repaint(): void {
        if (root.live)
            root.requestPaint();
    }

    function strokeSeries(ctx, series, top: real, bottom: real, color, lineWidth: real): void {
        const count = series.length;
        const first = Math.max(0, count - root.windowSamples);
        ctx.beginPath();
        for (let i = first; i < count; i++) {
            const x = root.xAt(i, count);
            const y = root.yAt(series[i], top, bottom);
            if (i === first)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.stroke();
    }

    function fillSeries(ctx, series, top: real, bottom: real): void {
        const count = series.length;
        const first = Math.max(0, count - root.windowSamples);
        ctx.beginPath();
        ctx.moveTo(root.xAt(first, count), bottom);
        for (let i = first; i < count; i++)
            ctx.lineTo(root.xAt(i, count), root.yAt(series[i], top, bottom));
        ctx.lineTo(root.xAt(count - 1, count), bottom);
        ctx.closePath();
        ctx.fillStyle = Colors.accentDim;
        ctx.fill();
    }

    function xAt(index: int, count: int): real {
        return root.width * (index - (count - root.windowSamples)) / (root.windowSamples - 1);
    }

    function yAt(value: real, top: real, bottom: real): real {
        return bottom + (top - bottom) * Math.min(1, value / root.maxValue);
    }

    function drawArea(ctx, series, top: real, bottom: real): void {
        if (series.length < 2)
            return;
        root.fillSeries(ctx, series, top, bottom);
        root.strokeSeries(ctx, series, top, bottom, Colors.accent, Globals.performanceLineWidth);
    }

    onPaint: {
        const ctx = root.getContext("2d");
        ctx.reset();
        const inset = Globals.performanceLineWidth;
        ctx.fillStyle = Colors.cardSecondary;
        ctx.fillRect(0, 0, root.width, root.height);
        if (root.valuesBelow.length > 0) {
            const middle = root.height / 2;
            root.drawArea(ctx, root.values, inset, middle - Globals.hairlineHeight);
            root.drawArea(ctx, root.valuesBelow, root.height - inset, middle + Globals.hairlineHeight);
        } else {
            root.drawArea(ctx, root.values, inset, root.height);
            if (root.valuesOver.length >= 2)
                root.strokeSeries(ctx, root.valuesOver, inset, root.height, Colors.text, Globals.performanceOverLineWidth);
        }
        ctx.fillStyle = Colors.border;
        for (let i = 1; i < Globals.performanceGridDivisions; i++)
            ctx.fillRect(Math.round(root.width * i / Globals.performanceGridDivisions), 0, Globals.hairlineHeight, root.height);
    }
}
