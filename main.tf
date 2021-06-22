# Get AWS account info

data "aws_caller_identity" "current" {}

# Begin Macie

resource "aws_macie2_account" "PIIFinder" {}

resource "aws_macie2_classification_job" "PPIFinderJob" {
    job_type = "ONE_TIME"
    name     = "PPI Finder"
    s3_job_definition {
        bucket_definitions {
            account_id = data.aws_caller_identity.current.account_id
            buckets = [aws_s3_bucket.AB_Discord_logs]
        }
    }
    depends_on = [aws_macie2_account.PIIFinder]

    tags = {
        terraform = "true"
        use = "Kanchimoe/Macie"
    }
}


resource "aws_s3_bucket" "AB_Discord_logs" {
  bucket = "AB_Discord_logs"
  acl    = "private"

    tags = {
        terraform = "true"
        use = "Kanchimoe/Macie"
    }
}

# Firehose

resource "aws_kinesis_firehose_delivery_stream" "firehose" {
    name        = "ABDiscord_PPI_Firehose"
    destination = "extended_s3"
    
    extended_s3_configuration {
    role_arn   = aws_iam_role.ABDiscord_Firehose.arn
    bucket_arn = aws_s3_bucket.AB_Discord_logs.arn
    

        data_format_conversion_configuration {
            input_format_configuration { 
                deserializer {
                    hive_json_ser_de {}
                }
            }

            output_format_configuration {
                serializer {
                    parquet_ser_de {}
                }
            }

            schema_configuration {
                database_name = aws_glue_catalog_table.ABDiscord_Macie_Firehose_table.database_name
                table_name = aws_glue_catalog_table.ABDiscord_Macie_Firehose_table.name
                role_arn = aws_iam_role.ABDiscord_Firehose.arn
            }
        }
    }

    server_side_encryption {
        enabled = true
        key_type = "AWS_OWNED_CMK"
    }

    tags = {
        terraform = "true"
        use = "Kanchimoe/Macie"
    }
}

# Glue DB, for Firehose

resource "aws_glue_catalog_database" "ABDiscord_Macie_Firehose_db" {
  name = "abdiscord_firehose_macie"
}

resource "aws_glue_catalog_table" "ABDiscord_Macie_Firehose_table" {
  name          = "abdiscord_firehose_dataformat"
  database_name = "ABDiscord_Firehose_Macie"

  storage_descriptor {

    columns {
        name = "data"
        type = "struct<id:INT,channel_id:INT,guild_id:INT,content:string>"
    }
    columns {
        name = "author"
        type = "struct<id:INT,username:string,discriminator:string>" 
    }
  }
}

resource "aws_iam_role" "ABDiscord_Firehose" {
    name = "ABDiscord_Macie_Firehose"
    assume_role_policy = data.aws_iam_policy_document.ABDiscord_Firehose_AR.json

    tags = {
        terraform = "true"
        use = "Kanchimoe/macie"
    }
}

resource "aws_iam_policy" "ABDiscord_Firehose_policy" {
  name        = "ABDiscord_Firehose_policy"
  path        = "/"
  description = "Angel Beats Discord Macie/Firehose"
  policy = data.aws_iam_policy_document.ABDiscord_Firehose_policy.json

  tags = {
      terraform = "true"
      use = "Kanchimoe/macie"
  }
}

data "aws_iam_policy_document" "ABDiscord_Firehose_AR" {
    statement {
        actions = [
            "sts:AssumeRole"
        ]
        principals {
            type = "Service"
            identifiers = ["firehose.amazonaws.com"]
        }
    }
}

data "aws_iam_policy_document" "ABDiscord_Firehose_policy" {
    statement {
        actions = [
            # Access AWS Glue
            "glue:GetTable",
            "glue:GetTableVersion",
            "glue:GetTableVersions"
        ]
        resources = [
            aws_glue_catalog_table.ABDiscord_Macie_Firehose_table.arn
            ]
    }
    statement {
        actions = [
            # Access S3 bucket
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject" 
        ]
        resources = [
            aws_s3_bucket.AB_Discord_logs.arn
        ]
    }
}