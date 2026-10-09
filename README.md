# TP2 – Seguridad en Sistemas Operativos

**Materia:** Sistemas Operativos y Redes II  
**Institución:** Universidad Nacional de General Sarmiento  
**Año:** 2026

## Integrantes

- Joaquín Muñoz
- Francisco Javier Ruiz Lezcano
- Gastón Sanchez
- Mauricio Quevedo

## Descripción

Este repositorio contiene los archivos de configuración, scripts y evidencias del Trabajo Práctico 2, centrado en la seguridad de un sistema GNU/Linux. El trabajo aborda hardening básico, control de acceso obligatorio con AppArmor, auditoría mediante `auditd`, observación de llamadas al sistema con `strace` y control de integridad con AIDE.

El procedimiento, los resultados y su interpretación están documentados en **`SOR 2 TP2 - Informe técnico.pdf`** y en la carpeta `evidencias/`.

## Entorno de trabajo

- **Entorno indicado por la consigna:** Ubuntu Server 24.04 LTS amd64, en una máquina virtual aislada.
- **Entorno registrado en las evidencias del escenario integrador:** Ubuntu 20.04.2 LTS, kernel `5.4.0-70-generic`, en VirtualBox.
- **Host de la VM:** `alumno-virtualbox`.
- **Usuario observado en la VM:** `alumno`.
- **Acceso remoto documentado:** SSH mediante reenvío NAT desde `127.0.0.1:2222` al puerto 22 de la VM.
- **Herramientas principales:** Bash, compilador C, AppArmor, `auditd`, `strace`, AIDE y OpenSSH.

**Diferencia de entorno:** las evidencias del escenario integrador corresponden a Ubuntu 20.04.2 LTS, no a la versión Ubuntu Server 24.04 LTS indicada por la consigna. Esta diferencia se deja explícita y no se presenta la ejecución registrada como si se hubiera realizado en la versión oficial solicitada.

## Estructura relevante

- `hardening/hardening.sh`: implementación del hardening.
- `apparmor/usr.local.bin.tp2-reader`: perfil de AppArmor para `tp2-reader`.
- `audit/99-tp2.rules`: reglas de auditoría.
- `aide/aide.conf`: configuración de AIDE incluida en el repositorio.
- `scripts/preparar_entorno.sh`: preparación del laboratorio e instalación opcional de dependencias.
- `scripts/escenario_final.sh`: ejecución del escenario integrador.
- `scripts/restaurar_entorno.sh`: retirada de los cambios y archivos creados por el laboratorio; revisar el script antes de ejecutarlo.
- `src/`: código fuente de `tp2-reader` y `tp2-event`.
- `tests/public_checks.sh`: comprobaciones públicas de estructura, entorno y entrega.
- `evidencias/`: salidas y capturas organizadas por etapa.
- `SOR 2 TP2 - Informe técnico.pdf`: informe técnico del grupo.


## Orden de ejecución y comprobaciones

El trabajo se desarrolló en etapas, abordando cada mecanismo de seguridad por separado y luego integrándolos en un escenario común. Las evidencias de cada etapa se conservaron en la carpeta `evidencias/` y los procedimientos y resultados se documentaron en el informe técnico.

### 1. Preparación del entorno

Se preparó una máquina virtual aislada de VirtualBox y se instalaron las dependencias necesarias, se compilaron los programas de prueba y se creó el directorio de trabajo `/srv/tp2`. También se verificó el estado inicial de los servicios y controles de seguridad.

```bash
sudo ./scripts/preparar_entorno.sh --install-packages
sudo ./tests/public_checks.sh --entorno
```

Una vez comprobado el entorno, se creó el snapshot `TP2_BASE` para disponer de un punto de restauración.

### 2. Parte 1: Hardening

Se completó el script `hardening/hardening.sh` a partir del archivo base proporcionado. Se verificó el estado de los controles, se aplicaron las modificaciones necesarias y se registraron las evidencias correspondientes. También se evaluó el comportamiento del script al ejecutarlo nuevamente y su capacidad de restaurar los cambios.

