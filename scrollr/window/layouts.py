"""Algoritmi di disposizione automatica, mescola e scambia."""
import math
import random
from typing import List, Optional, Tuple

from PyQt6.QtCore import QRectF, QPointF
from PyQt6.QtWidgets import QMessageBox

from scrollr.canvas.photo_item import PhotoItem
from scrollr.keys import kb


class LayoutMixin:
    """Algoritmi di disposizione automatica, mescola e scambia."""

    SEAM_KEEP = 0.15  # «A cavallo»: parte minima di pagina che una foto occupa da ogni lato della giunzione

    # ================= ALGORITMI DI LAYOUT E RIORGANIZZAZIONE =================
    def _on_layout_button(self, mode: str):
        # Nuovo seed solo quando si sceglie esplicitamente un layout: gli slider non rigenerano il random
        self._layout_seed = random.randrange(1 << 30)
        self.current_layout_mode = mode
        self.apply_auto_layout(mode)
        self._sync_layout_tiles()
        self._schedule_commit()

    def _sync_layout_tiles(self):
        tile = self.layout_tiles.get(self.current_layout_mode)
        if tile is not None:
            tile.setChecked(True)
        self.mosaic_style_box.setVisible(self.current_layout_mode == "mosaic")
        idx = self.combo_mosaic.findData(self.mosaic_style)
        if idx >= 0 and idx != self.combo_mosaic.currentIndex():
            self.combo_mosaic.blockSignals(True)
            self.combo_mosaic.setCurrentIndex(idx)
            self.combo_mosaic.blockSignals(False)

    def _on_mosaic_style_changed(self, index: int):
        self.mosaic_style = self.combo_mosaic.itemData(index) or "auto"
        if self.current_layout_mode == "mosaic":
            self._relayout_keep()

    def _relayout_keep(self, *_):
        if self._restoring:
            return
        if self.get_canvas_photos():
            self.apply_auto_layout(self.current_layout_mode)
            self._schedule_commit()

    def _layout_photos(self) -> List[PhotoItem]:
        """Foto ordinate dalla disposizione automatica: tutte tranne quelle libere."""
        return [p for p in self.get_canvas_photos() if not p.free]

    def apply_auto_layout(self, mode: str):
        photos = self._layout_photos()
        if not photos:
            return
        self.current_layout_mode = mode
        rng = random.Random(self._layout_seed)
        gap = float(self.slider_gap.value())
        margin = float(self.slider_margin.value())

        # Il bordo bianco "Polaroid" aggiunto in automatico si toglie: lo rimette Polaroid dove serve
        for p in photos:
            if p.auto_border:
                p.border_width = 0.0
                p.auto_border = False
                p.update()

        if mode == "scrl_seam":
            if self.scene.num_frames < 2:
                # "A cavallo" richiede almeno 2 pagine: le aggiunge e ricorda quante ce n'erano prima
                frames = max(2, math.ceil(len(photos) / 4))
                self._seam_added_frames = (self.scene.num_frames, frames)
                self._set_frames_silently(frames)
                self.statusBar().showMessage(
                    f"«A cavallo» ha bisogno di più pagine: ne ho impostate {frames}. "
                    "Scegliendo un'altra disposizione torni al formato di prima.", 8000)
        elif self._seam_added_frames is not None:
            # Si lascia "A cavallo": ripristina il numero di pagine originale, se non è stato cambiato a mano
            before, added = self._seam_added_frames
            self._seam_added_frames = None
            if self.scene.num_frames == added:
                self._set_frames_silently(before)
                self.statusBar().showMessage(f"Formato ripristinato: {before} pagina" if before == 1
                                             else f"Formato ripristinato: {before} pagine", 5000)
        if mode == "scrl_seam":
            canvas = self.scene.canvas_rect().adjusted(margin, margin, -margin, -margin)
            self._layout_seam(photos, self._safe_rect(canvas), gap)
        else:
            per_page = self.spin_per_page.value()
            if self.chk_per_frame.isChecked() and per_page > 0:
                # Numero fisso di foto per pagina: le pagine si adeguano (tenendo quelle con testi e forme)
                needed = len(self._page_photo_counts(len(photos)))
                # Restano anche le pagine con testi, forme o foto libere
                text_pages = [self._page_of(t) + 1 for t in self.get_canvas_texts() + self.get_canvas_shapes()]
                text_pages += [self._page_of(p) + 1 for p in self.get_canvas_photos() if p.free]
                frames = max([1, needed] + [p for p in text_pages if p <= self.spin_frames.maximum()])
                if frames != self.scene.num_frames:
                    self._set_frames_silently(frames)
            if self.chk_per_frame.isChecked():
                chunks, start = [], 0
                for count in self._page_photo_counts(len(photos)):
                    chunks.append(photos[start:start + count])
                    start += count
                fw = self.scene.frame_w
                for first, last in self.scene.seam_groups():
                    chunk = [p for f in range(first, min(last + 1, len(chunks))) for p in chunks[f]]
                    if not chunk:
                        continue
                    frame_rect = QRectF(first * fw, 0, (last - first + 1) * fw, self.scene.frame_h)
                    area = self._safe_rect(frame_rect.adjusted(margin, margin, -margin, -margin))
                    if last > first:
                        # Pagine unite «a cavallo»: righe continue che attraversano solo le loro giunzioni
                        self._layout_seam(chunk, area, gap, [k * fw for k in range(first + 1, last + 1)])
                        continue
                    # Una pagina può avere la sua disposizione (clic destro → Disposizione di questa pagina)
                    own = self.scene.page_layouts[first] if first < len(self.scene.page_layouts) else None
                    if own:
                        self._layout_in_rect(own["mode"], chunk, area, gap, rng, own.get("style"))
                    else:
                        self._layout_in_rect(mode, chunk, area, gap, rng)
            else:
                area = self._safe_rect(self.scene.canvas_rect().adjusted(margin, margin, -margin, -margin))
                self._layout_in_rect(mode, photos, area, gap, rng)

        self.scene.update()
        self._sync_inspector_from_item(self._get_primary_selected())

    def _page_photo_counts(self, n: int) -> List[int]:
        """
        Quante foto vanno in ogni pagina, nell'ordine delle pagine. Le pagine con un numero fissato
        (clic destro → Foto in questa pagina) lo rispettano; le altre prendono "Foto per pagina"
        oppure, su Auto, si dividono in parti uguali le foto rimaste.
        """
        fixed = self.scene.page_counts
        per_page = self.spin_per_page.value()

        def fixed_at(i: int) -> Optional[int]:
            return fixed[i] if i < len(fixed) else None

        if per_page > 0:
            counts, left = [], n
            while left > 0 and len(counts) < self.spin_frames.maximum():
                f = fixed_at(len(counts))
                c = min(per_page if f is None else f, left)
                counts.append(c)
                left -= c
            if left and counts:
                counts[-1] += left  # Raggiunto il massimo di pagine: le foto in più vanno nell'ultima
            return counts

        frames = self.scene.num_frames
        counts: List[Optional[int]] = [None] * frames
        left = n
        for i in range(frames):
            f = fixed_at(i)
            if f is not None:
                counts[i] = min(f, left)
                left -= counts[i]
        free = [i for i in range(frames) if counts[i] is None]
        if free:
            # Le prime pagine libere prendono l'eccedenza
            base, extra = divmod(left, len(free))
            for j, i in enumerate(free):
                counts[i] = base + (1 if j < extra else 0)
        elif left:
            counts[-1] += left  # Tutte le pagine sono fissate: le foto in più vanno nell'ultima
        return counts

    def _on_per_page_changed(self, *_):
        if self._restoring:
            return
        if self.spin_per_page.value() == 0:
            self.statusBar().showMessage("Foto per pagina su Auto: le foto si dividono tra le pagine impostate", 4000)
        self._relayout_keep()
        self._schedule_commit()

    def _set_frames_silently(self, frames: int):
        """Cambia il numero di pagine senza far scattare un secondo relayout."""
        self.spin_frames.blockSignals(True)
        self.spin_frames.setValue(frames)
        self.spin_frames.blockSignals(False)
        self.scene.num_frames = frames
        self.scene.update_canvas_rect()
        self.fit_canvas_in_view()

    @staticmethod
    def _safe_rect(r: QRectF) -> QRectF:
        return QRectF(r.x(), r.y(), max(100.0, r.width()), max(100.0, r.height()))

    @staticmethod
    def _place(p: PhotoItem, x: float, y: float, w: float, h: float, rotation: float = 0.0):
        p.setRotation(rotation)
        p.set_cell_size(w, h)
        p.setPos(x, y)
        p.saved_cell = None

    def _layout_in_rect(self, mode: str, photos: List[PhotoItem], area: QRectF, gap: float, rng: random.Random,
                        mosaic_style: Optional[str] = None):
        if mode == "mosaic":
            self._layout_mosaic(photos, area, gap, mosaic_style or self.mosaic_style)
        elif mode == "strips_h":
            self._layout_strips(photos, area, gap, horizontal=True)
        elif mode == "strips_v":
            self._layout_strips(photos, area, gap, horizontal=False)
        elif mode == "scatter":
            self._layout_scatter(photos, area, rng)
        else:
            self._layout_grid(photos, area, gap)

    def _layout_grid(self, photos: List[PhotoItem], area: QRectF, gap: float):
        # Calcola numero ottimale di righe e colonne in base al rapporto dell'area (es. 3:4)
        n = len(photos)
        cols = min(n, max(1, round(math.sqrt(n * area.width() / area.height()))))
        rows = math.ceil(n / cols)
        row_h = (area.height() - gap * (rows - 1)) / rows
        idx = 0
        for r in range(rows):
            remaining = n - idx
            cols_in_row = min(cols, math.ceil(remaining / (rows - r)))
            col_w = (area.width() - gap * (cols_in_row - 1)) / cols_in_row
            for c in range(cols_in_row):
                self._place(photos[idx], area.x() + c * (col_w + gap), area.y() + r * (row_h + gap), col_w, row_h)
                idx += 1

    def _layout_mosaic(self, photos: List[PhotoItem], area: QRectF, gap: float, style: str):
        # Foto "Hero" in evidenza + griglia per le altre; la posizione dipende dallo stile scelto
        portrait = area.height() >= area.width()
        if style == "masonry":
            self._layout_masonry(photos, area, gap)
            return
        hero, others = photos[0], photos[1:]
        if not others:
            self._place(hero, area.x(), area.y(), area.width(), area.height())
            return
        x, y, w, h = area.x(), area.y(), area.width(), area.height()

        if style == "two" and len(others) >= 2:
            heroes, rest_photos = photos[:2], photos[2:]
            if portrait:
                band = (h - gap) * 0.55
                half = (w - gap) / 2.0
                self._place(heroes[0], x, y, half, band)
                self._place(heroes[1], x + half + gap, y, half, band)
                rest = QRectF(x, y + band + gap, w, h - band - gap)
            else:
                band = (w - gap) * 0.55
                half = (h - gap) / 2.0
                self._place(heroes[0], x, y, band, half)
                self._place(heroes[1], x, y + half + gap, band, half)
                rest = QRectF(x + band + gap, y, w - band - gap, h)
            self._layout_grid(rest_photos, rest, gap)
            return

        if style == "center" and len(others) >= 2:
            k = math.ceil(len(others) / 2)
            first, second = others[:k], others[k:]
            if portrait:
                mid = (h - 2 * gap) * 0.56
                side = (h - 2 * gap - mid) / 2.0
                self._layout_grid(first, QRectF(x, y, w, side), gap)
                self._place(hero, x, y + side + gap, w, mid)
                self._layout_grid(second, QRectF(x, y + side + mid + 2 * gap, w, side), gap)
            else:
                mid = (w - 2 * gap) * 0.56
                side = (w - 2 * gap - mid) / 2.0
                self._layout_grid(first, QRectF(x, y, side, h), gap)
                self._place(hero, x + side + gap, y, mid, h)
                self._layout_grid(second, QRectF(x + side + mid + 2 * gap, y, side, h), gap)
            return

        where = style if style in ("top", "bottom", "left", "right") else ("top" if portrait else "left")
        if where in ("top", "bottom"):
            hero_h = (h - gap) * 0.55
            rest_h = h - hero_h - gap
            if where == "top":
                self._place(hero, x, y, w, hero_h)
                rest = QRectF(x, y + hero_h + gap, w, rest_h)
            else:
                self._place(hero, x, y + rest_h + gap, w, hero_h)
                rest = QRectF(x, y, w, rest_h)
        else:
            hero_w = (w - gap) * 0.55
            rest_w = w - hero_w - gap
            if where == "left":
                self._place(hero, x, y, hero_w, h)
                rest = QRectF(x + hero_w + gap, y, rest_w, h)
            else:
                self._place(hero, x + rest_w + gap, y, hero_w, h)
                rest = QRectF(x, y, rest_w, h)
        self._layout_grid(others, rest, gap)

    def _layout_masonry(self, photos: List[PhotoItem], area: QRectF, gap: float):
        # Colonne riempite a tutta altezza con foto di altezze diverse e giunzioni sfalsate
        n = len(photos)
        cols = min(n, max(1, round(math.sqrt(n * area.width() / area.height()))))
        if n >= 4:
            cols = max(2, cols)
        col_w = (area.width() - gap * (cols - 1)) / cols
        columns: List[List[Tuple[PhotoItem, float]]] = [[] for _ in range(cols)]
        heights = [0.0] * cols
        for p in photos:
            pm = p.pixmap
            ratio = pm.height() / pm.width() if pm.width() > 0 and pm.height() > 0 else 1.0
            ratio = min(1.8, max(0.55, ratio))
            c = heights.index(min(heights))
            columns[c].append((p, ratio))
            heights[c] += ratio
        for c, items in enumerate(columns):
            if not items:
                continue
            # Alterna foto alte e basse, sfasate tra colonne vicine, così le giunzioni non si allineano mai
            weights = [r * (1.3 if (c + j) % 2 == 0 else 0.77) for j, (_p, r) in enumerate(items)]
            avail = area.height() - gap * (len(items) - 1)
            total = sum(weights)
            cy = area.y()
            cx = area.x() + c * (col_w + gap)
            for (p, _r), wt in zip(items, weights):
                ph = avail * wt / total
                self._place(p, cx, cy, col_w, ph)
                cy += ph + gap

    def _layout_strips(self, photos: List[PhotoItem], area: QRectF, gap: float, horizontal: bool):
        n = len(photos)
        if horizontal:
            row_h = (area.height() - gap * (n - 1)) / n
            for i, p in enumerate(photos):
                self._place(p, area.x(), area.y() + i * (row_h + gap), area.width(), row_h)
        else:
            col_w = (area.width() - gap * (n - 1)) / n
            for i, p in enumerate(photos):
                self._place(p, area.x() + i * (col_w + gap), area.y(), col_w, area.height())

    def _layout_scatter(self, photos: List[PhotoItem], area: QRectF, rng: random.Random):
        # Stile Freestyle / Polaroid con leggera inclinazione casuale (riproducibile tramite seed)
        n = len(photos)
        cols = max(1, math.ceil(math.sqrt(n * area.width() / area.height())))
        rows = math.ceil(n / cols)
        cell_w = area.width() / cols
        cell_h = area.height() / rows
        for i, p in enumerate(photos):
            r, c = divmod(i, cols)
            w = cell_w * 0.88
            h = cell_h * 0.88
            jitter_x = rng.uniform(-cell_w * 0.08, cell_w * 0.08)
            jitter_y = rng.uniform(-cell_h * 0.08, cell_h * 0.08)
            x = area.x() + c * cell_w + (cell_w - w) / 2.0 + jitter_x
            y = area.y() + r * cell_h + (cell_h - h) / 2.0 + jitter_y
            self._place(p, x, y, w, h, rng.uniform(-7.5, 7.5))
            if p.border_width == 0:
                p.border_width = 8.0
                p.auto_border = True
                p.update()

    def _layout_seam(self, photos: List[PhotoItem], area: QRectF, gap: float,
                     seams: Optional[List[float]] = None):
        """
        «A cavallo»: righe giustificate su tutta l'area, con le proporzioni vere delle foto.
        Nessuno spazio tra due foto cade vicino a una giunzione: ogni giunzione è attraversata da una
        foto, che resta visibile per almeno SEAM_KEEP della pagina da entrambe le parti.
        `seams` = x delle giunzioni da attraversare (None = tutte quelle della tela).
        """
        aspects = []
        for p in photos:
            pm = p.pixmap
            a = pm.width() / pm.height() if pm.width() > 0 and pm.height() > 0 else 1.0
            aspects.append(min(2.2, max(0.5, a)))
        w_avail, h_avail = area.width(), area.height()

        # Numero di righe: quello che, a proporzioni intatte, riempie meglio l'altezza della tela
        best = None
        for r in range(1, min(len(photos), 8) + 1):
            rows = self._split_rows(aspects, r)
            heights = [(w_avail - gap * (len(row) - 1)) / sum(aspects[i] for i in row) for row in rows]
            score = abs(math.log((sum(heights) + gap * (r - 1)) / h_avail))
            if best is None or score < best[0]:
                best = (score, rows, heights)
        _, rows, heights = best
        scale = (h_avail - gap * (len(rows) - 1)) / sum(heights)

        fw = self.scene.frame_w
        if seams is None:
            seams = [k * fw for k in range(1, self.scene.num_frames)]
        keep = fw * self.SEAM_KEEP
        y = area.y()
        for row, row_h in zip(rows, heights):
            row_h *= scale
            total_a = sum(aspects[i] for i in row)
            inner = w_avail - gap * (len(row) - 1)
            # Centri degli spazi tra le foto della riga
            cuts, x = [], area.x()
            for i in row[:-1]:
                x += inner * aspects[i] / total_a
                cuts.append(x + gap / 2.0)
                x += gap
            # Sposta gli spazi troppo vicini a una giunzione, senza rendere una foto troppo stretta
            min_w = row_h * 0.45
            for j, c in enumerate(cuts):
                near = [sx for sx in seams if abs(c - sx) < keep]
                if not near:
                    continue
                lo = (cuts[j - 1] if j > 0 else area.x() - gap / 2.0) + min_w + gap
                hi = (cuts[j + 1] if j + 1 < len(cuts) else area.right() + gap / 2.0) - min_w - gap
                options = [t for t in (near[0] - keep, near[0] + keep)
                           if lo <= t <= hi and not any(abs(t - sx) < keep - 0.5 for sx in seams)]
                if options:
                    cuts[j] = min(options, key=lambda t: abs(t - c))
            edges = [area.x() - gap / 2.0] + cuts + [area.right() + gap / 2.0]
            for k, i in enumerate(row):
                left, right = edges[k] + gap / 2.0, edges[k + 1] - gap / 2.0
                self._place(photos[i], left, y, right - left, row_h)
            y += row_h + gap

    @staticmethod
    def _split_rows(aspects: List[float], rows: int) -> List[List[int]]:
        """Divide le foto (in ordine) in righe con somme di proporzioni il più possibile uguali."""
        n = len(aspects)
        pre = [0.0]
        for a in aspects:
            pre.append(pre[-1] + a)
        target = pre[-1] / rows
        inf = float("inf")
        cost = [[inf] * (n + 1) for _ in range(rows + 1)]
        back = [[0] * (n + 1) for _ in range(rows + 1)]
        cost[0][0] = 0.0
        for k in range(1, rows + 1):
            for i in range(k, n + 1):
                for j in range(k - 1, i):
                    c = cost[k - 1][j] + (pre[i] - pre[j] - target) ** 2
                    if c < cost[k][i]:
                        cost[k][i], back[k][i] = c, j
        bounds, i = [], n
        for k in range(rows, 0, -1):
            j = back[k][i]
            bounds.append(list(range(j, i)))
            i = j
        return bounds[::-1]

    @staticmethod
    def _slot(p: PhotoItem) -> tuple:
        return (QPointF(p.pos()), p.cell_w, p.cell_h, p.rotation(), p.zValue(), p.layout_index)

    @staticmethod
    def _apply_slot(p: PhotoItem, slot: tuple):
        pos, w, h, rot, z, layout_index = slot
        p.set_cell_size(w, h)
        p.setPos(pos)
        p.setRotation(rot)
        p.setZValue(z)
        p.layout_index = layout_index

    def shuffle_canvas_photos(self):
        """Rimescola l'ordine delle foto mantenendo esattamente le posizioni e dimensioni correnti."""
        photos = self._layout_photos()
        if len(photos) < 2:
            return
        slots = [self._slot(p) for p in photos]
        shuffled = slots[:]
        while shuffled == slots:  # Garantisce che qualcosa cambi davvero
            random.shuffle(shuffled)
        for p, slot in zip(photos, shuffled):
            self._apply_slot(p, slot)
        self.scene.update()
        self._schedule_commit()

    # ---------- Foto spostate da una pagina all'altra ----------
    def _photo_pages(self) -> dict:
        """Pagina in cui la disposizione mette ogni foto ordinata: {uid: pagina}."""
        ordered = self._layout_photos()
        pages, start = {}, 0
        for f, count in enumerate(self._page_photo_counts(len(ordered))):
            for p in ordered[start:start + count]:
                pages[p.uid] = f
            start += count
        return pages

    def _pages_split(self) -> bool:
        """Le foto si dividono per pagina (altrimenti non ha senso spostarle da una pagina all'altra)."""
        return (self.chk_per_frame.isChecked() and self.current_layout_mode != "scrl_seam"
                and self.scene.num_frames > 1)

    def _move_photos_to_page(self, photos: List[PhotoItem], target: int):
        """
        Mette le foto nella pagina `target` (in fondo alle sue foto). Le pagine toccate fissano il
        loro nuovo numero di foto, così il prossimo ridisegno non le riporta dov'erano.
        """
        if not self._pages_split() or not (0 <= target < self.scene.num_frames):
            return False
        ordered = self._layout_photos()
        current = self._photo_pages()
        movers = [p for p in photos if not p.free and current.get(p.uid, target) != target]
        if not movers:
            return False
        by_page: List[List[PhotoItem]] = [[] for _ in range(self.scene.num_frames)]
        for p in ordered:
            if p not in movers:
                by_page[min(current.get(p.uid, 0), self.scene.num_frames - 1)].append(p)
        by_page[target].extend(movers)
        counts = self.scene.page_counts
        counts.extend([None] * (self.scene.num_frames - len(counts)))
        for f in {current[p.uid] for p in movers} | {target}:
            counts[f] = len(by_page[f])
        self._trim_page_lists()
        for i, p in enumerate(p for page in by_page for p in page):
            p.layout_index = i
        self._relayout_keep()
        self.statusBar().showMessage(
            (f"Foto spostata nella pagina {target + 1}" if len(movers) == 1
             else f"{len(movers)} foto spostate nella pagina {target + 1}"), 4000)
        self._schedule_commit()
        return True

    def _insert_into_page(self, new: List[PhotoItem], target: int, current: dict):
        """
        Foto appena create messe in fondo alla pagina `target`; `current` è la pagina delle foto
        già ordinate (letta prima di crearle). La pagina fissa il suo nuovo numero di foto.
        """
        n = self.scene.num_frames
        by_page: List[List[PhotoItem]] = [[] for _ in range(n)]
        for p in self._layout_photos():
            if p not in new:
                by_page[min(current.get(p.uid, n - 1), n - 1)].append(p)
        by_page[target].extend(new)
        counts = self.scene.page_counts
        counts.extend([None] * (n - len(counts)))
        counts[target] = len(by_page[target])
        self._trim_page_lists()
        for i, p in enumerate(p for page in by_page for p in page):
            p.layout_index = i
        self._relayout_keep()

    def _on_photo_dropped(self, item: PhotoItem):
        """Foto trascinata e rilasciata su un'altra pagina: passa a quella pagina e ci resta."""
        if not self._pages_split():
            return
        dragged = [p for p in self._selected_photos() if not p.free] or ([item] if not item.free else [])
        current = self._photo_pages()
        group = {f: g for g in self.scene.seam_groups() for f in range(g[0], g[1] + 1)}
        targets = {}
        for p in dragged:
            page = self._page_of(p)
            # Dentro lo stesso gruppo «a cavallo» la foto non cambia pagina: attraversa già le giunzioni
            if 0 <= page < self.scene.num_frames and group[page] != group.get(current.get(p.uid, page)):
                targets.setdefault(page, []).append(p)
        for page, photos in targets.items():
            self._move_photos_to_page(photos, page)

    def _toggle_free_selected(self):
        """Foto libera ↔ foto nella disposizione, per le foto selezionate."""
        photos = self._selected_photos()
        if not photos:
            return
        make_free = not all(p.free for p in photos)
        for p in photos:
            p.set_free(make_free)
            if make_free:
                p.setZValue(self._max_z() + 1.0)  # Davanti alle foto ordinate
        self._relayout_keep()
        if make_free:
            self.statusBar().showMessage("Foto libera: spostala dove vuoi, la disposizione non la tocca più", 5000)
        else:
            self.statusBar().showMessage("La foto è tornata nella disposizione", 4000)
        self._schedule_commit()

    def swap_two_selected_photos(self):
        selected = self._selected_photos()
        if len(selected) != 2:
            QMessageBox.information(
                self,
                "Scambia due foto",
                kb("Seleziona esattamente 2 foto sulla tela: clicca la prima, poi Ctrl+clic sulla seconda.")
            )
            return
        p1, p2 = selected
        s1, s2 = self._slot(p1), self._slot(p2)
        self._apply_slot(p1, s2)
        self._apply_slot(p2, s1)
        self.scene.update()
        self._schedule_commit()
