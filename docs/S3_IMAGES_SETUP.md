# S3 Images Bucket - Implementation Guide

## ✅ Components Implemented

A production-ready S3 module has been created for storing web application images:

### 1. **S3 Module** (`modules/s3/`)
- ✅ S3 bucket with automatic encryption (SSE-S3)
- ✅ Object versioning enabled
- ✅ Public access completely blocked
- ✅ HTTPS enforcement (deny unencrypted transfers)
- ✅ Granular IAM role-based permissions
- ✅ Configurable lifecycle policy

### 2. **IAM Integration** (updated `iam/` module)
- ✅ EC2 role can now read and write to the S3 bucket
- ✅ Limited permissions (only necessary actions)
- ✅ Access restricted to the specific bucket

### 3. **Dev Integration** (`envs/dev/`)
- ✅ S3 bucket created for the dev environment
- ✅ Unique name: `ecommerce-dev-images-{account-id}`
- ✅ Explicitly linked to EC2 IAM role

---

## 📋 Configurable Variables

The S3 module accepts these variables:

```hcl
variable "bucket_name"                        # Unique bucket name (required)
variable "environment"                        # dev, stage, prod (required)
variable "enable_versioning"                  # true (default)
variable "enable_server_side_encryption"      # true (default)
variable "read_access_role_arns"              # List of roles with read access
variable "write_access_role_arns"             # List of roles with write access
variable "lifecycle_expiration_days"          # Days to delete objects (0 = never)
variable "tags"                               # Additional tags
```

---

## 🚀 Next Steps

### 1. Initialize Terraform
```bash
cd envs/dev
terraform init
```

### 2. Review the Plan
```bash
terraform plan
```

### 3. Apply (when ready)
```bash
terraform apply
```

### 4. Verify the Bucket
```bash
# Get the bucket name from outputs
terraform output s3_images_bucket_name

# List objects (should be empty initially)
aws s3 ls s3://ecommerce-dev-images-{account-id}/
```

---

## 💾 Permissions Assigned to EC2

The EC2 IAM role now has these permissions on the S3 bucket:

### Read:
- `s3:GetObject` - Download/read images
- `s3:ListBucket` - List objects in the bucket

### Write:
- `s3:PutObject` - Upload new images
- `s3:DeleteObject` - Delete images

---

## 📱 Usage in the Application

### Node.js / Express

```javascript
const AWS = require('aws-sdk');
const s3 = new AWS.S3({ region: 'eu-west-3' });

// Upload image
app.post('/api/upload', async (req, res) => {
  const file = req.file;
  const params = {
    Bucket: process.env.S3_BUCKET_NAME,
    Key: `images/${Date.now()}-${file.originalname}`,
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

// Download image
app.get('/api/images/:filename', async (req, res) => {
  const params = {
    Bucket: process.env.S3_BUCKET_NAME,
    Key: `images/${req.params.filename}`
  };

  try {
    const data = await s3.getObject(params).promise();
    res.contentType(data.ContentType);
    res.send(data.Body);
  } catch (err) {
    res.status(404).json({ error: 'Image not found' });
  }
});
```

### Python / Flask

```python
import boto3
import os

s3 = boto3.client('s3', region_name='eu-west-3')
BUCKET = os.getenv('S3_BUCKET_NAME')

# Upload image
@app.route('/api/upload', methods=['POST'])
def upload():
    file = request.files['file']
    key = f"images/{uuid.uuid4()}-{file.filename}"
    
    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=file.stream,
        ContentType=file.content_type
    )
    
    return jsonify({'url': f"s3://{BUCKET}/{key}"})

# Download image
@app.route('/api/images/<filename>')
def get_image(filename):
    try:
        obj = s3.get_object(Bucket=BUCKET, Key=f'images/{filename}')
        return send_file(obj['Body'], mimetype=obj['ContentType'])
    except:
        return jsonify({'error': 'Not found'}), 404
```

---

## 🔐 Security

### ✅ Implemented

| Aspect | Status | Details |
|--------|--------|---------|
| Encryption | ✅ Enabled | Automatic SSE-S3 |
| Public Access | ✅ Blocked | Completely blocked |
| HTTPS | ✅ Enforced | Deny unencrypted transfers |
| Permissions | ✅ Restrictive | Only necessary roles |
| Versioning | ✅ Enabled | Recover old versions |

---

## 📊 Available Outputs

After applying, these will be available in `terraform output`:

```hcl
s3_images_bucket_name       # Bucket name
s3_images_bucket_arn        # Bucket ARN
s3_images_bucket_domain_name # Regional domain name
s3_images_folder_path       # Recommended path (s3://bucket/images/)
```

---

## ⚙️ Production Configuration (`envs/prod/`)

To prepare the production bucket (when needed):

```hcl
module "s3_images" {
  source = "../../modules/s3"

  bucket_name = "ecommerce-prod-images-${data.aws_caller_identity.current.account_id}"
  environment = "prod"

  enable_versioning         = true
  lifecycle_expiration_days = 365  # Archive images after 1 year

  read_access_role_arns  = [module.iam.ec2_instance_role_arn]
  write_access_role_arns = [module.iam.ec2_instance_role_arn]

  tags = {
    CostCenter = "ecommerce"
    Backup     = "daily"
  }
}
```

---

## 🎯 Usage Variants

### Read-only access from EC2
```hcl
read_access_role_arns = [module.iam.ec2_instance_role_arn]
write_access_role_arns = []  # Disabled
```

### Multiple roles with access
```hcl
read_access_role_arns = [
  module.iam.ec2_instance_role_arn,
  aws_iam_role.lambda_processor.arn,
  aws_iam_role.batch_import.arn
]
```

### CloudFront for distribution
```hcl
# In production, consider CloudFront for global image cache
# with restricted access via OAI (Origin Access Identity)
```

---

## 📝 Important Notes

1. **Bucket name**: Includes account ID to ensure global uniqueness
2. **Cost**: S3 Standard; consider Glacier for archiving old images
3. **Performance**: For high-traffic images, use CloudFront in production
4. **Backups**: Versioning provides protection against accidental overwrites
5. **Permissions**: Can be updated without recreating the bucket

---

## 🔗 References

- [S3 Module Documentation](../../modules/s3/README.md)
- [IAM Module Documentation](../../modules/iam/README.md)
- [S3 Module Variables](../../modules/s3/variables.tf)
- [S3 Module Outputs](../../modules/s3/outputs.tf)
