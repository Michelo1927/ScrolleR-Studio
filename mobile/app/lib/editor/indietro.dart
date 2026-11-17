/// «Indietro» dentro i menu dell'editor: un sottomenu aperto (una categoria della barra, il dettaglio di un parametro,
/// il selettore colore completo) si registra qui, e il gesto «indietro» di sistema torna prima al livello di sopra,
/// come il pulsante ‹ che il sottomenu mostra.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Pila dei ritorni: l'ultimo registrato è il livello più interno.
class PilaIndietro {
  final List<_Ritorno> _pila = [];

  /// Torna indietro di un livello, se c'è un sottomenu aperto; dice se l'ha fatto.
  bool indietro() {
    if (_pila.isEmpty) return false;
    _pila.last.azione();
    return true;
  }

  bool get vuota => _pila.isEmpty;
}

class _Ritorno {
  _Ritorno(this.azione);
  VoidCallback azione;
}

final pilaIndietroProvider = Provider<PilaIndietro>((ref) => PilaIndietro());

/// Registra [onIndietro] finché è montato: il gesto «indietro» di sistema lo chiama prima di chiudere lo strumento.
class RitornoLocale extends ConsumerStatefulWidget {
  const RitornoLocale({
    super.key,
    required this.onIndietro,
    required this.child,
  });

  final VoidCallback onIndietro;
  final Widget child;

  @override
  ConsumerState<RitornoLocale> createState() => _RitornoLocaleState();
}

class _RitornoLocaleState extends ConsumerState<RitornoLocale> {
  late final _Ritorno _ritorno = _Ritorno(widget.onIndietro);
  late final PilaIndietro _pila = ref.read(pilaIndietroProvider);

  @override
  void initState() {
    super.initState();
    _pila._pila.add(_ritorno);
  }

  @override
  void didUpdateWidget(RitornoLocale vecchio) {
    super.didUpdateWidget(vecchio);
    _ritorno.azione = widget.onIndietro;
  }

  @override
  void dispose() {
    _pila._pila.remove(_ritorno);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
