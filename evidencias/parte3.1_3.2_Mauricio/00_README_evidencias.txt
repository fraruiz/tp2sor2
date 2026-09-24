TP2 - Seguridad en Sistemas Operativos
Parte 3 (Auditoria + strace) - Guia de la carpeta de evidencias
==================================================================

Este archivo explica que muestra cada evidencia, para quien arme el
informe no tenga que reconstruir el razonamiento mirando los .txt crudos.


00_baseline.txt
----------------
Que es: la salida de /var/lib/tp2-lab/baseline.txt, generada automaticamente
por preparar_entorno.sh justo al terminar de preparar la VM.

Que muestra: fecha de la preparacion, hostname, version de kernel, sistema
operativo, y el estado de AppArmor y de auditd en ese momento exacto.

Para que sirve: es la foto del entorno "recien salido del horno", antes de
que nadie del grupo tocara hardening, AppArmor, auditd o AIDE. Sirve como
punto de referencia inicial en el informe (Paso 0, individual y obligatorio
para todo el grupo).


01_reglas_cargadas.txt
------------------------
Que es: la salida de "sudo auditctl -l | grep tp2".

Que muestra: las dos reglas de auditoria efectivamente activas en el
kernel en ese momento:
  -w /srv/tp2/datos -p wa -k tp2_datos
  -a always,exit -F arch=b64 -S execve -F path=/usr/local/bin/tp2-event -F key=tp2_exec

Para que sirve: prueba que las reglas no solo estan escritas en el archivo
audit/99-tp2.rules, sino que el kernel las tiene cargadas y funcionando
(auditctl -l lee directamente del kernel, no del archivo).


02_ausearch_tp2_datos.txt
----------------------------
Que es: la salida de "sudo ausearch -k tp2_datos -ts recent", despues de
disparar manualmente una escritura y un cambio de permisos sobre
/srv/tp2/datos/publico.txt.

Que muestra: tres eventos con key="tp2_datos":
  - dos con syscall=257 (openat), generados por "tee -a" al escribir en
    publico.txt -> demuestran la parte de ESCRITURA ("w") de la regla.
  - uno con syscall=268 (fchmodat), generado por "chmod 0640" sobre el
    mismo archivo -> demuestra la parte de CAMBIO DE ATRIBUTOS ("a") de
    la regla.

Para que sirve: confirma que la regla -p wa funciona completa, sus dos
mitades (escritura y atributos), no solo una.


03_strace_tp2event.txt
-------------------------
Que es: trace completo de syscalls (con "strace -tt", timestamps de
microsegundos) de una ejecucion de /usr/local/bin/tp2-event.

Que muestra: la PRIMERA linea del archivo es el execve() que lanza el
programa, con el binario y el argumento exactos con los que se lo llamo
(ej: execve("/usr/local/bin/tp2-event", ["/usr/local/bin/tp2-event",
"correlacion_demo_..."], ...)). El resto del archivo son las syscalls
internas del programa (abrir el log, escribir, cerrar el archivo).

Para que sirve: es la evidencia "en el momento", vista desde afuera del
proceso via ptrace. Es la pieza que se correlaciona con 04 y 05 para el
Analisis 5.


04_eventos_log.txt
---------------------
Que es: la ultima linea de /srv/tp2/datos/eventos.log, el log propio de la
aplicacion (lo escribe el mismo binario tp2-event cada vez que corre).

Que muestra: fecha, PID del proceso, UID, y el mensaje/argumento con el
que se lo ejecuto. Ejemplo:
  2026-09-24T19:10:19-0300 pid=23515 uid=0 mensaje=correlacion_demo_...

Para que sirve: es la SEGUNDA fuente independiente que registra el mismo
evento, con el dato clave para correlacionar: el PID.


05_ausearch_tp2_exec.txt
---------------------------
Que es: la salida de "sudo ausearch -k tp2_exec -ts recent", inmediatamente
despues de correr tp2-event bajo strace.

Que muestra: el registro persistente que dejo la regla de auditoria del
TODO 2 al detectar el execve. Incluye el mismo PID, el mismo binario
(/usr/local/bin/tp2-event), el mismo argumento (en el registro EXECVE) y
el numero de syscall 59 (execve en la tabla de 64 bits, arch=c000003e).

Para que sirve: es la TERCERA fuente, la que demuestra que el evento quedo
capturado por el kernel de forma persistente, independientemente de que
alguien estuviera mirando con strace o no.


======================================================================
COMO SE CORRELACIONAN 03, 04 y 05 (la base del Analisis 5)
======================================================================

Los tres archivos describen la MISMA ejecucion real de tp2-event, y se
puede probar comparando:

  - El mismo PID en los tres (eventos.log lo escribe la app; ausearch lo
    captura el kernel; strace lo esta observando en vivo).
  - El mismo binario: /usr/local/bin/tp2-event.
  - El mismo argumento/mensaje.
  - El mismo instante (mismo segundo en los tres timestamps).

La idea para el Analisis 5 (correlacion syscall <-> evento persistente):

  - strace (03) muestra el syscall execve en tiempo real, con maximo
    detalle (binario + argumentos exactos), pero es EFIMERO: si no se
    hubiera estado trazando en ese momento, esa informacion se pierde
    para siempre.
  - ausearch (05) muestra el mismo evento, pero capturado por una regla
    que ya estaba cargada en el kernel de antemano. No depende de que
    alguien este mirando: cualquier ejecucion de tp2-event, trazada o no,
    queda en /var/log/audit/audit.log de forma PERSISTENTE y consultable
    despues.
  - eventos.log (04) es una tercera confirmacion, a nivel aplicacion, que
    ademas aporta el PID de forma directa y legible.

Conclusion: la correlacion demuestra que un mismo evento del sistema
puede observarse de dos formas muy distintas - una activa y efimera
(strace), y otra pasiva y persistente (auditd) - y que ambas coinciden
en describir exactamente lo mismo.
