---
title: "Build a serverless IP counter on AWS"
date: "2023-11-25T11:24:18+01:00"
draft: false
tags:
  - tutorial
  - cloud
  - aws
  - terraform
---

Welcome to this guide on building a serverless IP counter using AWS Lambda and DynamoDB. This is designed as a practical exercise to help you gain hands-on experience with some of the most popular services offered by AWS.

We will create a simple IP address counter, each time a visitor accesses the webpage, the counter for its IP address will increase.

This project will enhance your understanding of AWS services and also give you a practical example of how serverless technologies can be used in a real-world scenario.

### What you will learn

By completing this project you will learn to:

- Configure and deploy a Lambda function.
- Deploy a DynamoDB table.
- Integrate these services together to create a simple serverless application.
- Use Terraform to define and provision AWS infrastructure as code.

### Technologies used

- **AWS Lambda**: A serverless compute service that lets you run code without provisioning or managing servers.
- **AWS DynamoDB**: A fast and flexible NoSQL database service for all applications that need consistent, single-digit millisecond latency at any scale.
- **Terraform**: An open-source infrastructure as code software tool that provides a consistent CLI workflow to manage hundreds of cloud services.
- **Python**: For the lambda's function code :)

### Prerequisites

You should have at least the following:

- A basic understanding of AWS services.
- An AWS account and some knowledge of the pricing of the services used.
- Python programming knowledge, we'll be using this language for the lambda function.
- Some experience using Terraform and basic knowledge about infrastructure as code.

Please, remember to consider aspects like security and cost when setting up these services.

OK, let's get started!

## Initializing the project repository

To begin, we need to set up a local Git repository for our project. I know that this is very basic but I want to guide you through the whole process.

### 1. Initialize a git repository

Create a new directory for your project and initialize a Git repository:

```bash
mkdir serverless-ip-counter
cd serverless-ip-counter
git init
```

### 2. Create a '.gitignore' file

Create a `.gitignore` file in the root of your project directory. For Terraform projects, it's **uttermost important** to exclude state files, lock files, etc. that might contain sensitive data.

Add the following contents to your `.gitignore` file:

```gitignore
# Local .terraform directories
.terraform*

# .tfstate files
terraform.tfstate
terraform.tfstate.*

# Crash log files
crash.log

# Most .tfvars files contain sensitive data
*.tfvars
*.tfvars.json

# Ignore CLI configuration files
.terraformrc
terraform.rc

# Ignore the ZIP that terraform will create from our lambda-code
lambda-code.zip
```

### 3. Create the 'provider.tf' file

Next, create a file named `provider.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  profile = "<CLI_PROFILE>" # Replace <CLI_PROFILE> with your AWS CLI profile name
  region  = var.region

  default_tags {
    tags = {
      Name = local.name
    }
  }
}
```

Replace `<CLI_PROFILE>` with your AWS CLI profile name. The `region` and `name` values will be defined in the next step.

### 4. Define variables and locals

Now, let's define some variables and locals that our Terraform configuration will use.

Create a file named `variables.tf` and add the following contents:

```hcl
variable "env" {
  description = "Environment name"
  default     = "test"
}

variable "name" {
  description = "Application name"
  default     = "ip-counter"
}

variable "region" {
  description = "AWS Region"
  default     = "us-east-1"
}

locals {
  name = "${var.env}-${var.name}"
}
```

This file defines three variables: `env`, `name`, and `region`, with default values for each. The locals block creates a concatenated `name` that we use as the default `Name` tag for our resources.

## Initial lambda function

The next step in our project is to set up the initial AWS Lambda function. We will start with a simple Python function that returns a "Hello, world!" string, and later modify it to interact with DynamoDB.

### 1. Create the lambda function code

First, we need to write the Python code for our Lambda function. Create a new directory named `lambda-code` in your project and add a file named `lambda_function.py` with the following code:

```python
def lambda_handler(event, context):
    return {"statusCode": 200, "body": "Hello, world!"}
```

This is really basic but will help us testing that everything is working correctly.

