TP2 - Seguridad en Sistemas Operativos
Parte 2 (AppArmor) - Guia de la carpeta de evidencias
======================================================

Todo se corrio en la VM alumno-virtualbox con el usuario alumno.
Cada .txt es lo que se copio de la terminal (comandos y salidas) y el
.png con el mismo numero es la captura de esa misma pantalla.


01_sin_perfil_dac (.txt y .png)
Que es: el estado antes de cargar el perfil.
Que muestra:
  - El grep sobre /sys/kernel/security/apparmor/profiles no devuelve nada:
    tp2-reader no tiene perfil cargado. Las lineas que aparecen debajo
    ("l.txt", "id", "/usr/local/bin/tp2-reader ...") no son salida del
    grep: son el eco de los comandos que se pegaron todos juntos mientras
    el primero todavia corria.
  - publico.txt y confidencial.txt son 0644 (root:root), cualquier
    usuario los puede leer por "otros".
  - tp2-reader lee los dos. Para DAC la lectura esta permitida.

02_complain (.txt y .png)
Que es: carga del perfil y prueba en modo complain.
Que muestra:
  - apparmor_parser -Q y -r no devuelven nada, o sea sin errores
    (sintaxis ok y perfil cargado).
  - El perfil queda "(complain)" y tp2-reader lee los dos archivos.
  - En /var/log/audit/audit.log queda apparmor="ALLOWED" sobre
    confidencial.txt: el kernel avisa que el acceso no esta en el perfil
    pero lo deja pasar. La ultima linea (pid=3302) es la de esta prueba;
    la anterior es de una corrida previa del mismo dia.
  - El journalctl -k que pide la consigna no devuelve nada. Como auditd
    esta activo, los eventos de AppArmor van a audit.log y no al journal
    del kernel.

03_enforce (.txt y .png)
Que es: la misma prueba con el perfil en modo enforce.
Que muestra:
  - publico.txt se lee.
  - confidencial.txt da Permission denied, y como root (sudo) tambien.
    AppArmor confina al programa, no importa quien lo corra.
  - En audit.log queda apparmor="DENIED" sobre confidencial.txt. Las dos
    ultimas lineas son de esta prueba: pid=3318 con fsuid=1000 (alumno)
    y pid=3320 con fsuid=0 (root). La primera es de una corrida previa.


Donde buscar cada cosa para el informe
---------------------------------------
- Analisis 3 (DAC permite, AppArmor bloquea): comparar 01 con 03.
- Analisis 4 (complain vs enforce): comparar 02 con 03.
- Por que se bloquea confidencial.txt: el perfil solo da permiso de
  lectura a publico.txt. A confidencial.txt no se le dio ninguna regla
  a proposito (tampoco un "deny"), y AppArmor niega todo lo que no esta
  permitido en el perfil.
