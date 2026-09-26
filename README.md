# Portal académico sobre Kubernetes

Implementación reproducible del caso práctico propuesto en el Trabajo Práctico
Integrador. El laboratorio despliega un portal HTTP mínimo en un clúster local de
Minikube y permite demostrar acceso mediante un Service, escalado horizontal
manual y reposición automática de Pods.

## Arquitectura

El archivo `kubernetes-lab.yaml` declara cuatro recursos:

- `Namespace/tp-kubernetes`: aísla los recursos del laboratorio.
- `ConfigMap/portal-config`: contiene la configuración de NGINX y las respuestas
  de `/` y `/healthz`.
- `Deployment/portal`: mantiene inicialmente dos réplicas, define recursos y
  verifica salud y disponibilidad mediante probes HTTP.
- `Service/portal`: expone los Pods con un punto de acceso estable de tipo
  `NodePort`.

Cada respuesta de `/` incluye el hostname del contenedor, que en Kubernetes
coincide con el nombre del Pod que atendió la solicitud.
`kustomization.yaml` permite analizar y renderizar los recursos localmente con
Kustomize, integrado en `kubectl`.

## Requisitos

- Docker en funcionamiento.
- Minikube.
- kubectl.
- curl y Bash.
- Al menos 2 CPU y 2 GiB de memoria asignables al clúster.
- Espacio libre para las imágenes, contenedores y logs de Docker. La guía general
  de Minikube recomienda 20 GB libres; con el driver Docker usado aquí no se
  reserva un disco virtual de 20 GB. El consumo real depende de las imágenes
  descargadas y los datos acumulados.

El arranque asigna 2048 MiB de RAM y desactiva la precarga y la caché adicional
de imágenes de Minikube para reducir copias en disco. Las imágenes necesarias
se descargan en el runtime del clúster; el primer arranque puede tardar más y
requiere acceso a sus registros. Esto no elimina cachés anteriores ni limita
el espacio que Docker puede consumir. `--disk-size` configura discos de máquinas
virtuales y no se utiliza como límite de disco para este laboratorio con Docker.

Para cambiar la asignación al crear el clúster:

```bash
MINIKUBE_MEMORY=3072 MINIKUBE_CPUS=2 make start
```

Si el perfil ya existe, Minikube puede requerir recrearlo para cambiar sus
recursos. `make stop` detiene el clúster, pero conserva sus datos en disco.

Los scripts rechazan operaciones sobre un contexto diferente de `asi-k8s`. Se
pueden cambiar los valores predeterminados mediante las variables `PROFILE`,
`NAMESPACE`, `DEPLOYMENT`, `SERVICE` y `TIMEOUT`.

## Ejecución paso a paso

Validar el manifiesto e iniciar el clúster:

```bash
make check
make start
```

Desplegar los recursos y comprobar que las dos réplicas estén disponibles:

```bash
make deploy
```

Obtener la URL en una terminal y mantenerla abierta si Minikube crea un túnel:

```bash
make url
```

En una segunda terminal, copiar la URL anterior y realizar veinte solicitudes:

```bash
TP_URL='http://127.0.0.1:PUERTO' make requests
```

La salida debe mostrar `Portal academico - ASI 2026` y distintos nombres de Pod.
No se garantiza alternancia estricta entre las instancias.

Escalar a cuatro réplicas y verificar el estado:

```bash
make scale-up
```

Eliminar un Pod y esperar que el Deployment recupere la cantidad deseada:

```bash
make self-heal
```

El script informa el Pod eliminado, espera hasta 180 segundos y muestra el estado
final. Para ver la transición en vivo, ejecutar antes en otra terminal:

```bash
kubectl -n tp-kubernetes get pods -l app=portal --watch
```

## Evidencias para el informe

La consigna requiere capturas reales de estas cinco etapas:

1. Versiones utilizadas y nodo en estado `Ready` (`make start`).
2. Despliegue inicial con dos Pods `Running` y `Ready 1/1` (`make deploy`).
3. Respuesta HTTP con el nombre del Pod (`make requests`).
4. Deployment con cuatro réplicas disponibles (`make scale-up`).
5. Terminación del Pod y aparición de su reemplazo (`make self-heal`, junto con
   el comando `--watch`).

`make evidence` guarda además versiones, recursos e identificador inmutable de la
imagen utilizada bajo `evidencias/FECHA-HORA/`. Es evidencia textual auxiliar y no
reemplaza las capturas solicitadas.

## Cierre del laboratorio

Volver al estado declarativo inicial y detener Minikube:

```bash
make reset
make stop
```

El laboratorio es educativo y utiliza un único nodo. No demuestra tolerancia a la
caída del nodo, persistencia, autenticación, autoscalado ni rendimiento productivo.
