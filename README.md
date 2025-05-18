# Evitar los fallos de "Out of Capacity" de la nube de Oracle para tener una instancia/ VPS con 4vCPU y 24GB de RAM


**Nota importante:** Probablemente **no será necesario complicarse tanto para la instancia gratuita** si la cuenta de Oracle que tienes la has actualizado a "Pay As You Go", pero en caso de que aún así te dé fallo (o no tienes manera de insertar un método de pago válido), esta solución es ideal.

Para poder ejecutar esto es necesario tener **PHP 7.x or 8.x** y **composer** instalado en tu máquina para llamar a la API de Oracle "LaunchInstance" [endpoint](https://docs.oracle.com/en-us/iaas/api/#/en/iaas/20160918/Instance/LaunchInstance).

Usaremos el paquete desarrollado por [@hitrov](https://github.com/hitrov) - [oci-api-php-request-sign](https://packagist.org/packages/hitrov/oci-api-php-request-sign).

## Generar API Key

Iniciaremos sesión en nuestra cuenta de [Oracle](http://cloud.oracle.com/) e iremos a la imagen de nuestro **perfil --> "User settings"**.

![User Settings](/src/img/user_settings_oci.png)

Iremos a **Recursos --> API Keys**, y agregaremos una nueva API Key.

![Agregar nueva API Key](/src/img/agregar_api_key.png)

Nos **descargamos la API Key privada y le damos a "agregar"** para que se mantenga en nuestra cuenta.

![Descargar private key](/src/img/descargar_api_key_private.png)

Nos aparecerá la información para poder validar la API Key (fingerprint), donde **guardaremos esta información** para utilizarla a la hora de atacar al servicio de Oracle.

![Fingerprint de la API](/src/img/api_key_fingerprint.png)


## Requisisitos

Lo **ideal es que la instalación la realicemos en algún entorno virtual** para simplificar el proceso y evitar posibles fallos con dependencias.

En mi ejemplo lo voy a dejar **en una máquina de Debian 12 montada en un contenedor LXC en proxmox sin nada instalado**, pero se puede dejar instalado:

- En tu propio ordenador.

- En un entorno de Docker.

- En una máquina virtualizada (Hyper-V, Virtualbox, VMWare, Parallels).

![Entorno de la instalación](/src/img/entorno_instalacion.png)

## Instalación

Nos instalaremos **composer** y **git**.

`apt-get install composer -y`

![Composer install](/src/img/instalar_composer.png)

`apt-get install git -y`

![Instalar GIT](/src/img/instalar_git.png)

Y las **dependencias de PHP** que requerirá el repositorio.

`apt update && apt install php8.2-curl php8.2-xml php8.2-dom php8.2-simplexml -y`

![Dependencias de PHP](/src/img/dependencias_php.png)

**Clonaremos** este repositorio.
```bash
git clone https://github.com/hitrov/oci-arm-host-capacity.git
```

Y después **nos iremos a la carpeta** recién clonada.

```bash
cd oci-arm-host-capacity/
```

![Repositorio clonado](/src/img/clonar_repositorio.png)

**Instalaremos** las siguientes dependencias de composer:

- `composer require aws/aws-sdk-php`

![Dependencias composer AWS](/src/img/dependencias_composer_aws.png)

- `composer require hitrov/oci-api-php-request-sign`

![Dependencias composer OCI ARM](/src/img/dependencias_composer_oci_arm.png)

Y finalmente **actualizaremos el composer**.

`composer update`

![Actualizar composer](/src/img/composer_actualizar.png)

### Tener la private key en el servidor

Será necesario que la "private key" que hemos generado antes **esté accesible por el servidor**, ya que con ella es con quién podremos realizar la petición por API.

En mi caso antes, **este fichero** era el que me descargué con el siguiente nombre.

`oracle@enrico.es_2025-05-17T16_17_41.921Z.pem`

Lo que haré **será dejarlo en el servidor de Debian**, en la misma carpeta donde estamos trabajando, **cambiándole el nombre** a algo más sencillo.

`mv oracle@enrico.es_2025-05-17T16_17_41.921Z.pem enrico.es_private.pem`

![Pasar privae Key](/src/img/pasar_private_key.png)

### Copiar fichero de configuración

**Haremos una copia del fichero de configuración de ejemplo** (`.env.example`) para poder generar nuestro propio fichero de configuración.

```bash
cp .env.example .env
```

![Clonar fichero de configuración](/src/img/clonar_fichero_env.png)

#### Obtener OCI_SUBNET_ID, OCI_IMAGE_ID, 

Estos dos valores ahora mismo **no los tendríamos localizados**, y eso es algo que se ha de conseguir de la siguiene manera:

1. Tendremos que crear nuestra instancia desde la web de [Oracle](https://cloud.oracle.com/compute/instances/create) y seleccionar el tipo de instancia que queremos. Idealmente lo que queremos será:

    -   **Capacidad**: VM.Standard.A1.Flex con 4 OCPU y 24GB de RAM
    -   **Disco duro**: 200GB

    Digo idealmente, ya que **la capacidad máxima que entraría en una cuenta gratuita de Oracle** sería lo antes indicado:

![Limites Oracle Always Free](/src/img/limites_always_free.png)

2. Lo único importante será que tendremos que indicar **que no querremos claves SSH**, las generaremos después para poder acceder a la instancia.

![SSH Desactivar clave](/src/img/ssh_desactivado.png)

3. Antes de darle al botón de crear, **abriremos la consola de desarrollador del navegador (F12)**, para poder obtener estos valores.

![Abrir consola de desarrollador](/src/img/abrir_consola_firefox_2.png)

4. Le daremos al **botón de "Create"**, donde probablemente nos falle.

5. Iremos en la **consola** --> **"Network"** y:

    -   Filtraremos por **"instances"**.
    -   **Seleccionaremos** la opción que aparezca --> Click derecho.
    -   Iríamos a **"Copy Value"** --> **"Copy as cURL"**.

![Obtener valores SUBNET](/src/img/obtener_valores_SUBNET_IMAGE.png)

6. Esto **nos guardará en el portapapeles un texto muy largo**, de este estilo.

![Filtrar CURL](/src/img/filtrar_curl.png)

7. En este texto, **buscaremos y anotaremos** los valores siguientes:

    -   **subnetId** (OCI_SUBNET_ID en nuestro script)

    -   **imageId** (OCI_IMAGE_ID en nuestro script)

    -   **availabilityDomain** (OCI_AVAILIBITY_DOMAIN en nuestro script)

![subnetID valor](/src/img/subnetId.png)
![imageID valor](/src/img/imageId.png)
![availabilityDomain valor](/src/img/availabilityDomain.png)


#### Generar claves SSH pública y privada (para obtener valor OCI_SSH_PUBLIC_KEYS)

Para poder acceder a la instancia una vez creada, **será necesario que tengamos unas claves SSH pública y privada para poder acceder a él por SSH.**

Por ello, **generaremos estos ficheros** con el siguiente comando.

`ssh-keygen -t rsa -b 4096 -C "oracle@enrico.es"`

![Generar claves SSH](/src/img/generar_claves_ssh.png)

Y **guardaremos el valor de la clave pública** para usarla en la variable OCI_SSH_PUBLIC_KEYS.

`cat ~/.ssh/id_rsa.pub`

![Guardar clave pública](/src/img/guardar_clave_publica.png)

#### Editar fichero .env

Ya con todas las variables obtenidas, **simplemente editaremos el fichero .env** rellenándo las siguienes variables:

- **OCI_REGION** --> Obtenido al generar una API Key.
- **OCI_USER_ID** --> Obtenido al generar una API Key.
- **OCI_TENANCY_ID** --> Obtenido al generar una API Key.
- **OCI_KEY_FINGERPRINT** --> Obtenido al generar una API Key.
- **OCI_PRIVATE_KEY_FILENAME** --> Obtenido al generar una API Key.
- **OCI_SUBNET_ID** --> Obtenido de la petición por web con cURL.
- **OCI_IMAGE_ID** --> Obtenido de la petición por web con cURL.
- **OCI_AVAILABILITY_DOMAIN** --> Obtenido de la petición por web con cURL.
- **OCI_SSH_PUBLIC_KEY** --> Obtenido al generar nuestros certificados SSH.

![Fichero .env rellenado](/src/img/fichero_env_rellenado.png)

### Lanzar el script de PHP

Ya con todo generado, simplemente **lanzaremos el script de php con la siguiente línea**, el cuál probablemente nos dará un error de "Out of host capacity", indicándo que la petición API es correcta.

`php ./index.php`

![Petición API](/src/img/peticion_php_api.png)

### Programar ejecución

Ya teniendo este script configurado y validado que funcionaría, **solo quedaría dejar programado la ejecución de este script** para que lo reintente cada x minutos.

Para ello, haremos lo siguiente:

1. **Crearemos un fichero de log** para almacenar los intentos.

`touch oci.log`

2. **Encontraremos la ruta absoluta de nuestro repositorio** donde estaría el script con el siguiente comando.

`readlink -f oci.log`

En nuestro ejemplo, **nuestra ruta absoluta será** `/root/oci-arm-host-capacity/`.

![Crear logs y ruta](/src/img/crear_log_y_ruta.png)

3. **Editaremos crontab para que cada minuto se lance este script** y se guarde el resultado en el ficher de log.

`crontab -e`

4. **Agregaremos la siguiente línea**, utilizando las rutas absolutas para evitar problemas.

`* * * * * /usr/bin/php /root/oci-arm-host-capacity/index.php >> /root/oci-arm-host-capacity/oci.log`

![Configuración Crontab](/src/img/configurar_crontab.png)

5. Estaría todo listo, **simplemente a esperar** hasta que nos diesen la instancia. 🙂

## Pasos posteriores - Asignar IP Pública

Este apartado **no se puede hacer mediante API por los límites que tiene.**

Simplemente, teniendo ya la instancia creada en Oracle, nos iremos a **Details** -> **Resources** -> **Attached VNICs**

#IMAGEN#

Después iremos a **Resources** -> **IPv4 Addresses** -> **Edit**

#IMAGEN#

Elegiremos una **EPHEMERAL PUBLIC IP** y actualizaremos.

#IMAGEN#

Y de esta manera **podremos acceder a la instancia por IP Pública.**