### 2. Terraform resources for lambda

Now, let's create the Terraform configuration to deploy this Lambda function. You'll need to define three resources: [aws_lambda_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function), [archive_file](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) and [aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role).

Create a Terraform file named `lambda.tf` in your project directory and add the following configuration:

```hcl
resource "aws_lambda_function" "ip_counter_lambda" {
  function_name = local.name
  description   = "Serverless IP counter"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.iam_lambda.arn
  runtime       = "python3.11"

  source_code_hash = data.archive_file.lambda_output.output_base64sha256
  filename         = data.archive_file.lambda_output.output_path

  environment {
    variables = {
      # Environment variables for the lambda
    }
  }
}

resource "aws_iam_role" "iam_lambda" {
  name = local.name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

data "archive_file" "lambda_output" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-code"
  output_path = "${path.module}/lambda-code.zip"
}
```

This configuration defines the lambda function and instructs Terraform to package the contents of the `lambda-code` folder **into a ZIP file** automatically. The `aws_lambda_function` uses this ZIP file as its source code. It's a good practice to do this as the AWS imposes some limits on the size of the code uploaded, and Terraform does this automatically for us.

Now ensure that the Terraform code is correct by executing `terraform validate`:

```shell
$ terraform init
$ terraform validate
Success! The configuration is valid.
```

## Adding a lambda function URL

To provide easy HTTP access to our Lambda function, we'll use the [aws_lambda_function_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url) resource. This is a simpler alternative to setting up an API Gateway and is suitable for our project's scope.

### Why use a lambda URL over API Gateway?

API Gateway offers a range of features like request validation, rate limiting, and more advanced routing options, but it can be overkill for simpler applications like this demo. In contrast, lambda function URLs allows for direct HTTP invocation which simplifies testing and implementation.

If we had several API endpoints or lambdas it would be a good idea to put API Gateway infront of our architecture.

### 1. Append the lambda function URL to the 'lambda.tf' file

Add the following code to the existing `lambda.tf` file:

```hcl
resource "aws_lambda_function_url" "url_1" {
  function_name      = aws_lambda_function.ip_counter_lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}
```

## Testing the lambda function

Now that we have set up our initial lambda function and its associated URL, it's time to apply our Terraform configuration and test it.

### 1. Create the file 'outputs.tf'

Before that, we will create a file named `outputs.tf` which will output the URL of our Lambda function once Terraform applies the configuration (or by using `terraform output`). This will allow us to retrieve the URL easily.

Create `outputs.tf` with the following content:

```hcl
output "lambda_url" {
  value = aws_lambda_function_url.url_1.function_url
}
```

### 2. Apply the terraform configuration

Before applying our configuration, it's good practice to run `terraform plan` to **review the changes** that will be made to the infrastructure. We don't want to break production, do we?

OK, run `terraform plan`, you should see an output similar to this:

```
Plan: 3 to add, 0 to change, 0 to destroy.
```

This indicates that a `terraform apply` will create three new resources without destroying or modifying any existing ones.

Alright, now run `terraform apply`. Terraform will create the necessary resources making API calls to AWS. Once its complete, you should see your lambda function's URL in the outputs:

```
Outputs:

lambda_url = "https://gceulcmv2nckndx66lle7q4c6y0xpmap.lambda-url.us-east-1.on.aws/"
```

### 3. Test the lambda function

Finally, test the lambda function to ensure it's working. You can do this using `curl` with the function URL:

```shell
$ curl https://gceulcmv2nckndx66lle7q4c6y0xpmap.lambda-url.us-east-1.on.aws/
Hello, world!
```

That looks good, the response confirms that our lambda function is deployed and accessible.

Next, we'll deploy our DynamoDB table.

## Setting up DynamoDB

For our application to work, we need a database to store our counters. DynamoDB is a NoSQL key/value database that will fit our use case perfectly.

### 1. Define the DynamoDB table

