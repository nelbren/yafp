# Fonts with consistent Unicode fallback

## Iconos del prompt

Las etiquetas estáticas usan Font Awesome mediante Nerd Fonts en Bash, zsh y
PowerShell. La terminal local debe usar una Nerd Font que incluya estos
códigos, también al mostrar una sesión SSH. Python y `user-shield` usan los
códigos remapeados de Nerd Fonts, no los puntos de código de la fuente
original de Font Awesome.

| N.º | Uso                             | Icono       | Código Nerd Fonts    |
| --- | ------------------------------- | ----------- | -------------------- |
| 1   | Advertencia                     | ``         | `F071`               |
| 2   | Error                           | ``         | `F057`               |
| 3   | Éxito                           | ``         | `F058`               |
| 4   | Git: eliminados                 | ``         | `F1F8`               |
| 5   | Git: modificados                | ``         | `F044`               |
| 6   | Git: nuevos                     | ``         | `F0FE`               |
| 7   | Git: preparados para commit     | ``         | `F187`               |
| 8   | Python                          | ``         | `ED1B`               |
| 9   | Usuario                         | ``         | `F007`               |
| 10  | Administrador                   | ``         | `EDCF`               |
| 11  | Equipo local / cliente SSH      | ` / `     | `F108 / F109`        |
| 12  | Ubicación local en minimal      | ``         | `F015`               |
| 13  | Comando anterior en default     | ``         | `F120`               |
| 14  | Remoto / temporizador           | ``         | `F0E7`               |
| 15  | Rendimiento: rápido/medio/lento | ` /  / ` | `F135 / F2F2 / F252` |
| 16  | Contexto general de depuración  | ``         | `F013`               |
| 17  | Contexto Git de depuración      | ``         | `F1D3`               |
| 18  | Urgencia del próximo chequeo    | ``         | `F111`               |

El catálogo corresponde a los reemplazos aprobados; cada tema conserva las
etiquetas que ya mostraba. Por ejemplo, el entorno de `default` en Bash/zsh
mantiene su nombre entre corchetes, y `light` conserva `✓`, `☒`, `↯` y los
contadores numéricos. El círculo del temporizador mantiene los colores verde,
amarillo y rojo junto al porcentaje y los segundos. No se cambian los
umbrales, los colores ni la lógica.

Se conservan los indicadores Braille, `֍`, `` para refresco en segundo plano,
`⟳` para datos iniciales pendientes, los marcos y los momentos del día. La
sustitución afecta a la decoración de YAFP; los emojis escritos en comandos,
rutas, ramas o nombres de entornos permanecen intactos. Los mensajes de las
herramientas de instalación, doctor y calidad conservan sus símbolos de texto.

`yafp-status` y `yafp-demo` usan `` (`U+F0AC`) para el remoto, ``
(`U+F058`) para el estado al día, `` (`U+F017`) para la hora actual y ``
(`U+F274`) para la próxima revisión. Las etiquetas del informe quedan
alineadas y conservan los colores y la salida `unavailable`. La vista previa
se anuncia con `` (`U+F120`); el recordatorio de `Ctrl+C` usa ``
(`U+EDFE`, infinito remapeado por Nerd Fonts) y `` (`U+F021`, refresco).
El intervalo del bucle sigue siendo de cuatro segundos.

El cuadro de `yafp-codex` usa `` (`U+F274`) para el restablecimiento,
`` (`U+F21E`, heartbeat) para el estado y `` (`U+F200`, chart-pie) para la
cuota restante. Los estados usan `` (`U+F058`) para `ok`, `` (`U+F252`)
para `pending`, `` (`U+F204`) para `disabled`, `` (`U+F023`) para
`logged-out`, `` (`U+F05E`) para `unsupported-auth`, `` (`U+F071`) para
dependencias ausentes, `` (`U+F017`) para `timeout` y `` (`U+F057`) para
`unavailable`. Los datos no disponibles de `Reset` y `Remaining` usan ``
(`U+F059`, question-circle) en gris. Los nombres de estado acompañan los iconos
incluso sin color.

El informe `yafp-resources` añade `` (`U+EFC5`, memory, remapeado por Nerd
Fonts) para RAM. CPU usa `` (`U+F2DB`), SWAP `` (`U+F0EC`) y disco ``
(`U+F0A0`). El estado reutiliza `` (`U+F21E`), la edad `` (`U+F017`) y los
valores ausentes `` (`U+F059`) en gris. El refresco `` y sus datos en caché
conservan el significado del monitor.

Referencias: [Font Awesome][font-awesome] y [catálogo Nerd Fonts][nerd-glyphs].

