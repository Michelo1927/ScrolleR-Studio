/// Motore di ScrolleR Studio Mobile: Dart puro, senza Flutter, provato da riga di comando.
///
/// La logica si porta 1:1 dall'app desktop (`scrollr/`), che resta la fonte di verità.
library;

export 'src/color/colore.dart';
export 'src/color/selettore.dart';
export 'src/edit/aggancio.dart';
export 'src/edit/elementi.dart';
export 'src/edit/forme.dart';
export 'src/edit/geometria_foto.dart';
export 'src/edit/ritaglio.dart';
export 'src/edit/selezione.dart';
export 'src/edit/strumenti_foto.dart';
export 'src/edit/testo.dart';
export 'src/edit/trasforma.dart';
export 'src/export/esportazione.dart';
export 'src/history/describe.dart';
export 'src/history/history.dart';
export 'src/layout/layout.dart'
    show minLayoutArea, pagePhotoCounts, seamKeep, splitRows;
export 'src/layout/layout_ops.dart';
export 'src/model/argb.dart';
export 'src/model/canvas_state.dart';
export 'src/model/context.dart';
export 'src/model/elements.dart';
export 'src/model/result.dart';
export 'src/model/scene.dart';
export 'src/model/snapshot.dart';
export 'src/pages/canvas_ops.dart';
export 'src/pages/pages.dart';
export 'src/pages/videos.dart';
export 'src/project/formato.dart';
export 'src/project/paths.dart';
export 'src/project/project_file.dart';
export 'src/util/py.dart';
export 'src/util/py_random.dart';
