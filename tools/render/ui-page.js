// Builds DOM from the exported Roblox GUI tree (see ui-export.luau).
const ui = await (await fetch("/ui.json")).json();

const rgba = (c, a = 1) => (c ? `rgba(${c[0]},${c[1]},${c[2]},${Math.max(0, Math.min(1, a))})` : "transparent");
const len = (scale, offset) => (scale ? `calc(${scale * 100}% + ${offset}px)` : `${offset}px`);
const mods = (n, cls) => n.kids.find((k) => k.c === cls);
const WEIGHTS = { Thin: 100, ExtraLight: 200, Light: 300, Regular: 400, Medium: 500, SemiBold: 600, Bold: 700, ExtraBold: 800, Heavy: 900 };

function richToHtml(text) {
	const esc = text.replace(/&(?!(lt|gt|amp|quot|apos);)/g, "&amp;");
	return esc
		.replace(/<br\s*\/?>/g, "<br>")
		.replace(/<font([^>]*)>/g, (_, attrs) => {
			let style = "";
			const color = /color="([^"]+)"/.exec(attrs);
			if (color) style += `color:${color[1].replace(/rgb\(([^)]+)\)/, "rgb($1)")};`;
			const size = /size="(\d+)"/.exec(attrs);
			if (size) style += `font-size:${size[1]}px;`;
			const weight = /weight="([^"]+)"/.exec(attrs);
			if (weight) style += `font-weight:${weight[1] === "bold" ? 700 : weight[1]};`;
			return `<span style="${style}">`;
		})
		.replace(/<\/font>/g, "</span>")
		.replace(/<(\/?)(b|i|u|s)>/g, "<$1$2>")
		.replace(/<\/?(stroke|uppercase|smallcaps|mark)[^>]*>/g, "");
}

const fitQueue = [];

