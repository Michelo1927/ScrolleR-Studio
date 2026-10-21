"""Tema "Studio Pro": palette, font, foglio di stile QSS e stile Fusion dell'app."""
import os
import tempfile
from typing import Dict

from PyQt6.QtCore import Qt, QPointF
from PyQt6.QtGui import QPixmap, QPainter, QColor, QFont, QFontDatabase, QPolygonF, QPalette
from PyQt6.QtWidgets import QApplication


# ================= TEMA "STUDIO PRO" (stile Adobe Photoshop) =================
# Grigi neutri senza dominanti (per giudicare correttamente i colori delle foto),
# pannelli compatti con bordi netti e un unico accento blu, riservato a azioni e selezione.
# Guide in ciano e guide smart in magenta, come negli editor professionali.
THEME = {
    "frame": "#252525",      # Cornice dell'applicazione: menu, barra opzioni, strumenti, stato
    "backdrop": "#1E1E1E",   # Area di lavoro attorno alla tela (pasteboard)
    "panel": "#323232",      # Corpo dei pannelli
    "header": "#282828",     # Intestazioni a schede dei pannelli
    "field": "#1F1F1F",      # Campi di input
    "raised": "#3D3D3D",     # Pulsanti
    "hover": "#4A4A4A",
    "line": "#181818",       # Separatori scuri tra le aree
    "edge": "#4F4F4F",       # Contorni chiari di pulsanti e campi
    "text": "#DADADA",
    "muted": "#A3A3A3",
    "faint": "#696969",
    "accent": "#2680EB",
    "accent_hover": "#378EF0",
    "accent_ink": "#FFFFFF",
    "danger": "#E34850",
    "guide": "#29D5F5",
    "snap": "#FF3DCB",
}

# Colori rapidi per forme e disegni (contenuto del collage, non dell'interfaccia)
SWATCHES = [
    "#FFFFFF", "#000000", "#8E8E93", "#FF3B30", "#FF9500", "#FFCC00",
    "#34C759", "#00C7BE", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55",
]

_FONT_CACHE: Dict[str, str] = {}


def font_family(role: str = "text") -> str:
    """
    Segoe UI Variable (Windows 11) se disponibile, altrimenti Segoe UI.
    Dove Segoe non c'è (Mac, Linux) si usa il font di sistema, ad esempio San Francisco su Mac.
    """
    if role not in _FONT_CACHE:
        wanted = "Segoe UI Variable Display" if role == "display" else "Segoe UI Variable Text"
        families = set(QFontDatabase.families())
        system = QFontDatabase.systemFont(QFontDatabase.SystemFont.GeneralFont).family()
        _FONT_CACHE[role] = next((f for f in (wanted, "Segoe UI Variable", "Segoe UI") if f in families), system)
    return _FONT_CACHE[role]


def ui_font(px: int, weight: QFont.Weight = QFont.Weight.Normal, role: str = "text") -> QFont:
    f = QFont(font_family(role))
    f.setPixelSize(px)
    f.setWeight(weight)
    return f


def is_light(color: QColor) -> bool:
    return (0.299 * color.red() + 0.587 * color.green() + 0.114 * color.blue()) > 150


