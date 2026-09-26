# Guion para presentar el laboratorio de Kubernetes

Duración estimada: 10 a 15 minutos, con una demostración en vivo.

En cada paso, explicá qué esperás que ocurra, ejecutá el comando y señalá el resultado.

## Preparación

- Tené Docker en funcionamiento y los requisitos del README instalados.
- Ensayá la secuencia antes de exponer. El primer inicio puede demorar por las descargas.
- Abrí tres terminales ubicadas en la carpeta del repo:

  ```bash
  cd /home/mateo/dev/kubernetes
  ```

| Terminal | Uso |
| --- | --- |
| A | Ejecutar los comandos del laboratorio |
| B | Mantener abierta la URL o el túnel de Minikube |
| C | Observar los cambios de los Pods |

## 1. Presentar el objetivo

Podés abrir diciendo:

> Este trabajo muestra cómo desplegar un servidor web en Kubernetes, aumentar la cantidad de instancias y recuperar automáticamente una instancia eliminada. Usamos Minikube para ejecutar el laboratorio localmente.

Abrí `kubernetes-lab.yaml` y señalá los cuatro recursos:

- `Namespace`: agrupa los recursos del laboratorio.
- `ConfigMap`: contiene la configuración de NGINX y el texto que responde.
- `Deployment`: define las instancias del portal y mantiene la cantidad deseada.
- `Service`: proporciona un punto de acceso común a los Pods.

En el Deployment, destacá:

```yaml
replicas: 2
```

> Acá declaramos que queremos mantener dos instancias del portal.

## 2. Validar e iniciar el entorno

En la terminal A:

```bash
make check
make start
```

> El primer comando revisa la sintaxis del script y procesa el YAML con Kustomize. El segundo inicia el clúster local usando Docker, con dos CPU y 2 GiB de memoria por defecto.

Mostrá el nodo con estado `Ready`.

**Captura:** versiones utilizadas y nodo listo.

## 3. Desplegar el portal

```bash
make deploy
```

> Ahora aplicamos la configuración. Kubernetes crea los recursos y espera a que las instancias estén disponibles.

Señalá en la salida:

- Deployment con `READY 2/2`.
- Dos Pods en `Running`, cada uno con `READY 1/1`.
- Service de tipo `NodePort`.

> Cada Pod ejecuta un contenedor NGINX. El Service nos da un punto de acceso común para esas instancias.

**Captura:** despliegue inicial con dos Pods listos.

## 4. Mostrar que el portal responde

En la terminal B:

```bash
make url
```

Copiá la URL que devuelve. Si el comando mantiene un túnel, dejá esa terminal abierta.

En la terminal A, reemplazá `PUERTO` por el valor real de la URL:

```bash
TP_URL='http://127.0.0.1:PUERTO' make requests
```

Si Minikube devuelve otra dirección, usá esa dirección completa.

Vas a obtener veinte respuestas con este formato:

```text
Portal academico - ASI 2026
Pod: portal-...
```

> La respuesta incluye el nombre del Pod que atendió la solicitud. Si aparecen distintos nombres, podemos observar que las solicitudes llegan a diferentes instancias.

No esperes una alternancia exacta entre los Pods.

**Captura:** respuestas HTTP con los nombres de los Pods.

## 5. Aumentar de dos a cuatro instancias

Primero, en la terminal C, iniciá la observación en vivo:

```bash
kubectl -n tp-kubernetes get pods -l app=portal --watch
```

En la terminal A:

```bash
make scale-up
```

> Estamos cambiando manualmente la cantidad deseada de réplicas de dos a cuatro. Kubernetes crea las dos instancias adicionales.

Mostrá cómo aparecen los nuevos Pods y esperá el resultado final: cuatro Pods listos y Deployment `4/4`.

> Esto es escalado horizontal: aumentamos la cantidad de instancias. En esta demostración, el escalado lo solicitamos nosotros.

**Captura:** Deployment con cuatro réplicas disponibles.

## 6. Demostrar la reposición automática

Dejá la terminal C observando los Pods. En la terminal A:

```bash
make self-heal
```

Antes de ejecutarlo, explicá:

> Este comando elimina uno de los Pods para simular la pérdida de una instancia. Como el estado deseado sigue siendo cuatro réplicas, Kubernetes debe crear un reemplazo.

Señalá:

- El nombre del Pod eliminado.
- La aparición de un Pod con otro nombre.
- La recuperación de las cuatro réplicas listas.

> Kubernetes detecta que falta una instancia y crea otra para volver al estado declarado.

La transición puede ser rápida: apoyate también en los nombres que imprime el script.

**Captura:** terminación del Pod y aparición de su reemplazo, usando la salida de la terminal C y del script.

## 7. Guardar las evidencias

```bash
make evidence
```

> Guardamos las versiones del entorno, el estado de los recursos y el identificador de la imagen utilizada para documentar esta ejecución.

Los archivos se guardan en `evidencias/FECHA-HORA/`. Complementan las capturas tomadas durante las etapas anteriores.

## 8. Cerrar el laboratorio y la exposición

Detené la observación de la terminal C con `Ctrl+C`. En la terminal A:

```bash
make reset
make stop
```

Si la terminal B sigue ejecutando el túnel, finalizalo con `Ctrl+C`.

> Volvemos a dos réplicas y detenemos el clúster local.

Podés cerrar diciendo:

> Demostramos el despliegue de un servicio web, su acceso mediante un Service, el escalado manual y la reposición automática de Pods. El laboratorio tiene un único nodo, por lo que no demuestra recuperación ante la caída de ese nodo.

Durante toda la exposición, mantené esta idea como hilo conductor: **declaramos cuántas instancias queremos y Kubernetes trabaja para mantener esa cantidad**.
