/// Home: elenco dei progetti. Nella Fase 0 mostra solo lo stato vuoto con l'azione «Nuovo».
library;

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Pagina iniziale dell'app.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final testi = Testi.of(context);
    final stili = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(testi.appTitolo)),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: MisureScrl.tocco,
                color: ColoriScrl.testoSecondario,
              ),
              const SizedBox(height: MisureScrl.spazio),
              Text(testi.homeVuotaTitolo, style: stili.titleMedium),
              const SizedBox(height: MisureScrl.spazioPiccolo),
              Text(testi.homeVuotaAiuto, style: stili.bodySmall),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MisureScrl.spazio),
          child: FilledButton.icon(
            onPressed: () =>
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(testi.inArrivo))),
            icon: const Icon(Icons.add),
            label: Text(testi.nuovoProgetto),
          ),
        ),
      ),
    );
  }
}