[font-awesome]: https://github.com/FortAwesome/Font-Awesome/blob/6.7.2/css/all.css
[nerd-glyphs]: https://github.com/ryanoasis/nerd-fonts/blob/master/glyphnames.json

## Preview sample

Las capturas siguientes conservan esta muestra histórica, anterior a los
reemplazos de iconos del catálogo actual.

<!-- markdownlint-disable MD013 -->
```less
🪟 nelbren↤[֍⣿4d21h] @ NDEV-DPC-02↦[⚙⣄▦⣀⇄⡀◉⣿] ⌂ ~\yafp ↦[⣦✓🌐︎] master↯↦[±1+1] ⧖ 2026-10-30 09:03:27 ✓
$
```
<!-- markdownlint-enable MD013 -->

1. ### [Ioskeley Mono][preview-ioskeley]

   #### ④ Logos — Ioskeley Mono

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |4/4|✓|✓|✓|✓|

   ![YAFP macOS with Ioskeley Mono](images/fonts/ioskeley-macOS.png)

2. ### [Cozette][preview-cozette]

   #### ④ Logos — Cozette

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |4/4|✓|✓|✓|✓|

   ![YAFP macOS with Cozette](images/fonts/cozette-macOS.png)

3. ### [Aporetic Sans Mono][preview-aporetic-sans]

   #### ¾ Logos — Aporetic Sans Mono

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |==3/4==|✓|✓|==✗==|✓|

   ![YAFP macOS with Aporetic Sans Mono](images/fonts/aporetic-sans-macOS.png)

4. ### [psudoFont Liga Mono][preview-psudo]

   #### ¾ Logos — psudoFont Liga Mono

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |==3/4==|✓|✓|==✗==|✓|

   ![YAFP macOS with psudoFont Liga Mono](images/fonts/psudo-macOS.png)

5. ### [Adwaita Mono][preview-adwaita-mono]

   #### ¾ Logos — Adwaita Mono

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |==3/4==|✓|✓|==✗==|✓|

   ![YAFP macOS with Adwaita Mono](images/fonts/adwaita-mono-macOS.png)

6. ### [Monofoki][preview-monofoki]

   #### ¾ Logos — Monofoki

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |==3/4==|✓|✓|==✗==|✓|

   ![YAFP macOS with Monofoki](images/fonts/monofoki-macOS.png)

7. ### [JuliaMono][preview-julia-mono]

   #### ¾ Logos — JuliaMono

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |==3/4==|✓|✓|==✗==|✓|

   ![YAFP macOS with JuliaMono](images/fonts/julia-mono-macOS.png)

8. ### [JetBrains Mono][preview-jetbrainsmono]

   #### ¾ Logos — JetBrains Mono

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |==3/4==|✓|✓|==✗==|✓|

   ![YAFP macOS with JetBrains Mono](images/fonts/jetbrainsmono-macOS.png)

9. ### [Lilex][preview-lilex]

   #### ¾ Logos — Lilex

   |OS|macOS|Windows|Debian|Kali|
   |:--:|:--:|:--:|:--:|:--|
   |==3/4==|✓|✓|==✗==|✓|

   ![YAFP macOS with Lilex](images/fonts/lilex-macOS.png)

10. ### [Victor Mono][preview-victor-mono]

    #### ¾ Logos — Victor Mono

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Victor Mono](images/fonts/victor-mono-macOS.png)

11. ### [Proggy Vector][preview-proggy-vector]

    #### ¾ Logos — Proggy Vector

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP preview with Proggy Vector](images/fonts/proggy-vector-macOS.png)

12. ### [Spleen][preview-spleen]

    #### ¾ Logos — Spleen

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Spleen](images/fonts/spleen-macOS.png)

13. ### [D2Coding][preview-d2coding]

    #### ¾ Logos — D2Coding

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with D2Coding](images/fonts/d2coding-macOS.png)

14. ### [Bront DejaVu Sans Mono][preview-bront-dejavu]

    #### ¾ Logos — Bront DejaVu Sans Mono

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Bront DejaVu Sans Mono](images/fonts/bront-dejavu-macOS.png)

15. ### [Bront Ubuntu Mono][preview-bront-ubuntu]

    #### ¾ Logos — Bront Ubuntu Mono

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Bront Ubuntu Mono](images/fonts/bront-ubuntu-macOS.png)

16. ### [IBM 3270][preview-font3270]

    #### ¾ Logos — IBM 3270

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with IBM 3270](images/fonts/font3270-macOS.png)

17. ### [Monoid][preview-monoid]

    #### ¾ Logos — Monoid

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Monoid](images/fonts/monoid-macOS.png)