### 3. Parte 2: AppArmor

Se configuró el perfil `apparmor/usr.local.bin.tp2-reader` para restringir los archivos que podía leer el programa de prueba. Se realizaron pruebas en los modos `complain` y `enforce`, comparando el comportamiento del programa y los eventos registrados. Finalmente, el perfil quedó en modo `enforce`, de manera que los accesos no autorizados fueran bloqueados.

### 4. Parte 3.1 y 3.2: Auditoría y llamadas al sistema

Se configuraron las reglas de auditoría de `auditd` mediante `audit/99-tp2.rules` y se comprobaron los eventos generados por las operaciones sobre los archivos de prueba y la ejecución de `tp2-event`. Además, se utilizó `strace` para observar las llamadas al sistema y contrastarlas con los registros persistentes de auditoría. Las salidas obtenidas se guardaron como evidencia.

### 5. Parte 3.3: Integridad con AIDE

Se configuró AIDE mediante `aide/aide.conf` para controlar los archivos de `/srv/tp2/datos`. Se generó una línea base del estado inicial y luego se realizaron cambios controlados, como crear archivos y modificar contenido o atributos. Finalmente, se ejecutó una verificación para identificar las diferencias detectadas respecto de la línea base.

### 6. Escenario integrador

Con los componentes configurados, se ejecutó el escenario integrador mediante el script `correr_escenario_integrador.sh`, que prepara y ejecuta las pruebas y recopila sus resultados. Se verificó que AppArmor, `auditd` y AIDE actuaran conjuntamente: AppArmor controló los accesos, `auditd` registró las operaciones seleccionadas y AIDE detectó los cambios en el estado de los archivos.

Los resultados se almacenaron en `evidencias/escenario_integrador_20261009_000325/`.

### 7. Validación de la entrega

Por último, se revisaron los archivos de configuración, los scripts, las evidencias y el informe técnico. Antes de generar el archivo final, se ejecuta la comprobación de entrega:

```bash
./tests/public_checks.sh --entrega
```

Esta comprobación permite detectar determinados problemas de estructura y sintaxis, pero no reemplaza la revisión manual de los resultados ni garantiza por sí sola el cumplimiento completo de la consigna.

**Nota sobre el entorno:** las evidencias documentadas del escenario integrador corresponden a Ubuntu 20.04.2 LTS con kernel `5.4.0-70-generic`, mientras que la consigna solicita Ubuntu Server 24.04 LTS amd64. Esta diferencia se deja explícita en la documentación.


## Diferencias y observaciones técnicas registradas

- **Compatibilidad de AIDE:** la evidencia del escenario registra AIDE 0.16.1. Esa versión rechazó algunas opciones de `aide/aide.conf` del repositorio, en particular `database_in`, `report_level` y `ftype`. Para esa ejecución se utilizó una configuración compatible ubicada en `/srv/tp2/config/aide.conf`: se empleó `database` y se omitieron `report_level` y `ftype`. La nota `evidencias/escenario_integrador_20261008_234554/NOTA_aide_compatibilidad.txt` documenta la diferencia. Por eso, la configuración del repositorio y la usada en esa ejecución no son idénticas.
- **Registros de AppArmor:** en el entorno probado, los eventos se encontraron en `/var/log/audit/audit.log` con `auditd` activo.
- **Finales de línea CRLF:** durante las pruebas se detectaron errores asociados a finales de línea de Windows en archivos de reglas y scripts. Se convirtieron a finales de línea Unix (LF) y se repitieron las pruebas.
- **`auditd` y AIDE tienen funciones distintas:** `auditd` registra operaciones seleccionadas por reglas; AIDE compara el estado de los archivos con una línea base. Por eso, una operación registrada por `auditd` no implica necesariamente que AIDE detecte una diferencia en el estado final.

## Evidencias e informe

Las evidencias están organizadas por etapa dentro de `evidencias/`. El informe técnico describe los objetivos, procedimientos, resultados y limitaciones observadas.
