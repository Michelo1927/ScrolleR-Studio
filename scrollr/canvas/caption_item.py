"""
Sottotitoli sulla tela: un blocco per video, con le frasi che cambiano nel tempo del video.
Si sposta e si stila come un testo; il riquadro è fisso (larghezza scelta, due righe di frase più due
di traduzione) e le frasi si appoggiano al suo fondo.
"""
from typing import List, Optional

from PyQt6.QtCore import Qt, QRectF
from PyQt6.QtGui import QColor, QFont, QFontMetricsF, QPainter, QPainterPath, QPen

from scrollr.canvas.text_item import TextItem
from scrollr.captions import balance_lines, clean_phrases, make_phrase, phrase_index_at, phrase_state
from scrollr.icons import draw_lock_badge
from scrollr.theme import THEME


class CaptionItem(TextItem):
    """Blocco di sottotitoli collegato al video `video_uid`; le frasi sono nei tempi del video originale."""
    PLACEHOLDER = "Sottotitoli"
    # Valori di partenza a livello di classe: TextItem.__init__ chiama già relayout()
    wrap_w = 860.0
    tr_size = 70
    tr_italic = True
    tr_show = True
    phrases: List[dict] = []

    def __init__(self, video_uid: int = 0, uid: Optional[int] = None):
        super().__init__("", uid)
        self.video_uid = video_uid
        self.phrases = []
        self.lang = "it"
        self.tr_lang = "en"
        self.wrap_w = 860.0
        self.tr_color = QColor(THEME["caption_translation"])
        self.tr_size = 70
        self.tr_italic = True
        self.tr_show = True
        self.bold = True
        self.shadow = True
        self.font_size = 58.0
        self._export_time: Optional[float] = None
        self._shown = None
        self._path_cache = None
        self.relayout(keep_center=False)

    # ---------- Stato ----------
    def get_state(self) -> dict:
        s = super().get_state()
        s.update(kind="caption", text="", video_uid=self.video_uid, lang=self.lang, tr_lang=self.tr_lang,
                 wrap_w=round(self.wrap_w, 1), tr_color=self.tr_color.name(QColor.NameFormat.HexArgb),
                 tr_size=self.tr_size, tr_italic=self.tr_italic, tr_show=self.tr_show,
                 phrases=[phrase_state(p) for p in self.phrases])
        return s

    def set_state(self, s: dict):
        self.video_uid = int(s.get("video_uid", 0))
        self.lang = str(s.get("lang", "it"))
        self.tr_lang = str(s.get("tr_lang", "en"))
        self.wrap_w = max(40.0, float(s.get("wrap_w", 860.0)))
        self.tr_color = QColor(s.get("tr_color", THEME["caption_translation"]))
        self.tr_size = int(s.get("tr_size", 70))
        self.tr_italic = bool(s.get("tr_italic", True))
        self.tr_show = bool(s.get("tr_show", True))
        self.phrases = clean_phrases(s.get("phrases", []))
        super().set_state(s)

    def set_phrases(self, phrases: List[dict]):
        self.phrases = clean_phrases(phrases)
        self.relayout()

    def has_translation(self) -> bool:
        return any(p.get("tr", "").strip() for p in self.phrases)

    # ---------- Tempo ----------
    def video(self):
        """Il video collegato, se è sulla tela."""
        scene = self.scene()
        if scene is None:
            return None
        return next((it for it in scene.items() if getattr(it, "uid", None) == self.video_uid
                     and hasattr(it, "trim_start")), None)

    def current_time(self) -> Optional[float]:
        """Secondo del video da mostrare: esportazione, riproduzione sulla tela o copertina."""
        if self._export_time is not None:
            return self._export_time
        v = self.video()
        if v is None:
            return None
        return v.current_time() if v.is_playing else v.poster

    def set_export_time(self, t: Optional[float]):
        self._export_time = t
        self.update()

    def refresh_time(self):
        """Chiamata dal video a ogni fotogramma: si ridisegna solo se cambia la frase."""
        t = self.current_time()
        shown = phrase_index_at(self.phrases, t) if t is not None else -1
        if shown != self._shown:
            self.update()

    # ---------- Geometria ----------
    def _tr_font(self) -> QFont:
        f = QFont(self.font_family)
        f.setPixelSize(max(4, int(round(self.font_size * self.tr_size / 100.0))))
        f.setBold(self.bold)
        f.setItalic(self.tr_italic)
        return f

    def _show_tr(self) -> bool:
        return self.tr_show and self.has_translation()

    def _content_size(self):
        fm = QFontMetricsF(self._font())
        h = fm.lineSpacing() + self._line_step(fm)
        if self._show_tr():
            tfm = QFontMetricsF(self._tr_font())
            h += self.font_size * 0.12 + tfm.lineSpacing() * 2
        return self.wrap_w, h

    # ---------- Disegno ----------
    def phrase_paths(self, phrase: dict, inner: QRectF):
        """Tracciati della frase e della traduzione, appoggiati al fondo di `inner` (in cache)."""
        tr = phrase.get("tr", "").strip() if self.tr_show else ""
        font, tfont = self._font(), self._tr_font()
        key = (phrase.get("text", ""), tr, font.toString(), tfont.toString(), self.align, self.line_height,
               inner.left(), inner.top(), inner.width(), inner.height())
        if self._path_cache is not None and self._path_cache[0] == key:
            return self._path_cache[1]
        fm, tfm = QFontMetricsF(font), QFontMetricsF(tfont)
        lines = balance_lines(phrase.get("text", ""), fm.horizontalAdvance, inner.width())
        tlines = balance_lines(tr, tfm.horizontalAdvance, inner.width()) if tr else []
        step = self._line_step(fm)
        height = fm.lineSpacing() + step * (len(lines) - 1)
        if tlines:
            height += self.font_size * 0.12 + tfm.lineSpacing() * len(tlines)
        y = inner.bottom() - height
        main, sub = QPainterPath(), QPainterPath()
        boxes = []

        def add(path, f, m, line, y):
            adv = m.horizontalAdvance(line)
            if self.align == "left":
                x = inner.left()
            elif self.align == "right":
                x = inner.right() - adv
            else:
                x = inner.left() + (inner.width() - adv) / 2.0
            path.addText(x, y + (m.lineSpacing() - m.height()) / 2.0 + m.ascent(), f, line)
            boxes.append(QRectF(x, y, adv, m.lineSpacing()))

        for line in lines:
            add(main, font, fm, line, y)
            y += step
        if tlines:
            y += fm.lineSpacing() - step + self.font_size * 0.12
            for line in tlines:
                add(sub, tfont, tfm, line, y)
                y += tfm.lineSpacing()
        result = (main, sub, boxes)
        self._path_cache = (key, result)
        return result

    def paint_phrase(self, painter: QPainter, phrase: dict, inner: QRectF):
        """Disegna una frase con lo stile del blocco (usata anche dall'anteprima della finestra Sottotitoli)."""
        if not phrase.get("text", "").strip() and not phrase.get("tr", "").strip():
            return
        main, sub, boxes = self.phrase_paths(phrase, inner)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        if self.box and boxes:
            pad = self.font_size * 0.22
            r = self.font_size * 0.18
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(self.box_color)
            for b in boxes:
                painter.drawRoundedRect(b.adjusted(-pad, -pad * 0.35, pad, pad * 0.35), r, r)
        both = QPainterPath(main)
        both.addPath(sub)
        if self.shadow:
            # Ombra morbida: alone scuro fatto di tratti sempre più sottili e appena spostati in basso
            off = self.font_size * 0.03
            shadow = both.translated(0, off)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            for width, alpha in ((0.34, 14), (0.24, 20), (0.15, 28), (0.08, 40)):
                pen = QPen(QColor(0, 0, 0, alpha), self.font_size * width)
                pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
                pen.setCapStyle(Qt.PenCapStyle.RoundCap)
                painter.strokePath(shadow, pen)
            painter.fillPath(shadow, QColor(0, 0, 0, 90))
        if self.outline > 0:
            pen = QPen(self.outline_color, self.outline * 2.0)
            pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
            painter.strokePath(both, pen)
        painter.fillPath(main, self.color)
        painter.fillPath(sub, self.tr_color)

    def paint(self, painter: QPainter, option, widget=None):
        scene = self.scene()
        exporting = bool(scene) and getattr(scene, "is_exporting", False)
        clean = exporting or (bool(scene) and getattr(scene, "clean_render", False))
        t = self.current_time()
        idx = phrase_index_at(self.phrases, t) if t is not None else -1
        self._shown = idx
        inner = self._rect.adjusted(self._pad, self._pad, -self._pad, -self._pad)
        v = None if clean else self.video()
        if idx >= 0:
            self.paint_phrase(painter, self.phrases[idx], inner)
        elif not clean and not (v is not None and v.is_playing):
            # Sulla tela, fuori dalle frasi: la prima frase in trasparenza, per vedere stile e posizione
            sample = next((p for p in self.phrases if p.get("text", "").strip()), None)
            painter.save()
            painter.setOpacity(painter.opacity() * 0.45)
            self.paint_phrase(painter, sample or make_phrase(self.PLACEHOLDER), inner)
            painter.restore()
        if clean:
            return
        accent = QColor(THEME["accent"])
        if self.isSelected():
            pen = QPen(accent, 1.5)
        elif self._hovered:
            accent.setAlpha(170)
            pen = QPen(accent, 1.0, Qt.PenStyle.DashLine)
        else:
            return
        pen.setCosmetic(True)
        painter.setPen(pen)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawRect(self._rect)
        if self.isSelected() and self.locked:
            draw_lock_badge(painter, self._view_scale())