def build_stylesheet() -> str:
    """Foglio di stile QSS dell'app, con i colori del tema al posto dei segnaposto @nome."""
    qss = """
        QWidget {
            color: @text;
            font-family: '@font';
            font-size: 12px;
        }
        QMainWindow, #Root {
            background-color: @frame;
        }
        QToolTip {
            background-color: @panel;
            color: @text;
            border: 1px solid @edge;
            border-radius: 2px;
            padding: 4px 7px;
        }

        /* ---- Barra dei menu e menu ---- */
        QMenuBar {
            background-color: @frame;
            color: @text;
            border-bottom: 1px solid @line;
            padding: 0 4px;
        }
        QMenuBar::item {
            padding: 5px 9px;
            background: transparent;
        }
        QMenuBar::item:selected, QMenuBar::item:pressed {
            background-color: @hover;
        }
        #AppBadge {
            background-color: @field;
            border: 1px solid @line;
            border-radius: 3px;
            margin: 2px 4px 2px 6px;
        }
        QMenu {
            background-color: @panel;
            border: 1px solid @line;
            padding: 4px 0;
        }
        QMenu::item {
            padding: 5px 28px 5px 14px;
            background: transparent;
        }
        QMenu::item:selected {
            background-color: @accent;
            color: @accent_ink;
        }
        QMenu::item:disabled {
            color: @faint;
        }
        QMenu::separator {
            height: 1px;
            background: @edge;
            margin: 4px 0;
        }
        QMenu::icon {
            padding-left: 6px;
        }

        /* ---- Barra opzioni, colonna strumenti, pannelli ---- */
        #OptionsBar {
            background-color: @frame;
            border-bottom: 1px solid @line;
        }
        #ToolStrip {
            background-color: @frame;
            border-right: 1px solid @line;
        }
        #ToolSep {
            background-color: @edge;
            margin: 0 6px;
        }
        #Dock {
            background-color: @panel;
        }
        #DockHeader, #DocTabBar {
            background-color: @header;
            border-bottom: 1px solid @line;
        }
        #DockTab {
            background-color: @panel;
            color: @text;
            font-weight: 600;
            font-size: 11px;
            padding: 0 14px;
            border-right: 1px solid @line;
        }
        #DocArea {
            background-color: @backdrop;
        }
        #DocTab {
            background-color: @panel;
            color: @text;
            font-size: 11px;
            padding: 0 16px;
            border-right: 1px solid @line;
        }
        #PanelScroll, #PanelScroll > QWidget {
            background: transparent;
        }
        QWidget#Panel {
            background-color: @panel;
        }
        QSplitter::handle {
            background: @line;
        }
        #Divider {
            background-color: @line;
        }
        #VSep {
            background-color: @edge;
        }

        /* ---- Testi ---- */
        #Brand {
            font-family: '@display';
            font-size: 14px;
            font-weight: 600;
        }
        #SectionTitle {
            font-size: 11px;
            font-weight: 700;
            color: @text;
            padding-top: 2px;
        }
        #FieldLabel {
            color: @muted;
            font-size: 11px;
        }
        #Hint {
            color: @muted;
            font-size: 11px;
        }
        #EmptyTitle {
            font-size: 13px;
            font-weight: 600;
        }
        #SelName {
            font-weight: 600;
            font-size: 12px;
        }
        #ValueChip {
            color: @text;
            background-color: @field;
            border: 1px solid @line;
            border-radius: 2px;
            padding: 1px 6px;
            min-width: 34px;
            font-size: 11px;
            qproperty-alignment: AlignCenter;
        }
        #StatusText {
            color: @muted;
            font-size: 11px;
            padding: 0 6px;
        }
        QStatusBar {
            background-color: @frame;
            border-top: 1px solid @line;
            padding: 0 6px;
            min-height: 24px;
        }
        QStatusBar::item {
            border: none;
        }

        /* ---- Pulsanti (pillole con contorno; azione primaria blu piena) ---- */
        QPushButton {
            background-color: transparent;
            border: 1px solid #707070;
            border-radius: 12px;
            padding: 4px 12px;
            min-height: 16px;
            font-weight: 600;
        }
        QPushButton:hover {
            background-color: @hover;
            border-color: #9A9A9A;
        }
        QPushButton:pressed {
            background-color: @field;
        }
        QPushButton:disabled {
            color: @faint;
            border-color: @hover;
        }
        QPushButton:focus {
            outline: none;
        }
        QPushButton#Primary {
            background-color: @accent;
            border: 1px solid @accent;
            color: @accent_ink;
            padding: 4px 16px;
        }
        QPushButton#Primary:hover {
            background-color: @accent_hover;
            border-color: @accent_hover;
        }
        QPushButton#Primary:disabled, QPushButton#Ghost:disabled, QPushButton#Danger:disabled {
            background-color: transparent;
            border-color: @hover;
            color: @faint;
        }
        QPushButton#Primary::menu-indicator {
            image: none;
            width: 0;
        }
        QPushButton#Ghost {
            border-color: @edge;
            color: @muted;
            font-weight: 500;
        }
        QPushButton#Ghost:hover {
            color: @text;
            border-color: #8A8A8A;
        }
        QPushButton#Danger {
            border-color: @edge;
            color: @danger;
        }
        QPushButton#Danger:hover {
            background-color: rgba(227, 72, 80, 0.14);
            border-color: @danger;
        }
        QToolButton {
            border: none;
            background: transparent;
        }
        QToolButton#IconButton {
            border: 1px solid transparent;
            border-radius: 2px;
            padding: 2px 5px;
            color: @text;
        }
        QToolButton#IconButton:hover {
            background-color: @hover;
        }
        QToolButton#IconButton:pressed {
            background-color: @field;
        }
        QToolButton#ToolButton {
            border: 1px solid transparent;
            border-radius: 3px;
            color: @text;
            font-size: 11px;
            padding: 3px 0 2px 0;
        }
        QToolButton#ToolButton::menu-indicator {
            image: none;
            width: 0;
        }
        QToolButton#ToolButton:disabled {
            color: @faint;
        }
        QToolButton#ToolButton[danger="true"] {
            color: @danger;
        }
        QToolButton#ToolButton[danger="true"]:disabled {
            color: @faint;
        }
        #ToolCaption {
            color: @faint;
            font-size: 10px;
            font-weight: 600;
            padding: 2px 0 1px 0;
        }
        QToolButton#ToolButton:hover {
            background-color: @hover;
        }
        QToolButton#ToolButton:pressed {
            background-color: @field;
            border-color: @line;
        }
        QToolButton#ColorChip {
            border: 1px solid transparent;
            border-radius: 2px;
            padding: 1px;
        }
        QToolButton#ColorChip:hover {
            border-color: @edge;
        }
        QToolButton#ColorChip:checked {
            border-color: @accent;
            background-color: rgba(38, 128, 235, 0.22);
        }
        QToolButton#ToggleButton {
            border: 1px solid transparent;
            border-radius: 2px;
            padding: 2px 8px;
            color: @muted;
        }
        QToolButton#ToggleButton:hover {
            background-color: @hover;
        }
        QToolButton#ToggleButton:checked {
            color: @text;
            background-color: @field;
            border-color: @line;
        }
        QToolButton#SoftButton {
            background-color: @raised;
            border: 1px solid @line;
            border-radius: 2px;
            padding: 4px 6px;
            color: @text;
            font-size: 11px;
        }
        QToolButton#SoftButton:hover {
            background-color: @hover;
        }
        QToolButton#SoftButton:pressed {
            background-color: @field;
        }
        QToolButton#SoftButton:checked {
            background-color: rgba(38, 128, 235, 0.22);
            border-color: @accent;
            color: @text;
        }
        QToolButton#SoftButton:disabled {
            color: @faint;
        }
        QToolButton#SegTab {
            background-color: @field;
            border: 1px solid @line;
            border-left: none;
            color: @muted;
            font-size: 11px;
            padding: 3px 0;
        }
        QToolButton#SegTab:hover {
            color: @text;
        }
        QToolButton#SegTab:checked {
            background-color: @raised;
            color: @text;
            font-weight: 600;
            border-bottom: 2px solid @accent;
        }
        QPlainTextEdit {
            background-color: @field;
            border: 1px solid @line;
            border-radius: 2px;
            padding: 4px;
            selection-background-color: @accent;
        }
        QPlainTextEdit:focus {
            border-color: @accent;
        }
        QDialog {
            background-color: @panel;
        }
        QRadioButton {
            spacing: 8px;
            padding: 2px 0;
        }
        QRadioButton::indicator {
            width: 14px;
            height: 14px;
            border-radius: 8px;
            border: 1px solid @edge;
            background-color: @field;
        }
        QRadioButton::indicator:checked {
            border: 1px solid @accent;
            background-color: qradialgradient(cx: 0.5, cy: 0.5, radius: 0.5, fx: 0.5, fy: 0.5,
                stop: 0 #FFFFFF, stop: 0.32 #FFFFFF, stop: 0.42 @accent, stop: 1 @accent);
        }
        QToolButton#LayoutTile {
            background-color: @field;
            border: 1px solid @line;
            border-radius: 2px;
            padding: 4px 2px 3px 2px;
            color: @muted;
            font-size: 11px;
        }
        QToolButton#LayoutTile:hover {
            border-color: @edge;
            color: @text;
        }
        QToolButton#LayoutTile:checked {
            background-color: rgba(38, 128, 235, 0.22);
            border-color: @accent;
            color: @text;
            font-weight: 600;
        }

        /* ---- Campi ---- */
        QComboBox, QSpinBox {
            background-color: @field;
            border: 1px solid @line;
            border-radius: 2px;
            padding: 3px 8px;
            min-height: 18px;
            selection-background-color: @accent;
        }
        QComboBox:hover, QSpinBox:hover {
            border-color: @edge;
        }
        QComboBox:focus, QSpinBox:focus {
            border-color: @accent;
        }
        QComboBox::drop-down {
            border: none;
            width: 18px;
        }
        QComboBox::down-arrow {
            image: url(@arrow);
            width: 9px;
            height: 9px;
            margin-right: 4px;
        }
        QComboBox QAbstractItemView {
            background-color: @panel;
            border: 1px solid @line;
            padding: 2px 0;
            outline: none;
            selection-background-color: @accent;
            selection-color: @accent_ink;
        }

        /* ---- Libreria a miniature ---- */
        QListWidget {
            background-color: @field;
            border: 1px solid @line;
            border-radius: 0;
            outline: none;
        }
        QListWidget::item {
            border: 1px solid transparent;
            padding: 1px;
        }
        QListWidget::item:hover {
            background-color: @hover;
        }
        QListWidget::item:selected {
            background-color: rgba(38, 128, 235, 0.30);
            border-color: @accent;
        }

        /* ---- Slider ---- */
        QSlider {
            min-height: 18px;
        }
        QSlider::groove:horizontal {
            height: 2px;
            background: #5C5C5C;
            border-radius: 1px;
        }
        QSlider::sub-page:horizontal {
            background: #B4B4B4;
            border-radius: 1px;
        }
        QSlider::handle:horizontal {
            background: @panel;
            border: 2px solid #B4B4B4;
            width: 10px;
            height: 10px;
            margin: -6px 0;
            border-radius: 7px;
        }
        QSlider::handle:horizontal:hover {
            border-color: #FFFFFF;
        }
        QSlider::handle:horizontal:pressed {
            border-color: @accent;
        }
        QSlider::sub-page:horizontal:disabled {
            background: @faint;
        }
        QSlider#Signed::sub-page:horizontal {
            background: #5C5C5C;
        }

        /* ---- Barre di scorrimento ---- */
        QScrollBar:vertical {
            background: @panel;
            width: 10px;
            margin: 0;
        }
        QScrollBar::handle:vertical {
            background: @hover;
            border-radius: 3px;
            min-height: 30px;
            margin: 2px;
        }
        QScrollBar::handle:vertical:hover {
            background: #6A6A6A;
        }
        QScrollBar:horizontal {
            background: @panel;
            height: 10px;
            margin: 0;
        }
        QScrollBar::handle:horizontal {
            background: @hover;
            border-radius: 3px;
            min-width: 30px;
            margin: 2px;
        }
        QScrollBar::handle:horizontal:hover {
            background: #6A6A6A;
        }
        QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page {
            background: none;
            height: 0;
            width: 0;
        }
        QAbstractScrollArea::corner {
            background: @panel;
        }
        /* Pagine a scacchiera: stesso fondo della zona di lavoro attorno alla tela */
        QScrollArea#PageGridArea, QWidget#PageGrid {
            background-color: @backdrop;
            border: none;
        }

        /* ---- Finestre di dialogo ---- */
        QMessageBox, QProgressDialog, QColorDialog {
            background-color: @panel;
        }
        QProgressBar {
            background-color: @field;
            border: 1px solid @line;
            border-radius: 2px;
            height: 6px;
            text-align: center;
            color: transparent;
        }
        QProgressBar::chunk {
            background-color: @accent;
            border-radius: 1px;
        }
    """
    # Freccina delle tendine: disegnata al volo e salvata come immagine temporanea per il QSS
    arrow_path = os.path.join(tempfile.gettempdir(), "scrl_studio_arrow.png")
    arrow = QPixmap(18, 18)
    arrow.fill(Qt.GlobalColor.transparent)
    ap = QPainter(arrow)
    ap.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    ap.setPen(Qt.PenStyle.NoPen)
    ap.setBrush(QColor(THEME["muted"]))
    ap.drawPolygon(QPolygonF([QPointF(2, 5), QPointF(16, 5), QPointF(9, 13)]))
    ap.end()
    arrow.save(arrow_path, "PNG")
    tokens = dict(THEME, font=font_family("text"), display=font_family("display"),
                  arrow=arrow_path.replace("\\", "/"))
    for key in sorted(tokens, key=len, reverse=True):
        qss = qss.replace("@" + key, tokens[key])
    return qss