Create a new file named `dynamodb.tf` in your project directory. This file will contain the configuration for our DynamoDB table and an IAM policy document granting read and write access to DynamoDB that we will attach to our lambda function IAM role policy.

The Terraform resources used are the following:

- [aws_iam_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)
- [aws_dynamodb_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table)

Add this code to the `dynamodb.tf` file:

```hcl
data "aws_iam_policy_document" "ddb-rw" {
  statement {
    sid       = "ddbrw"
    effect    = "Allow"
    actions   = ["dynamodb:Scan", "dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = ["*"]
  }
}

resource "aws_dynamodb_table" "ip-counter" {
  name         = local.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "address"
  attribute {
    name = "address"
    type = "S"
  }
}
```

### 2. IAM Role policy

Currently, our lambda function doesn't have any permissions to interact with our DynamoDB table, let's fix this.

Modify the `lambda.tf` file to include the inline policy in the `aws_iam_role.iam_lambda` resource. This will grant the lambda function the permissions defined in the IAM policy document.

Add the following inline policy to your lambda's IAM role:

```hcl
  inline_policy {
    name   = "ddbrw"
    policy = data.aws_iam_policy_document.ddb-rw.json
  }
```

The final `aws_iam_role` resource should look like this:

```hcl
resource "aws_iam_role" "iam_lambda" {
  name = local.name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  inline_policy {
    name   = "ddbrw"
    policy = data.aws_iam_policy_document.ddb-rw.json
  }
}
```

### 3. Modify the lambda function environment variables

Finally, update the `aws_lambda_function` resource to include the DynamoDB table name as an environment variable. We will use this environment variable in our lambda's python code to know the name of our DynamoDB table.

Modify the environment block in the `aws_lambda_function` resource from the `labmda.tf` file:

```hcl
  environment {
    variables = {
      DDB_TABLE_NAME = aws_dynamodb_table.ip-counter.name
    }
  }
```

## Finishing our lambda function code

This is looking good. Now that our basic AWS setup is complete, it's time to write our final lambda function code.

### Updating the code

Open the `lambda_function.py` file within the `lambda-code` directory and replace its content with the following:

```python
import os

import boto3
from botocore.exceptions import ClientError

ddb = boto3.resource("dynamodb")
table = ddb.Table(os.environ["DDB_TABLE_NAME"])


def update_counter(address: str):
    try:
        response = table.update_item(
            Key={"address": address},
            UpdateExpression="SET #v = if_not_exists(#v, :start) + :inc",
            ExpressionAttributeNames={"#v": "value"},
            ExpressionAttributeValues={":inc": 1, ":start": 0},
            ReturnValues="UPDATED_NEW",
        )
        return response["Attributes"]["value"]
    except ClientError as e:
        print(f"Error updating value: {e}")
        return None


def lambda_handler(event, context):
    request_context = event["requestContext"]
    source_ip = request_context["http"]["sourceIp"]

    count = update_counter(source_ip)
    if count is None:
        return {"statusCode": 500, "body": "Error updating counter"}

    body = {"address": source_ip, "count": count}
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": body,
    }
```

### How it works

1. It retrieves the source or client IP address from the `event` object.
2. The function `update_counter` leverages the [boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) library to interact with the DynamoDB table, updating or creating the key `address` with the IP address and its counter, permissions are "automatically" granted thanks to the IAM role attached to the lambda function. Finally it returns the updated counter value.
3. The handler returns a JSON response containing the address and its counter.

### Deploy and test

Let's see it in action. Run `terraform apply` and execute the lambda function by calling its URL:

```shell
$ terraform apply
[ . . . ]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

lambda_url = "https://2awtiy5yx77eemsxeu2lhqy77u0vwmhe.lambda-url.us-east-1.on.aws/"
```

The lambda's url will be different for you :)

