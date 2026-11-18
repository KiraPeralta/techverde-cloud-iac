# techverde-cloud-iac
Sistema de gestion de configuracion IaC y DevOps en AWSumentación técnica del proyecto

# TechVerde Chile – Infraestructura como Código (IaC) y Seguridad DevOps en AWS

Sistema de gestión de la configuración y despliegue automatizado para el portal web estático de **TechVerde Chile**, implementado mediante **Terraform**, **GitHub Actions** y servicios de seguridad y observabilidad en **Amazon Web Services (AWS)**.

## Descripción del Caso y Arquitectura
El proyecto resuelve la necesidad de publicar un catálogo digital con alta disponibilidad, eliminando despliegues manuales y garantizando trazabilidad, cifrado y detección temprana de incidentes en la región `us-east-2` (Ohio).

### Estructura del Repositorio
* `.github/workflows/deploy.yml`: Pipeline CI/CD para validación estática, despliegue IaC y pruebas automatizadas.
* `infra/main.tf`: Declaración IaC en Terraform (S3 Web, S3 Logs, CloudTrail, CloudWatch y políticas de seguridad).
* `tests/test_deployment.sh`: Script de pruebas automatizadas de disponibilidad (`HTTP 200`) y aislamiento (`HTTP 403`).
* `web/index.html` y `web/error.html`: Portal principal y página personalizada de error 404.

## Prácticas de Seguridad y Observabilidad Implementadas
1. **Mínimo Privilegio (IAM y Bucket Policies):** El bucket web permite exclusivamente lectura pública (`s3:GetObject`), mientras que el bucket de auditoría bloquea el 100% del acceso público (`PublicAccessBlock`).
2. **Protección de Credenciales:** Las llaves de AWS se almacenan cifradas en **GitHub Secrets** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`), sin exponer secretos en el código.
3. **Cifrado y Respaldo:** Cifrado en reposo **AES-256 (SSE-S3)** en ambos buckets y **versionado de objetos** activado en el bucket web.
4. **Monitoreo y Trazabilidad:**
   * **Amazon CloudWatch:** Supervisa métricas de tráfico y activa la alarma `TechVerde-High-4xx-Errors` ante 3 o más errores HTTP `4xx` en 5 minutos.
   * **AWS CloudTrail:** Registra el historial de eventos y llamadas API de la cuenta (`techverde-security-trail`).

## Flujo de Despliegue Automatizado
Cada cambio en la rama `main` ejecuta automáticamente en **GitHub Actions**:
1. **Validación Estática:** `terraform fmt` y `terraform validate` verifican la sintaxis antes de desplegar.
2. **Despliegue Declarativo:** `terraform apply` aprovisiona los recursos en AWS y sincroniza el sitio web en S3.
3. **Pruebas de Integración:** `tests/test_deployment.sh` valida que el sitio responda `200 OK` y que el bucket de logs devuelva `403 Forbidden`.

   ## Reflexión Final
La implementación de este sistema demostró cómo la Infraestructura como Código (Terraform) y la integración continua (GitHub Actions) transforman la administración Cloud en un proceso reproducible, seguro y auditable. Durante el desarrollo surgieron desafíos técnicos reales —como políticas restrictivas y límites regionales en AWS—, los cuales se resolvieron parametrizando el despliegue en `us-east-2` e incorporando importación de estado (`terraform import`) para lograr ejecuciones idempotentes. En conjunto, la combinación de monitoreo activo en CloudWatch, trazabilidad en CloudTrail y validación automatizada reduce el riesgo de errores humanos y fortalece la seguridad operativa de la plataforma.