18. ### [Iosevka][preview-iosevka]

    #### ¾ Logos — Iosevka

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Iosevka](images/fonts/iosevka-macOS.png)

19. ### [Hack][preview-hack]

    #### ¾ Logos — Hack

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Hack](images/fonts/hack-macOS.png)

20. ### [Hack Ligatured][preview-hack-ligatured]

    #### ¾ Logos — Hack Ligatured

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|==✗==|✓|✓|✓|

    ![YAFP macOS with Hack Ligatured](images/fonts/hack-ligatured-macOS.png)

21. ### [Office Code Pro][preview-office-code-pro]

    #### ¾ Logos — Office Code Pro

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Office Code Pro](images/fonts/office-code-pro-macOS.png)

22. ### [Fira Code][preview-firacode]

    #### ¾ Logos — Fira Code

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Fira Code](images/fonts/firacode-macOS.png)

23. ### [Hasklig][preview-hasklig]

    #### ¾ Logos — Hasklig

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Hasklig](images/fonts/hasklig-macOS.png)

24. ### [mononoki][preview-mononoki]

    #### ¾ Logos — mononoki

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with mononoki](images/fonts/mononoki-macOS.png)

25. ### [Fantasque Sans Mono][preview-fantasque-sans]

    #### ¾ Logos — Fantasque Sans Mono

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Fantasque Sans Mono](images/fonts/fantasque-sans-macOS.png)

26. ### [Hermit][preview-hermit]

    #### ¾ Logos — Hermit

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Hermit](images/fonts/hermit-macOS.png)

27. ### [Source Code Pro][preview-source-code-pro]

    #### ¾ Logos — Source Code Pro

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Source Code Pro](images/fonts/source-code-pro-macOS.png)

28. ### [Sudo][preview-sudo]

    #### ¾ Logos — Sudo

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Sudo](images/fonts/sudo-macOS.png)

29. ### [Luculent][preview-luculent]

    #### ¾ Logos — Luculent

    |OS|macOS|Windows|Debian|Kali|
    |:--:|:--:|:--:|:--:|:--|
    |==3/4==|✓|✓|==✗==|✓|

    ![YAFP macOS with Luculent](images/fonts/luculent-macOS.png)

[preview-aporetic-sans]: https://www.programmingfonts.org/#aporetic-sans
[preview-psudo]: https://www.programmingfonts.org/#psudo
[preview-ioskeley]: https://www.programmingfonts.org/#ioskeley
[preview-adwaita-mono]: https://www.programmingfonts.org/#adwaita-mono
[preview-monofoki]: https://www.programmingfonts.org/#monofoki
[preview-julia-mono]: https://www.programmingfonts.org/#julia-mono
[preview-cozette]: https://www.programmingfonts.org/#cozette
[preview-jetbrainsmono]: https://www.programmingfonts.org/#jetbrainsmono
[preview-lilex]: https://www.programmingfonts.org/#lilex
[preview-victor-mono]: https://www.programmingfonts.org/#victor-mono
[preview-proggy-vector]: https://www.programmingfonts.org/#proggy-vector
[preview-spleen]: https://www.programmingfonts.org/#spleen
[preview-d2coding]: https://www.programmingfonts.org/#d2coding
[preview-bront-dejavu]: https://www.programmingfonts.org/#bront-dejavu
[preview-bront-ubuntu]: https://www.programmingfonts.org/#bront-ubuntu
[preview-font3270]: https://www.programmingfonts.org/#font3270
[preview-monoid]: https://www.programmingfonts.org/#monoid
[preview-iosevka]: https://www.programmingfonts.org/#iosevka
[preview-hack]: https://www.programmingfonts.org/#hack
[preview-hack-ligatured]: https://www.programmingfonts.org/#hack-ligatured
[preview-office-code-pro]: https://www.programmingfonts.org/#office-code-pro
[preview-firacode]: https://www.programmingfonts.org/#firacode
[preview-hasklig]: https://www.programmingfonts.org/#hasklig
[preview-mononoki]: https://www.programmingfonts.org/#mononoki
[preview-fantasque-sans]: https://www.programmingfonts.org/#fantasque-sans
[preview-hermit]: https://www.programmingfonts.org/#hermit
[preview-source-code-pro]: https://www.programmingfonts.org/#source-code-pro
[preview-sudo]: https://www.programmingfonts.org/#sudo
[preview-luculent]: https://www.programmingfonts.org/#luculent

<!-- markdownlint-disable MD033 -->
<div style="text-align: right; font-size: 12px;">
📆 2026-11-02 23:09:10 🍎 MBP02 |
֎ OpenAI 🤖 Codex 🧠 GPT-6 No expuesto & 👨🏻‍💻 Nelbren ©️ 2026
</div>