def apply_app_style(app: QApplication):
    """Stile Fusion con palette scura coerente, così anche le finestre di dialogo seguono il tema."""
    app.setStyle("Fusion")
    pal = QPalette()
    roles = {
        QPalette.ColorRole.Window: THEME["panel"],
        QPalette.ColorRole.WindowText: THEME["text"],
        QPalette.ColorRole.Base: THEME["field"],
        QPalette.ColorRole.AlternateBase: THEME["panel"],
        QPalette.ColorRole.Text: THEME["text"],
        QPalette.ColorRole.Button: THEME["raised"],
        QPalette.ColorRole.ButtonText: THEME["text"],
        QPalette.ColorRole.Highlight: THEME["accent"],
        QPalette.ColorRole.HighlightedText: THEME["accent_ink"],
        QPalette.ColorRole.ToolTipBase: THEME["raised"],
        QPalette.ColorRole.ToolTipText: THEME["text"],
        QPalette.ColorRole.PlaceholderText: THEME["faint"],
    }
    for role, color in roles.items():
        pal.setColor(role, QColor(color))
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.Text, QColor(THEME["faint"]))
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.ButtonText, QColor(THEME["faint"]))
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.WindowText, QColor(THEME["faint"]))
    app.setPalette(pal)
    app.setFont(ui_font(12))
