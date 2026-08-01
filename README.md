Riepilogo di cosa serve:

  ┌────────────────┬────────────────────────────────────────────────────────────────────────────────────────────┐
  │ File da creare │                                            Come                                            │
  ├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
  │ AppIcon.png    │ 256×256 PNG (base per tutto)                                                               │
  ├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
  │ AppIcon.icns   │ Generato dal PNG con iconutil (macOS)                                                      │
  ├────────────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
  │ AppIcon.ico    │ Convertito dal PNG con https://convertio.co o magick AppIcon.png AppIcon.ico (ImageMagick) │
  └────────────────┴────────────────────────────────────────────────────────────────────────────────────────────┘

  Flusso per piattaforma:

  - macOS — .icns nell'app bundle (già gestito)
  - Windows — .ico via app.rc → icona sull'eseguibile e nella barra delle applicazioni; WIN32_EXECUTABLE TRUE rimuove la console
  - Linux — PNG embedded come risorsa Qt (setWindowIcon) per la finestra; .desktop + cmake --install per integrazione con il
  launcher di sistema
