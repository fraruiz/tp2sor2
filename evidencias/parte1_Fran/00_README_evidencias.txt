TP2 - Seguridad en Sistemas Operativos
Parte 1 (Hardening guiado) - Guia de la carpeta de evidencias
==============================================================

Todo se corrio en la VM alumno-virtualbox con el usuario alumno, desde
la raiz del repo (~/tp2sor2), el 2026-09-30 entre las 22:40 y las 22:44.
Cada .txt es lo que se copio de la terminal (comandos y salidas) y el
.png con el mismo numero es la captura de esa misma pantalla.
Estan numerados en el orden en que se ejecutaron.

Cada linea de salida tiene el formato que escribe el script en
/var/log/tp2-hardening.log: fecha, estado (CHECK, APPLIED, SKIPPED,
ERROR, RESUMEN), control y mensaje.


01_sin_hardening (.txt y .png)
Que es: un intento previo de correr --check, --apply y --restore.
Que muestra:
  - Los tres dan "sudo: ./hardening/hardening.sh: orden no encontrada".
    El prompt dice ~/tpsor2: se corrio desde un directorio mal escrito
    (el repo esta en ~/tp2sor2), asi que sudo no encontro el script.
  - El script no llego a ejecutarse, por lo tanto no se modifico nada
    del sistema. No aporta al informe; el estado inicial real es el 02.

02_hardening_check (.txt y .png)
Que es: --check antes de aplicar el hardening (22:40:37).
Que muestra:
  - UID0 en CHECK: solo root tiene UID 0.
  - SSH, PWQUALITY, UMASK y SYSCTL en ERROR porque no existe ninguno de
    los cuatro fragmentos 99-tp2-hardening.
  - Resumen: Aplicados=0 Omitidos=0 Verificados=1 Errores=4.
  - --check solo informa: Aplicados=0, no crea ni modifica archivos.

03_hardening_apply (.txt y .png)
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

04_hardening_restore (.txt y .png)
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

05_hardening_idempotencia (.txt y .png)
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

06_hardening_validaciones (.txt y .png)
Que es: contenido de los cuatro fragmentos y comprobacion de su efecto,
con el hardening aplicado (23:09).
Que muestra:
  - SSH: el fragmento contiene "PermitRootLogin no". sshd -t no da
    errores y sshd -T (configuracion efectiva, ya con todos los
    fragmentos combinados) devuelve "permitrootlogin no".
  - PWQUALITY: el fragmento fija minlen = 12, minclass = 3 y
    maxrepeat = 3, y /etc/pam.d/common-password tiene la linea de
    pam_pwquality.so, o sea que el modulo que lee esa politica esta
    activo.
  - UMASK: el fragmento contiene "umask 027". En una sesion de login
    nueva (bash -l) la mascara es 0027 y un archivo recien creado queda
    -rw-r----- (0640): sin ningun permiso para "otros".
  - SYSCTL: el fragmento fija fs.protected_hardlinks=1 y
    fs.protected_symlinks=1. El sysctl que sigue da "permiso denegado"
    porque se corrio sin sudo y esas dos claves solo las puede leer
    root; no es una falla del hardening. Los valores efectivos los
    confirma el --check de abajo, que corre como root: "valores
    efectivos del kernel en 1".
  - --check final: los cinco controles en CHECK,
    Aplicados=0 Omitidos=0 Verificados=5 Errores=0. Es el mismo comando
    que en el 02 daba Errores=4.


Donde buscar cada cosa para el informe
---------------------------------------
- Salida de --check antes del hardening: 02.
- Primera y segunda ejecucion de --apply: 03 y 05 (el 05 tiene las dos
  juntas en una misma captura).
- Fragmentos creados y validaciones realizadas: 06.
- Demostracion de que --restore funciona: 04, mas la primera ejecucion
  del 05 (vuelve a aplicar todo porque los fragmentos ya no estaban).
- Analisis 1 (un control, riesgo que reduce y como se comprobo): el 06
  tiene la comprobacion de los cuatro. Los mas directos son SSH (sshd -T
  muestra la configuracion efectiva: root no puede entrar por SSH, hay
  que entrar con un usuario comun y escalar con sudo) y UMASK (el
  archivo nuevo queda 0640, "otros" no lo puede leer). Comparar con el
  02, donde esos mismos controles estaban en ERROR.
- Analisis 2 (idempotencia): comparar las dos ejecuciones del 05. Mismo
  comando, mismo estado final; la primera aplica lo que falta
  (Aplicados=4) y la segunda detecta que no hay nada que cambiar
  (Omitidos=4). El script decide por el contenido del archivo (grep de
  la linea esperada), no por si ya se corrio antes.