```shell
$ curl https://2awtiy5yx77eemsxeu2lhqy77u0vwmhe.lambda-url.us-east-1.on.aws/ | jq .
{
  "address": "83.52.250.31",
  "count": 8
}
$ curl https://2awtiy5yx77eemsxeu2lhqy77u0vwmhe.lambda-url.us-east-1.on.aws/ | jq .
{
  "address": "83.52.250.31",
  "count": 9
}

$ curl https://2awtiy5yx77eemsxeu2lhqy77u0vwmhe.lambda-url.us-east-1.on.aws/ | jq .
{
  "address": "83.52.250.31",
  "count": 10
}
```

Great! Our serverless IP Address counter is working as expected, now we will integrate it in a simple HTML page using bit of javascript.

## Static HTML page integrating the lambda function

Now we'll create a simple HTML page that will call our lambda function URL using JavaScript.

### JavaScript code

The JavaScript code that will be embedded in the HTML file is designed to interact with your lambda function URL:

```javascript
window.onload = function () {
  let URL = "<LAMBDA_URL>";

  fetch(URL)
    .then((response) => response.json())
    .then((data) => {
      const address = data.address;
      const count = data.count;
      let message = "";

      if (count === 1) {
        message = `Welcome ${address}! It seems like it's your first time visiting this page!`;
      } else {
        message = `Welcome back ${address}! You have visited this page ${count} times.`;
      }

      document.getElementById("message").innerText = message;
    })
    .catch((error) => {
      console.error("Error fetching data: ", error);
      document.getElementById("message").innerText = "Error loading data.";
    });
};
```

Here's how it works:

1. It triggers a function with `window.onload` event.
2. The function performs a fetch request against the lambda's URL, when the request arrives to the AWS lambda function it contains the source IP Address and other metadata about the caller.
3. The response is processed expecting a JSON object that contains the `address` and `count` properties.
4. Finally we update the HTML element with the id `message` with the appropiate content, which is different if it's the first time (the counter is 1).

### Final HTML file

Here's the full HTML file embedding the JavaScript code and some CSS styles.

Save this file as `webpage/index.html` and remember to replace `<LAMBDA_URL>` with your actual lambda URL.

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>IP Address Counter</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        text-align: center;
        margin-top: 50px;
      }
      .message {
        font-size: 24px;
        color: #333;
      }
    </style>
  </head>
  <body>
    <div class="message" id="message"></div>

    <script>
      window.onload = function () {
        let URL = "<LAMBDA_URL>";

        fetch(URL)
          .then((response) => response.json())
          .then((data) => {
            const address = data.address;
            const count = data.count;
            let message = "";

            if (count === 1) {
              message = `Welcome ${address}! It seems like it's your first time visiting this page!`;
            } else {
              message = `Welcome back ${address}! You have visited this page ${count} times.`;
            }

            document.getElementById("message").innerText = message;
          })
          .catch((error) => {
            console.error("Error fetching data: ", error);
            document.getElementById("message").innerText =
              "Error loading data.";
          });
      };
    </script>
  </body>
</html>
```

Once you have saved it, open it with a your local browser. If everything is working correctly you should see a different message the first time you open it and a counter the next time. You can also check the DynamoDB table in your AWS console to see its values being updated.

## Demo

Take a look at this brief video showcasing the application.

{{< rawhtml >}}
<video controls>

  <source src="ip-counter-2.webm" type="video/webm" />
  Download the
  <a href="ip-counter-2.webm">WEBM</a>
  video.
</video>
{{< /rawhtml >}}

## Extending the project

For those interested in a deep hands-on experience, a good next step would be to serve this HTML page from an Amazon S3 bucket and use Amazon CloudFront as a CDN, those two services are also considered serverless and complement each other perfectly. This would require:

1. **Storing the HTML file in S3**: Create an S3 bucket, upload the HTML file, and configure the bucket for static website hosting.
2. **Setting up CloudFront**: Create a CloudFront distribution that points to your S3 bucket.

Do those steps extending the Terraform files of this project.

## Project files

For reference, here's the GitHub repository with all the files that were used in this demo:

- [https://github.com/aorith/terraform-aws-demos/tree/master/serverless-ip-counter](https://github.com/aorith/terraform-aws-demos/tree/master/serverless-ip-counter)
