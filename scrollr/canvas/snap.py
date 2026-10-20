"""Snap magnetico condiviso da foto e forme: bordi e centri di tela, pagine e altri elementi."""
from PyQt6.QtCore import QRectF

SNAP_PX = 8.0  # Distanza di snap in pixel dello schermo


def snap_selection(item, me: QRectF, view_scale: float):
    """
    Avvicina `item` (con riquadro in scena `me`) al bordo o centro più vicino entro SNAP_PX
    e sposta della stessa misura tutta la selezione. Gli elementi con snap_rect() fanno da riferimento.
    """
    scene = item.scene()
    if not (item.snap_enabled and scene and hasattr(scene, "canvas_rect")):
        if scene is not None and hasattr(scene, "set_snap_lines"):
            scene.set_snap_lines([], [])
        return

    snap_dist = SNAP_PX / max(0.01, view_scale)
    canvas = scene.canvas_rect()
    targets_x = []
    targets_y = [canvas.top(), canvas.center().y(), canvas.bottom()]
    for i in range(scene.num_frames + 1):
        fx = i * scene.frame_w
        targets_x.append(fx)
        if i < scene.num_frames:
            targets_x.append(fx + scene.frame_w / 2.0)

    for other in scene.items():
        if other is not item and hasattr(other, "snap_rect") and not other.isSelected():
            r = other.snap_rect()
            targets_x += [r.left(), r.center().x(), r.right()]
            targets_y += [r.top(), r.center().y(), r.bottom()]

    def best_offset(edges, targets):
        best = None
        for e in edges:
            for t in targets:
                d = t - e
                if abs(d) < snap_dist and (best is None or abs(d) < abs(best[0])):
                    best = (d, t)
        return best

    bx = best_offset([me.left(), me.center().x(), me.right()], targets_x)
    by = best_offset([me.top(), me.center().y(), me.bottom()], targets_y)
    off_x = bx[0] if bx else 0.0
    off_y = by[0] if by else 0.0

    if off_x or off_y:
        for it in scene.selectedItems():
            if getattr(it, "locked", True) is False:
                it.moveBy(off_x, off_y)
        if not item.isSelected():
            item.moveBy(off_x, off_y)
    scene.set_snap_lines([bx[1]] if bx else [], [by[1]] if by else [])
