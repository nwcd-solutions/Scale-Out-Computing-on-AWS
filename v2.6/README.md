## Quick deployment
You can quickly deploy this solution to China NingXia Region(Operated by NWCD) via CloudFormation using default configuration,
Region name | Region code | Launch
--- | --- | ---
AWS China(Ningxia) Region | cn-northwest-1 | [![Launch Stack](LaunchStack.jpg)](https://console.amazonaws.cn/cloudformation/home?region=cn-northwest-1#/stacks/new?templateURL=https://nwcd-solutions.s3.cn-northwest-1.amazonaws.com.cn/scale-out-computing-on-aws/v2.6.0/scale-out-computing-on-aws-without-es.template)
## Customized deployment
### Prerequisites
Create S3 Bucket for the customerized deploymeng resources
```
git clone https://github.com/nwcd-solutions/scale-out-computing-on-aws.git
cd scale-out-computing-on-aws/v2.6
```
Modify files
```
tar zcvf  soca.tar.gz -C source .
```
Upload v2.6 folder to S3 bucket created in prerequistes,use the url of scale-out-computing-on-aws-without-es.template under v2.6 folder in AWS CloudFomation console to create new stack.