function build(n, parentEl, parentLayout) {
	if (n.c === "ScreenGui") {
		if (n.enabled === false) return;
		const el = document.createElement("div");
		el.className = "g";
		el.dataset.name = n.n;
		const scale = mods(n, "UIScale")?.scale ?? 1;
		Object.assign(el.style, {
			left: "0",
			top: "0",
			width: `${100 / scale}%`,
			height: `${100 / scale}%`,
			transform: `scale(${scale})`,
			transformOrigin: "0 0",
			zIndex: String(n.order ?? 0),
		});
		parentEl.appendChild(el);
		for (const k of n.kids) build(k, el, null);
		return;
	}
	if (!n.size || n.vis === false) return;
	const el = document.createElement("div");
	el.className = "g";
	el.dataset.name = n.n;
	const s = el.style;
	const [xs, xo, ys, yo] = n.size;
	const autoX = n.auto === "X" || n.auto === "XY";
	const autoY = n.auto === "Y" || n.auto === "XY";
	const ratio = mods(n, "UIAspectRatioConstraint")?.ratio;
	if (parentLayout?.c === "UIGridLayout") {
		s.position = "relative";
		s.width = "100%";
		s.height = "100%";
	} else {
		if (autoX) s.minWidth = len(xs, xo);
		else s.width = len(xs, xo);
		if (autoY) s.minHeight = len(ys, yo);
		else if (ratio) s.aspectRatio = String(ratio);
		else s.height = len(ys, yo);
		if (parentLayout) {
			s.position = "relative";
			s.flexShrink = "0";
			if (parentLayout.sort === "LayoutOrder") s.order = String(n.lo ?? 0);
		} else {
			s.position = "absolute";
			const [px, pxo, py, pyo] = n.pos;
			s.left = len(px, pxo);
			s.top = len(py, pyo);
		}
	}
	if (autoX) el.dataset.autox = "1";
	if (autoY) el.dataset.autoy = "1";
	const transforms = [];
	if (!parentLayout && n.anchor && (n.anchor[0] || n.anchor[1])) transforms.push(`translate(${-n.anchor[0] * 100}%, ${-n.anchor[1] * 100}%)`);
	if (n.rot) transforms.push(`rotate(${n.rot}deg)`);
	if (transforms.length) s.transform = transforms.join(" ");
	s.zIndex = String(n.z ?? 1);
	if (n.clip || n.c === "ScrollingFrame") s.overflow = "hidden";
	const sizeC = mods(n, "UISizeConstraint");
	if (sizeC) {
		if (sizeC.min[0]) s.minWidth = `${sizeC.min[0]}px`;
		if (sizeC.min[1]) s.minHeight = `${sizeC.min[1]}px`;
		if (sizeC.max[0] < 1e6) s.maxWidth = `${sizeC.max[0]}px`;
		if (sizeC.max[1] < 1e6) s.maxHeight = `${sizeC.max[1]}px`;
	}
	// Background (+ gradient, which multiplies the colour in Roblox).
	const bgA = 1 - (n.bgt ?? 0);
	const grad = mods(n, "UIGradient");
	const isText = n.text !== undefined;
	if (bgA > 0.001) {
		if (grad && grad.on !== false) {
			const stops = grad.color.map(([t, c]) => {
				const tr = interp(grad.t, t);
				return `${rgba([(n.bg[0] * c[0]) / 255, (n.bg[1] * c[1]) / 255, (n.bg[2] * c[2]) / 255], bgA * (1 - tr))} ${t * 100}%`;
			});
			s.background = `linear-gradient(${90 + (grad.rot ?? 0)}deg, ${stops.join(", ")})`;
		} else {
			s.background = rgba(n.bg, bgA);
		}
	}
	const corner = mods(n, "UICorner");
	if (corner) s.borderRadius = corner.r[0] >= 0.5 ? "9999px" : corner.r[0] > 0 ? `${corner.r[0] * 100}%` : `${corner.r[1]}px`;
	const stroke = mods(n, "UIStroke");
	const textStroke = stroke && stroke.on !== false && isText && stroke.mode !== "Border";
	if (stroke && stroke.on !== false && !textStroke) {
		s.boxShadow = `0 0 0 ${stroke.th}px ${rgba(stroke.color, 1 - stroke.t)}`;
	}
	const pad = mods(n, "UIPadding")?.pad;
	if (pad) s.padding = `${len(pad[0], pad[1])} ${len(pad[2], pad[3])} ${len(pad[4], pad[5])} ${len(pad[6], pad[7])}`;
	// Image placeholder: a soft rounded tile in the image colour.
	if (n.img) {
		const ph = document.createElement("div");
		Object.assign(ph.style, { position: "absolute", inset: "12%", borderRadius: "30%", background: rgba(n.ic ?? [255, 255, 255], 0.55 * (1 - (n.it ?? 0))) });
		el.appendChild(ph);
	}
	// Text.
	if (isText && n.text) {
		const t = document.createElement("div");
		const ts = t.style;
		Object.assign(ts, {
			position: "absolute",
			inset: pad ? `${len(pad[0], pad[1])} ${len(pad[2], pad[3])} ${len(pad[4], pad[5])} ${len(pad[6], pad[7])}` : "0",
			display: "flex",
			justifyContent: { Left: "flex-start", Right: "flex-end" }[n.xa] ?? "center",
			alignItems: { Top: "flex-start", Bottom: "flex-end" }[n.ya] ?? "center",
			textAlign: { Left: "left", Right: "right" }[n.xa] ?? "center",
			color: grad && grad.on !== false && bgA <= 0.001 ? rgba(grad.color[0][1], 1 - (n.tt ?? 0)) : rgba(n.tc, 1 - (n.tt ?? 0)),
			fontSize: `${n.ts}px`,
			fontWeight: String(WEIGHTS[n.weight] ?? 400),
			fontFamily: n.mono ? "DejaVu Sans Mono, monospace" : "Inter, sans-serif",
			whiteSpace: n.wrap || n.scaled ? "normal" : "nowrap",
			lineHeight: "1.1",
			zIndex: "1",
			pointerEvents: "none",
		});
		if (textStroke) {
			ts.webkitTextStroke = `${stroke.th * 2}px ${rgba(stroke.color, 1 - stroke.t)}`;
			ts.paintOrder = "stroke fill";
		} else if (n.st !== undefined && n.st < 1) {
			ts.textShadow = `0 0 2px ${rgba(n.sc, 1 - n.st)}`;
		}
		const span = document.createElement("span");
		if (n.rich) span.innerHTML = richToHtml(n.text);
		else span.textContent = n.text;
		t.appendChild(span);
		el.appendChild(t);
		if (autoX || autoY) {
			// Let auto-sized text grow its box.
			ts.position = "relative";
			ts.inset = "";
		}
		if (n.scaled) fitQueue.push({ box: t, span, max: mods(n, "UITextSizeConstraint")?.maxText ?? 100 });
	}
	// Children: inside an inner container so padding behaves like Roblox's.
	const list = mods(n, "UIListLayout");
	const grid = mods(n, "UIGridLayout");
	const layout = grid ?? list ?? null;
	const inner = document.createElement("div");
	const is = inner.style;
	Object.assign(is, {
		position: "relative",
		width: autoX ? "max-content" : "100%",
		height: autoY ? "auto" : "100%",
		boxSizing: "border-box",
	});
	inner.dataset.inner = "1";
	if (list) {
		const vertical = list.dir !== "Horizontal";
		const main = vertical ? list.va : list.ha;
		const cross = vertical ? list.ha : list.va;
		Object.assign(is, {
			display: "flex",
			flexDirection: vertical ? "column" : "row",
			flexWrap: list.wraps ? "wrap" : "nowrap",
			gap: len(list.gap[0], list.gap[1]),
			justifyContent: { Center: "center", Right: "flex-end", Bottom: "flex-end" }[main] ?? "flex-start",
			alignItems: { Center: "center", Right: "flex-end", Bottom: "flex-end" }[cross] ?? "flex-start",
		});
	} else if (grid) {
		const [cxs, cxo, cys, cyo] = grid.cell;
		const [pxs, pxo, pys, pyo] = grid.cellPad;
		const cells = grid.maxCells > 0 ? grid.maxCells : "auto-fill";
		const vertical = grid.dir === "Vertical";
		Object.assign(is, {
			display: "grid",
			gridTemplateColumns: vertical ? "" : `repeat(${cells}, ${len(cxs, cxo)})`,
			gridTemplateRows: vertical ? `repeat(${cells}, ${len(cys, cyo)})` : "",
			gridAutoRows: vertical ? "" : len(cys, cyo),
			gridAutoColumns: vertical ? len(cxs, cxo) : "",
			gridAutoFlow: vertical ? "column" : "row",
			columnGap: len(pxs, pxo),
			rowGap: len(pys, pyo),
			justifyContent: { Center: "center", Right: "end" }[grid.ha] ?? "start",
			alignContent: { Center: "center", Bottom: "end" }[grid.va] ?? "start",
		});
	}
	el.appendChild(inner);
	const kids = n.kids.filter((k) => k.size);
	if (layout && layout.sort === "Name") kids.sort((a, b) => (a.n < b.n ? -1 : 1));
	if (layout?.sort === "LayoutOrder") kids.sort((a, b) => (a.lo ?? 0) - (b.lo ?? 0));
	for (const k of kids) build(k, inner, layout);
	parentEl.appendChild(el);
}

