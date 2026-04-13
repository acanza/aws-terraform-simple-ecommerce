# Módulo S3 - Bucket para Imágenes

Módulo reutilizable para crear buckets S3 seguros y bien configurados para almacenar imágenes de aplicaciones web.

## Características

✅ **Encriptación automática** - SSE-S3 por defecto  
✅ **Versionamiento** - Controlar versiones de objetos  
✅ **Acceso privado** - Bloqueo completamente del acceso público  
✅ **HTTPS obligatorio** - Denegar transferencias no encriptadas  
✅ **Control de acceso granular** - Permisos basados en roles IAM  
✅ **Ciclo de vida configurable** - Limpiar objetos antiguos automáticamente  

## Uso

### Ejemplo básico

```hcl
module "s3_images" {
  source = "./modules/s3"

  bucket_name = "ecommerce-dev-images"
  environment = "dev"

  # Permitir que el rol de EC2 lea y escriba imágenes
  read_access_role_arns  = [aws_iam_role.ec2_instance_role.arn]
  write_access_role_arns = [aws_iam_role.ec2_instance_role.arn]
}
```

### Ejemplo avanzado

```hcl
module "s3_images" {
  source = "./modules/s3"

  bucket_name = "ecommerce-prod-images"
  environment = "prod"

  enable_versioning               = true
  enable_server_side_encryption   = true
  lifecycle_expiration_days       = 365  # Borrar imágenes después de 1 año

  read_access_role_arns  = [
    aws_iam_role.ec2_instance_role.arn,
    aws_iam_role.lambda_image_processor.arn
  ]
  
  write_access_role_arns = [
    aws_iam_role.ec2_instance_role.arn
  ]

  tags = {
    CostCenter = "ecommerce"
    Owner      = "devops"
  }
}
```

## Variables

| Variable | Descripción | Tipo | Predeterminada |
|----------|------------|------|---------------|
| `bucket_name` | Nombre único del bucket (3-63 caracteres) | `string` | Requerido |
| `environment` | Ambiente: dev, stage, prod | `string` | Requerido |
| `enable_versioning` | Habilitar versionamiento de objetos | `bool` | `true` |
| `enable_server_side_encryption` | Habilitar encriptación SSE-S3 | `bool` | `true` |
| `read_access_role_arns` | ARNs de roles con acceso de lectura | `list(string)` | `[]` |
| `write_access_role_arns` | ARNs de roles con acceso de escritura | `list(string)` | `[]` |
| `lifecycle_expiration_days` | Días para eliminar objetos (0 = deshabilitado) | `number` | `0` |
| `tags` | Tags adicionales | `map(string)` | `{}` |

## Outputs

| Output | Descripción |
|--------|------------|
| `bucket_name` | Nombre del bucket S3 |
| `bucket_arn` | ARN del bucket |
| `bucket_region` | Región AWS del bucket |
| `bucket_domain_name` | Nombre de dominio para acceso HTTP |
| `images_folder_path` | Ruta recomendada: `s3://bucket-name/images/` |

## Permisos de IAM requeridos

Para que la aplicación en EC2 acceda al bucket, necesita estos permisos:

### Lectura (GetObject)
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::ecommerce-dev-images",
    "arn:aws:s3:::ecommerce-dev-images/*"
  ]
}
```

### Escritura (PutObject)
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::ecommerce-dev-images",
    "arn:aws:s3:::ecommerce-dev-images/*"
  ]
}
```

## Uso en la aplicación

### Node.js / Express

```javascript
const AWS = require('aws-sdk');
const s3 = new AWS.S3({ region: 'eu-west-3' });

// Subir imagen
app.post('/upload', async (req, res) => {
  const file = req.file;
  const key = `images/${Date.now()}-${file.originalname}`;

  const params = {
    Bucket: process.env.S3_BUCKET_NAME,
    Key: key,
    Body: file.buffer,
    ContentType: file.mimetype
  };

  try {
    const data = await s3.upload(params).promise();
    res.json({ url: data.Location });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Servir imagen
app.get('/images/:key', async (req, res) => {
  const params = {
    Bucket: process.env.S3_BUCKET_NAME,
    Key: `images/${req.params.key}`
  };

  try {
    const data = await s3.getObject(params).promise();
    res.contentType(data.ContentType);
    res.send(data.Body);
  } catch (err) {
    res.status(404).json({ error: 'Imagen no encontrada' });
  }
});
```

### Python / Flask

```python
import boto3
import os

s3_client = boto3.client('s3', region_name='eu-west-3')
BUCKET_NAME = os.getenv('S3_BUCKET_NAME')

# Subir imagen
@app.route('/upload', methods=['POST'])
def upload_image():
    file = request.files['file']
    key = f"images/{datetime.now().timestamp()}-{file.filename}"

    try:
        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=key,
            Body=file.stream,
            ContentType=file.content_type
        )
        return jsonify({'url': f"s3://{BUCKET_NAME}/{key}"})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Servir imagen
@app.route('/images/<path:key>')
def get_image(key):
    try:
        obj = s3_client.get_object(Bucket=BUCKET_NAME, Key=f'images/{key}')
        return send_file(obj['Body'], mimetype=obj['ContentType'])
    except Exception as e:
        return jsonify({'error': 'Imagen no encontrada'}), 404
```

## Seguridad aplicada

### ✅ Encriptación
- SSE-S3 por defecto en todos los objetos
- HTTPS obligatorio (denegar transferencias no encriptadas)

### ✅ Acceso privado
- Bloqueo de acceso público activado
- Sin ACLs públicas
- Sin políticas públicas

### ✅ Control de acceso
- Solo roles IAM especificados pueden acceder
- Permisos granulares (lectura/escritura)
- Sin wildcards (`*`) en acciones

### ✅ Versionamiento
- Recuperar versiones anteriores de imágenes
- Protección contra eliminación accidental

## Notas

- El bucket debe tener un nombre único en toda AWS
- Recomendado incluir el ambiente en el nombre: `ecommerce-{env}-images`
- Para producción, considerar CloudFront para distribución de contenido
- Para imágenes muy grandes, usar presigned URLs con expiración
