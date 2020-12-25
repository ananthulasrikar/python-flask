## pre-requisites
	awscli - https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
	jq - https://github.com/stedolan/jq/wiki/Installation
	openssl - https://wiki.openssl.org/index.php/Compilation_and_Installation

### generate aws ssh keypair
	cd cloudformation/application
	aws ec2 create-key-pair --key-name staging|jq -r '.KeyMaterial' > rewind.pem
	chmod 400 rewind.pem

### create self signed certificate
	cd cloudformation/application
	openssl genrsa -out server.key 2048
	openssl req -new -key server.key -out server.csr
	openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
	
### import self signed certificate to AWS account
	cd cloudformation/application
	aws iam upload-server-certificate --server-certificate-name rewind-flask-server-cert \
	  --certificate-body file://server.crt --private-key file://server.key

#### get aws sertificate arn
	arn:aws:iam::xxxx:server-certificate/rewind-flask-server-cert
	# this value to be used in cloudformation/application/parameters.json
	cd cloudformation/application
	aws iam list-server-certificates|jq -r '.ServerCertificateMetadataList[].Arn'

# create topic
	# expected output: arn:aws:sns:us-west-2:xxxx:rewind-topic
	# this value to be used in cloudformation/application/parameters.json
	cd cloudformation/application
	aws sns create-topic --name rewind-topic| jq -r '.TopicArn'

# create subscription for email alerts
	cd cloudformation/application
	aws sns subscribe \
	--topic-arn arn:aws:sns:us-west-2:xxxx:rewind-topic \
	--protocol email \
	--notification-endpoint "xxxxxx@gmail.com"

# create staging environment
	cd cloudformation/application
	aws cloudformation create-stack \
	  --stack-name staging-stack \
	  --parameters file://staging.json \
	  --template-body file://application.yaml \
	  --capabilities CAPABILITY_AUTO_EXPAND \
	  --disable-rollback \
	  --output text

# create production environment
	cd cloudformation/application
	aws cloudformation create-stack \
	  --stack-name production-stack \
	  --parameters file://production.json \
	  --template-body file://application.yaml \
	  --capabilities CAPABILITY_AUTO_EXPAND \
	  --disable-rollback \
	  --output text

# create jenkins isntance
	cd cloudformation/jenkins
	aws cloudformation create-stack \
	  --stack-name jenkins-stack \
	  --parameters file://jenkins.json \
	  --template-body file://jenkins.yaml \
	  --capabilities CAPABILITY_AUTO_EXPAND \
	  --disable-rollback \
	  --output text

# setup jenkins manually
	ssh -i "rewind.pem" ec2-user@{JENKINS_INSTACE_DNS}
	sudo cat /var/lib/jenkins/secrets/initialAdminPassword
	# skip setup and continue as admin
	# create simple job & add below code in execute shell block
	# webhook can be configured for post commit hook at https://github.com/ananthulasrikar/python-flask/settings/hooks/new
	# adding the curl -X POST http://admin:dkjffkjgh447kfhgdkh@{JENKINS_INSTACE_DNS}:8080/job/test/build
	# admin is username, apitoken is dkjffkjgh447kfhgdkh