function interp(seq, t) {
	if (!seq || !seq.length) return 0;
	for (let i = 0; i < seq.length - 1; i++) {
		const [t0, v0] = seq[i];
		const [t1, v1] = seq[i + 1];
		if (t >= t0 && t <= t1) return v0 + ((v1 - v0) * (t - t0)) / Math.max(t1 - t0, 1e-6);
	}
	return seq[seq.length - 1][1];
}

// Roblox AutomaticSize grows a box to contain all its children, including
// absolutely placed ones (which CSS ignores). Measure and grow, innermost
// boxes first.
function autoSize(root) {
	const boxes = Array.from(root.querySelectorAll("[data-autox],[data-autoy]")).reverse();
	for (const el of boxes) {
		const r = el.getBoundingClientRect();
		const cs = getComputedStyle(el);
		let right = 0;
		let bottom = 0;
		const consider = (c) => {
			const cr = c.getBoundingClientRect();
			right = Math.max(right, cr.right - r.left);
			bottom = Math.max(bottom, cr.bottom - r.top);
		};
		for (const c of el.children) {
			if (c.dataset.inner) {
				for (const k of c.children) consider(k);
			} else consider(c);
		}
		const padR = parseFloat(cs.paddingRight) || 0;
		const padB = parseFloat(cs.paddingBottom) || 0;
		const scale = r.width / (el.offsetWidth || r.width || 1) || 1;
		if (el.dataset.autox && right + padR * scale > r.width + 0.5) el.style.width = `${(right + padR * scale) / scale}px`;
		if (el.dataset.autoy && bottom + padB * scale > r.height + 0.5) el.style.height = `${(bottom + padB * scale) / scale}px`;
	}
}

function fitText() {
	for (const { box, span, max } of fitQueue) {
		const w = box.clientWidth;
		const h = box.clientHeight;
		if (!w || !h) continue;
		let lo = 4;
		let hi = Math.min(max, 100);
		while (hi - lo > 0.5) {
			const mid = (lo + hi) / 2;
			box.style.fontSize = `${mid}px`;
			if (span.offsetWidth <= w + 0.5 && span.offsetHeight <= h + 0.5) lo = mid;
			else hi = mid;
		}
		box.style.fontSize = `${lo}px`;
	}
}

let stage;
window.show = (name) => {
	stage?.remove();
	fitQueue.length = 0;
	stage = document.createElement("div");
	Object.assign(stage.style, { position: "absolute", inset: "0" });
	document.body.appendChild(stage);
	for (const g of ui[name].guis) build(g, stage, null);
	fitText();
	autoSize(stage);
	autoSize(stage);
};
await document.fonts.ready;
window.ready = true;
