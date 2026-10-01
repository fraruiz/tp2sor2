TP2 - Seguridad en Sistemas Operativos
Parte 1 (Hardening guiado) - Guia de la carpeta de evidencias
==============================================================

Todo se corrio en la VM alumno-virtualbox con el usuario alumno, desde
la raiz del repo (~/tp2sor2), el 2026-09-30 entre las 22:40 y las 22:44.
Cada .png es la captura de la terminal con el comando y su salida.
Las capturas estan numeradas en el orden en que se ejecutaron.

Cada linea de salida tiene el formato que escribe el script en
/var/log/tp2-hardening.log: fecha, estado (CHECK, APPLIED, SKIPPED,
ERROR, RESUMEN), control y mensaje.


01_sin_hardening (.png)
Que es: un intento previo de correr --check, --apply y --restore.
Que muestra:
  - Los tres dan "sudo: ./hardening/hardening.sh: orden no encontrada".
    El prompt dice ~/tpsor2: se corrio desde un directorio mal escrito
    (el repo esta en ~/tp2sor2), asi que sudo no encontro el script.
  - El script no llego a ejecutarse, por lo tanto no se modifico nada
    del sistema. No aporta al informe; el estado inicial real es el 02.

02_hardening_check (.png)
Que es: --check antes de aplicar el hardening (22:40:37).
Que muestra:
  - UID0 en CHECK: solo root tiene UID 0.
  - SSH, PWQUALITY, UMASK y SYSCTL en ERROR porque no existe ninguno de
    los cuatro fragmentos 99-tp2-hardening.
  - Resumen: Aplicados=0 Omitidos=0 Verificados=1 Errores=4.
  - --check solo informa: Aplicados=0, no crea ni modifica archivos.

03_hardening_apply (.png)
Que es: primera ejecucion de --apply (22:41:57).
Que muestra:
  - Los cuatro controles en APPLIED. Se crean:
      /etc/ssh/sshd_config.d/99-tp2-hardening.conf       (y ssh recargado)
      /etc/security/pwquality.conf.d/99-tp2-hardening.conf
      /etc/profile.d/99-tp2-hardening.sh
      /etc/sysctl.d/99-tp2-hardening.conf   (y valores aplicados en caliente)
  - Que SSH figure como APPLIED implica que sshd -t paso antes de
    recargar: si la validacion falla, el script registra ERROR y no
    recarga el servicio.
  - UID0 sigue en CHECK: es un control de diagnostico, no corrige nada.
  - Resumen: Aplicados=4 Omitidos=0 Verificados=1 Errores=0.

04_hardening_restore (.png)
Que es: --restore despues del primer --apply (22:43:01).
Que muestra:
  - Para cada fragmento, una linea RESTORE "Eliminado ... porque no
    existia antes del TP". Como en el estado original no habia ninguno
    de los cuatro archivos, restaurar significa borrarlos, no reponer un
    respaldo.
  - SSH se vuelve a recargar despues de eliminar su fragmento.
  - Resumen: Aplicados=8 Omitidos=0 Verificados=1 Errores=0. Son 8 y no
    4 porque cada control registra dos lineas APPLIED: una de
    restore_file (RESTORE) y otra del propio control (SSH, PWQUALITY,
    UMASK, SYSCTL). Son 4 archivos restaurados, contados dos veces.

05_hardening_idempotencia (.png)
Que es: dos ejecuciones seguidas de --apply despues del restore
(22:44:08 y 22:44:12).
Que muestra:
  - Primera: otra vez cuatro APPLIED, Aplicados=4 Omitidos=0. Esto
    confirma que el --restore del 04 realmente habia eliminado los
    fragmentos: si hubieran quedado, aca saldrian como SKIPPED.
  - Segunda, 4 segundos despues: cuatro SKIPPED ("ya establece ...",
    "ya fija ambos valores"), Aplicados=0 Omitidos=4. No reescribe
    archivos ni recarga ssh.
  - En las dos, Errores=0.
  - La VM quedo con el hardening aplicado al terminar esta captura.


Donde buscar cada cosa para el informe
---------------------------------------
- Salida de --check antes del hardening: 02.
- Primera y segunda ejecucion de --apply: 03 y 05 (el 05 tiene las dos
  juntas en una misma captura).
- Demostracion de que --restore funciona: 04, mas la primera ejecucion
  del 05 (vuelve a aplicar todo porque los fragmentos ya no estaban).
- Analisis 2 (idempotencia): comparar las dos ejecuciones del 05. Mismo
  comando, mismo estado final; la primera aplica lo que falta
  (Aplicados=4) y la segunda detecta que no hay nada que cambiar
  (Omitidos=4). El script decide por el contenido del archivo (grep de
  la linea esperada), no por si ya se corrio antes.
