set -e 

AWS_PAGER=""

echo "Searching for existing images..."
readarray -t IMAGES < <(aws ec2 describe-images --filters Name=name,Values=$CUSTOMER-api-* | jq -r '.[] | sort_by(.CreationDate) | .[0:-1] | .[].ImageId')
echo "Found ${#IMAGES[@]} images"

if [[ ${#IMAGES[@]} -gt 5 ]]; then
    NUMBER_TO_DELETE=$((( ${#IMAGES[@]} -5 )))
    echo "Deleting $NUMBER_TO_DELETE older images..."

    for IMAGE in ${IMAGES[@]:0:$NUMBER_TO_DELETE}; do
        echo "Deleting $IMAGE"
        #aws ec2 deregister-image --image-id $IMAGE
    done
else
    echo "Not enough existing images"
fi 