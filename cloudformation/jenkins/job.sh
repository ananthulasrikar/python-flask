
#!/bin/bash
# clone github repo
/usr/bin/git clone https://github.com/ananthulasrikar/python-flask
cd python-flask
# build docker image
docker build -t rewindflask .
# push docker images to local registry
docker push 0.0.0.0:5000/python-flask

# get a list of instances by environment, role, and stack
instances=$(
  aws autoscaling describe-auto-scaling-instances \
    --query "AutoScalingInstances[*].[AutoScalingGroupName,InstanceId]" \
    --region us-west-2 --output text \
    | awk '{print $2}'
)

# get PrivateDnsName of the instances to deploy the changes
machines=$(
  for instance in $instances ; do
    aws ec2 describe-instances \
      --instance-ids $instance  \
      --query Reservations[].Instances[].PrivateDnsName \
      --region us-west-2 \
      --output text
  done
)

# deploy source artifact to all matching machines
for machine in $machines ; do
	echo "INFO: Deploying ${artifact} to ${ENVIRONMENT}"
	ssh -o StrictHostKeyChecking=no ec2-user@${machine} "sudo /bin/docker rm --force rewind-flask && /bin/docker run -d -p 80:80 ec2-18-237-212-127.us-west-2.compute.amazonaws.com:5000/rewindflask rewind-flask"
	if [ $? -ne 0 ] ; then
		echo "ERROR: Failed to deploy ${ROLE}" && exit 1
	fi
done
